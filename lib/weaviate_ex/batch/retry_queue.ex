defmodule WeaviateEx.Batch.RetryQueue do
  @moduledoc """
  Manages automatic re-queuing of failed batch objects.

  This GenServer tracks failed objects and provides automatic retry with
  exponential backoff. Objects are tracked by UUID and dropped after
  exceeding the maximum retry count.

  ## Features

  - Track retry count per object UUID
  - Exponential backoff between retries with jitter
  - Drop objects after max_retries
  - Permanent failure callback for objects that exceed retry limit
  - Drain queue to get all pending retries

  ## Examples

      # Start the retry queue
      {:ok, pid} = RetryQueue.start_link(
        client: client,
        max_retries: 3,
        base_delay_ms: 1000,
        on_permanent_failure: fn objects ->
          Logger.error("Permanent failures: \#{length(objects)}")
        end
      )

      # Enqueue failed objects for retry
      :ok = RetryQueue.enqueue_failed(pid, failed_objects)

      # Get retry count for a specific UUID
      count = RetryQueue.get_retry_count(pid, "uuid-123")

      # Drain all queued objects (for manual processing)
      {:ok, objects} = RetryQueue.drain(pid)

      # Clear the queue
      :ok = RetryQueue.clear(pid)
  """

  use GenServer
  require Logger

  @default_max_retries 3
  @default_base_delay_ms 1000
  @max_delay_ms 60_000
  @jitter_factor 0.2

  @type failed_object :: %{
          required(:uuid) => String.t(),
          required(:properties) => map(),
          required(:collection) => String.t(),
          optional(:vector) => [float()],
          optional(:tenant) => String.t()
        }

  @type state :: %{
          client: map(),
          queue: :queue.queue(failed_object()),
          retry_counts: %{String.t() => non_neg_integer()},
          max_retries: pos_integer(),
          base_delay_ms: pos_integer(),
          on_permanent_failure: ([failed_object()] -> any()) | nil
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the retry queue GenServer.

  ## Options

    - `:client` - WeaviateEx client (required)
    - `:max_retries` - Maximum retry attempts per object (default: 3)
    - `:base_delay_ms` - Base delay for exponential backoff (default: 1000)
    - `:on_permanent_failure` - Callback for objects that exceed max retries
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Enqueue failed objects for retry.

  Objects are tracked by UUID. If an object has already been retried
  `max_retries` times, the `on_permanent_failure` callback is invoked
  and the object is dropped.
  """
  @spec enqueue_failed(GenServer.server(), [failed_object()]) :: :ok
  def enqueue_failed(pid, failed_objects) when is_list(failed_objects) do
    GenServer.cast(pid, {:enqueue_failed, failed_objects})
  end

  @doc """
  Drain all queued objects for manual processing.

  Returns all pending objects and clears the queue.
  """
  @spec drain(GenServer.server()) :: {:ok, [failed_object()]}
  def drain(pid) do
    GenServer.call(pid, :drain)
  end

  @doc """
  Get the current queue size.
  """
  @spec size(GenServer.server()) :: non_neg_integer()
  def size(pid) do
    GenServer.call(pid, :size)
  end

  @doc """
  Clear all queued objects and reset retry counts.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  @doc """
  Get the retry count for a specific UUID.
  """
  @spec get_retry_count(GenServer.server(), String.t()) :: non_neg_integer()
  def get_retry_count(pid, uuid) do
    GenServer.call(pid, {:get_retry_count, uuid})
  end

  @doc """
  Get the current state (for debugging/testing).
  """
  @spec get_state(GenServer.server()) :: map()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # ============================================================================
  # Pure Functions (Public for testing)
  # ============================================================================

  @doc """
  Calculate exponential backoff delay for a given attempt.

  Returns delay in milliseconds, capped at max_delay (60 seconds).
  """
  @spec calculate_backoff(non_neg_integer(), pos_integer()) :: pos_integer()
  def calculate_backoff(attempt, base_delay_ms) when attempt >= 0 and base_delay_ms > 0 do
    delay = (base_delay_ms * :math.pow(2, attempt)) |> trunc()
    min(delay, @max_delay_ms)
  end

  @doc """
  Calculate exponential backoff with jitter (±20%).

  Jitter helps prevent thundering herd when multiple retries happen simultaneously.
  """
  @spec calculate_backoff_with_jitter(non_neg_integer(), pos_integer()) :: pos_integer()
  def calculate_backoff_with_jitter(attempt, base_delay_ms) do
    base = calculate_backoff(attempt, base_delay_ms)
    jitter_range = trunc(base * @jitter_factor)

    # Add random jitter between -jitter_range and +jitter_range
    jitter = :rand.uniform(jitter_range * 2 + 1) - jitter_range - 1
    max(1, base + jitter)
  end

  @doc """
  Check if an error is retryable.

  Retryable errors include:
  - gRPC status codes: UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED, DEADLINE_EXCEEDED
  - Rate limit errors (detected by message patterns)
  """
  @spec retryable_error?(map()) :: boolean()
  def retryable_error?(%{code: code})
      when code in [:unavailable, :resource_exhausted, :aborted, :deadline_exceeded] do
    true
  end

  def retryable_error?(%{message: message}) when is_binary(message) do
    rate_limit_error?(message)
  end

  def retryable_error?(_error), do: false

  @doc """
  Check if an error message indicates a rate limit error.
  """
  @spec rate_limit_error?(String.t()) :: boolean()
  def rate_limit_error?(message) when is_binary(message) do
    patterns = [
      ~r/rate limit/i,
      ~r/Rate limit reached/i,
      ~r/tokens per min/i,
      ~r/support@cohere\.com/,
      ~r/503 error/i,
      ~r/too many requests/i,
      ~r/retry after/i
    ]

    Enum.any?(patterns, &Regex.match?(&1, message))
  end

  def rate_limit_error?(_), do: false

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    _client = Keyword.fetch!(opts, :client)

    state = %{
      client: Keyword.fetch!(opts, :client),
      queue: :queue.new(),
      retry_counts: %{},
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      base_delay_ms: Keyword.get(opts, :base_delay_ms, @default_base_delay_ms),
      on_permanent_failure: Keyword.get(opts, :on_permanent_failure)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue_failed, objects}, state) do
    {state, permanent_failures} = process_failed_objects(objects, state)

    # Invoke permanent failure callback if any
    if permanent_failures != [] and state.on_permanent_failure do
      state.on_permanent_failure.(permanent_failures)
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:drain, _from, state) do
    objects = :queue.to_list(state.queue)
    new_state = %{state | queue: :queue.new()}
    {:reply, {:ok, objects}, new_state}
  end

  @impl true
  def handle_call(:size, _from, state) do
    {:reply, :queue.len(state.queue), state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    new_state = %{state | queue: :queue.new(), retry_counts: %{}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_retry_count, uuid}, _from, state) do
    count = Map.get(state.retry_counts, uuid, 0)
    {:reply, count, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state_map = %{
      queue_size: :queue.len(state.queue),
      retry_counts: state.retry_counts,
      max_retries: state.max_retries,
      base_delay_ms: state.base_delay_ms,
      on_permanent_failure: state.on_permanent_failure
    }

    {:reply, state_map, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp process_failed_objects(objects, state) do
    Enum.reduce(objects, {state, []}, fn object, {state_acc, failures_acc} ->
      uuid = get_object_uuid(object)
      current_count = Map.get(state_acc.retry_counts, uuid, 0)
      new_count = current_count + 1

      if new_count > state_acc.max_retries do
        # Object exceeded max retries - permanent failure
        new_retry_counts = Map.delete(state_acc.retry_counts, uuid)
        new_state = %{state_acc | retry_counts: new_retry_counts}
        {new_state, [object | failures_acc]}
      else
        # Add to queue for retry
        new_queue = :queue.in(object, state_acc.queue)
        new_retry_counts = Map.put(state_acc.retry_counts, uuid, new_count)
        new_state = %{state_acc | queue: new_queue, retry_counts: new_retry_counts}
        {new_state, failures_acc}
      end
    end)
  end

  defp get_object_uuid(%{uuid: uuid}), do: uuid
  defp get_object_uuid(%{"uuid" => uuid}), do: uuid
  defp get_object_uuid(%{id: id}), do: id
  defp get_object_uuid(%{"id" => id}), do: id
  defp get_object_uuid(object), do: :erlang.phash2(object) |> to_string()
end
