defmodule WeaviateEx.Batch.Queue do
  @moduledoc """
  Queue for managing batch operation objects with failure tracking and retry support.

  Provides a structured way to manage objects during batch operations, including:
  - FIFO pending queue for objects to be inserted
  - Failed object tracking with retry counts
  - Automatic re-queue with configurable max retries

  ## Examples

      # Create a queue and add objects
      queue = Queue.new()
        |> Queue.enqueue_many(objects)

      # Process in batches
      {batch, queue} = Queue.dequeue_batch(queue, 100)

      # Track failures
      queue = Queue.mark_failed(queue, failed_object, "Validation error")

      # Re-queue failed objects for retry
      queue = Queue.requeue_failed(queue, max_retries: 3)
  """

  defmodule FailedObject do
    @moduledoc """
    Represents a failed object with metadata.
    """

    defstruct [:object, :reason, :retry_count, :failed_at]

    @type t :: %__MODULE__{
            object: map(),
            reason: String.t(),
            retry_count: non_neg_integer(),
            failed_at: DateTime.t()
          }
  end

  defstruct [:pending, :failed, :retry_count]

  @type t :: %__MODULE__{
          pending: :queue.queue(map()),
          failed: [FailedObject.t()],
          retry_count: %{String.t() => non_neg_integer()}
        }

  @doc """
  Creates a new empty queue.

  ## Examples

      queue = Queue.new()
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      pending: :queue.new(),
      failed: [],
      retry_count: %{}
    }
  end

  @doc """
  Checks if the queue has no pending objects.

  ## Examples

      Queue.empty?(queue)
      # => true
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{pending: pending}) do
    :queue.is_empty(pending)
  end

  @doc """
  Returns the number of pending objects.

  ## Examples

      Queue.pending_count(queue)
      # => 5
  """
  @spec pending_count(t()) :: non_neg_integer()
  def pending_count(%__MODULE__{pending: pending}) do
    :queue.len(pending)
  end

  @doc """
  Returns the number of failed objects.

  ## Examples

      Queue.failed_count(queue)
      # => 2
  """
  @spec failed_count(t()) :: non_neg_integer()
  def failed_count(%__MODULE__{failed: failed}) do
    length(failed)
  end

  @doc """
  Adds an object to the pending queue.

  ## Examples

      queue = Queue.enqueue(queue, %{id: "uuid-1", properties: %{name: "Test"}})
  """
  @spec enqueue(t(), map()) :: t()
  def enqueue(%__MODULE__{pending: pending} = queue, object) do
    %{queue | pending: :queue.in(object, pending)}
  end

  @doc """
  Adds multiple objects to the pending queue.

  ## Examples

      queue = Queue.enqueue_many(queue, objects)
  """
  @spec enqueue_many(t(), [map()]) :: t()
  def enqueue_many(%__MODULE__{} = queue, objects) when is_list(objects) do
    Enum.reduce(objects, queue, &enqueue(&2, &1))
  end

  @doc """
  Removes up to `size` objects from the pending queue.

  Returns a tuple of {objects, updated_queue}.

  ## Examples

      {batch, queue} = Queue.dequeue_batch(queue, 100)
  """
  @spec dequeue_batch(t(), pos_integer()) :: {[map()], t()}
  def dequeue_batch(%__MODULE__{pending: pending} = queue, size)
      when is_integer(size) and size > 0 do
    {batch, new_pending} = dequeue_n(pending, size, [])
    {Enum.reverse(batch), %{queue | pending: new_pending}}
  end

  defp dequeue_n(queue, 0, acc), do: {acc, queue}

  defp dequeue_n(queue, n, acc) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        dequeue_n(new_queue, n - 1, [item | acc])

      {:empty, queue} ->
        {acc, queue}
    end
  end

  @doc """
  Marks an object as failed with a reason.

  If the same object (by id) is marked failed again, increments the retry count.

  ## Examples

      queue = Queue.mark_failed(queue, object, "Validation error")
  """
  @spec mark_failed(t(), map(), String.t()) :: t()
  def mark_failed(%__MODULE__{failed: failed, retry_count: retry_count} = queue, object, reason) do
    object_id = get_object_id(object)
    current_retries = Map.get(retry_count, object_id, 0)
    new_retries = current_retries + 1

    # Remove existing entry for this object if present
    filtered_failed = Enum.reject(failed, &(get_object_id(&1.object) == object_id))

    failed_obj = %FailedObject{
      object: object,
      reason: reason,
      retry_count: new_retries,
      failed_at: DateTime.utc_now()
    }

    %{
      queue
      | failed: [failed_obj | filtered_failed],
        retry_count: Map.put(retry_count, object_id, new_retries)
    }
  end

  @doc """
  Moves failed objects back to the pending queue for retry.

  Only objects with retry_count < max_retries are requeued.

  ## Options

    - `:max_retries` - Maximum number of retries allowed (default: 3)

  ## Examples

      queue = Queue.requeue_failed(queue, max_retries: 3)
  """
  @spec requeue_failed(t(), keyword()) :: t()
  def requeue_failed(%__MODULE__{failed: failed} = queue, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)

    {to_requeue, to_keep} =
      Enum.split_with(failed, fn %FailedObject{retry_count: count} ->
        count < max_retries
      end)

    # Add retriable objects back to pending
    objects_to_requeue = Enum.map(to_requeue, & &1.object)
    queue = enqueue_many(queue, objects_to_requeue)

    %{queue | failed: to_keep}
  end

  @doc """
  Returns all failed objects.

  ## Examples

      failed = Queue.get_failed(queue)
  """
  @spec get_failed(t()) :: [FailedObject.t()]
  def get_failed(%__MODULE__{failed: failed}) do
    failed
  end

  @doc """
  Clears all failed objects.

  ## Examples

      queue = Queue.clear_failed(queue)
  """
  @spec clear_failed(t()) :: t()
  def clear_failed(%__MODULE__{} = queue) do
    %{queue | failed: [], retry_count: %{}}
  end

  @doc """
  Returns statistics about the queue.

  ## Examples

      stats = Queue.stats(queue)
      # => %{pending: 5, failed: 2, total: 7}
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = queue) do
    pending = pending_count(queue)
    failed = failed_count(queue)

    %{
      pending: pending,
      failed: failed,
      total: pending + failed
    }
  end

  # Get a unique identifier for an object
  defp get_object_id(%{id: id}), do: id
  defp get_object_id(%{"id" => id}), do: id
  defp get_object_id(%{uuid: uuid}), do: uuid
  defp get_object_id(%{"uuid" => uuid}), do: uuid
  defp get_object_id(object), do: :erlang.phash2(object)
end
