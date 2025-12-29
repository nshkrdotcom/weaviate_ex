defmodule WeaviateEx.Batch.RateLimited do
  @moduledoc """
  Rate-limited batch processor for Weaviate that respects vectorizer rate limits.

  This GenServer manages batch operations while enforcing rate limits to avoid
  overwhelming vectorizer APIs (OpenAI, Cohere, etc.) that have per-minute
  request quotas.

  ## Features

  - Configurable requests per minute limit
  - Automatic throttling based on rate limit
  - Retry on rate limit errors with exponential backoff
  - Error tracking for failed objects/references
  - Callback support for monitoring

  ## Examples

      # Start a rate-limited batcher with 30 requests per minute
      {:ok, batcher} = RateLimited.start(
        client: client,
        requests_per_minute: 30
      )

      # Add objects
      RateLimited.add_object(batcher, "Article", %{title: "Test"})

      # Flush respects rate limits
      {:ok, results} = RateLimited.flush(batcher)

      # Check remaining capacity
      remaining = RateLimited.get_remaining_requests(batcher)

      # Stop and get final results
      {:ok, final_results} = RateLimited.stop(batcher)
  """

  use GenServer
  require Logger

  alias WeaviateEx.API.Batch, as: BatchAPI
  alias WeaviateEx.Batch.BatchRetry
  alias WeaviateEx.Batch.ErrorTracking.{ErrorObject, Results}

  @type batch_object :: %{
          collection: String.t(),
          properties: map(),
          uuid: String.t() | nil,
          vector: [float()] | nil,
          tenant: String.t() | nil
        }

  @type batch_reference :: %{
          collection: String.t(),
          from_uuid: String.t(),
          property: String.t(),
          to_uuid: String.t(),
          tenant: String.t() | nil
        }

  @type state :: %{
          client: WeaviateEx.Client.t(),
          requests_per_minute: pos_integer(),
          batch_size: pos_integer(),
          objects_buffer: [batch_object()],
          references_buffer: [batch_reference()],
          request_times: [integer()],
          results: Results.t(),
          retry_on_rate_limit: boolean(),
          max_retries: pos_integer(),
          retry_sleep: (non_neg_integer() -> any()),
          on_flush: (Results.t() -> any()) | nil,
          on_error: (WeaviateEx.Error.t() -> any()) | nil,
          consistency_level: String.t() | nil
        }

  # Default options
  @default_requests_per_minute 60
  @default_batch_size 100
  @default_max_retries 5

  # Time window for rate limiting (1 minute in milliseconds)
  @rate_window_ms 60_000

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start a new rate-limited batcher.

  ## Options

    - `:client` - WeaviateEx.Client (required)
    - `:requests_per_minute` - Maximum requests per minute (default: 60)
    - `:batch_size` - Number of objects per batch (default: 100)
    - `:retry_on_rate_limit` - Retry on rate limit errors (default: false)
    - `:max_retries` - Maximum retry attempts (default: 5)
    - `:retry_sleep` - Sleep function used between retries (default: `&Process.sleep/1`)
    - `:name` - Optional name for process registration
    - `:on_flush` - Callback function called after each flush
    - `:on_error` - Callback function called on errors
    - `:consistency_level` - Consistency level for requests

  ## Examples

      {:ok, batcher} = RateLimited.start(
        client: client,
        requests_per_minute: 30,
        batch_size: 50
      )
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    gen_opts = if name, do: [name: name], else: []
    GenServer.start(__MODULE__, opts, gen_opts)
  end

  @doc """
  Add an object to the batch buffer.

  ## Options

    - `:uuid` - Custom UUID for the object
    - `:vector` - Custom vector for the object
    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      RateLimited.add_object(batcher, "Article", %{title: "Test"})
      RateLimited.add_object(batcher, "Article", %{title: "Test"}, uuid: "custom-uuid")
  """
  @spec add_object(pid(), String.t(), map(), keyword()) :: :ok
  def add_object(pid, collection, properties, opts \\ []) do
    GenServer.call(pid, {:add_object, collection, properties, opts})
  end

  @doc """
  Add a reference to the batch buffer.

  ## Options

    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      RateLimited.add_reference(batcher, "Article", "uuid-1", "hasAuthor", "author-uuid")
  """
  @spec add_reference(pid(), String.t(), String.t(), String.t(), String.t(), keyword()) :: :ok
  def add_reference(pid, collection, from_uuid, property, to_uuid, opts \\ []) do
    GenServer.call(pid, {:add_reference, collection, from_uuid, property, to_uuid, opts})
  end

  @doc """
  Flush all buffered objects and references to Weaviate.

  This respects the rate limit and may block if necessary.
  """
  @spec flush(pid()) :: {:ok, Results.t()} | {:error, WeaviateEx.Error.t()}
  def flush(pid) do
    GenServer.call(pid, :flush, :infinity)
  end

  @doc """
  Stop the batcher, flushing any remaining objects.

  Returns final aggregated results.
  """
  @spec stop(pid()) :: {:ok, Results.t()}
  def stop(pid) do
    GenServer.call(pid, :stop, :infinity)
  end

  @doc """
  Get the current state of the batcher.

  Useful for debugging and testing.
  """
  @spec get_state(pid()) :: state()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Get the number of remaining requests allowed in the current rate window.
  """
  @spec get_remaining_requests(pid()) :: non_neg_integer()
  def get_remaining_requests(pid) do
    GenServer.call(pid, :get_remaining_requests)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    client = Keyword.fetch!(opts, :client)

    state = %{
      client: client,
      requests_per_minute: Keyword.get(opts, :requests_per_minute, @default_requests_per_minute),
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
      objects_buffer: [],
      references_buffer: [],
      request_times: [],
      results: Results.new(),
      retry_on_rate_limit: Keyword.get(opts, :retry_on_rate_limit, false),
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      retry_sleep: Keyword.get(opts, :retry_sleep, &Process.sleep/1),
      on_flush: Keyword.get(opts, :on_flush),
      on_error: Keyword.get(opts, :on_error),
      consistency_level: Keyword.get(opts, :consistency_level)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_object, collection, properties, opts}, _from, state) do
    object = %{
      collection: collection,
      properties: properties,
      uuid: Keyword.get(opts, :uuid),
      vector: Keyword.get(opts, :vector),
      tenant: Keyword.get(opts, :tenant)
    }

    new_state = %{state | objects_buffer: [object | state.objects_buffer]}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:add_reference, collection, from_uuid, property, to_uuid, opts}, _from, state) do
    reference = %{
      collection: collection,
      from_uuid: from_uuid,
      property: property,
      to_uuid: to_uuid,
      tenant: Keyword.get(opts, :tenant)
    }

    new_state = %{state | references_buffer: [reference | state.references_buffer]}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    case do_flush(state) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.results}, new_state}

      {:error, error, new_state} ->
        {:reply, {:error, error}, new_state}
    end
  end

  @impl true
  def handle_call(:stop, _from, state) do
    case do_flush(state) do
      {:ok, new_state} ->
        {:stop, :normal, {:ok, new_state.results}, new_state}

      {:error, _error, new_state} ->
        {:stop, :normal, {:ok, new_state.results}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_remaining_requests, _from, state) do
    remaining = calculate_remaining_requests(state)
    {:reply, remaining, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_flush(state) do
    start_time = System.monotonic_time(:millisecond)

    # Flush objects with rate limiting
    {objects_result, state_after_objects} = flush_objects_with_rate_limit(state)

    # Flush references with rate limiting
    {references_result, state_after_refs} = flush_references_with_rate_limit(state_after_objects)

    elapsed_seconds = (System.monotonic_time(:millisecond) - start_time) / 1000

    case {objects_result, references_result} do
      {{:ok, obj_results}, {:ok, ref_results}} ->
        merged_results =
          merge_results(state_after_refs.results, obj_results, ref_results)
          |> Results.set_elapsed(elapsed_seconds)

        if state.on_flush, do: state.on_flush.(merged_results)

        new_state = %{
          state_after_refs
          | objects_buffer: [],
            references_buffer: [],
            results: merged_results
        }

        {:ok, new_state}

      {{:error, error}, _} ->
        if state.on_error, do: state.on_error.(error)
        {:error, error, state_after_refs}

      {_, {:error, error}} ->
        if state.on_error, do: state.on_error.(error)
        {:error, error, state_after_refs}
    end
  end

  defp flush_objects_with_rate_limit(%{objects_buffer: []} = state) do
    {{:ok, Results.new()}, state}
  end

  defp flush_objects_with_rate_limit(state) do
    objects = Enum.reverse(state.objects_buffer)
    batches = Enum.chunk_every(objects, state.batch_size)

    {results, final_state} =
      Enum.reduce_while(batches, {[], state}, fn batch, {acc_results, acc_state} ->
        # Wait for rate limit capacity
        {delay, new_state} = wait_for_capacity(acc_state)

        if delay > 0 do
          Process.sleep(delay)
        end

        case send_object_batch_with_retry(new_state.client, batch, new_state) do
          {:ok, batch_result} ->
            updated_state = record_request(new_state)
            {:cont, {[{:ok, batch_result} | acc_results], updated_state}}

          {:error, error} ->
            {:halt, {[{:error, error} | acc_results], new_state}}
        end
      end)

    # Check for errors
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      {:error, error} ->
        {{:error, error}, final_state}

      nil ->
        combined =
          results
          |> Enum.reverse()
          |> Enum.reduce(Results.new(), fn {:ok, batch_result}, acc ->
            merge_batch_results(acc, batch_result)
          end)

        {{:ok, combined}, final_state}
    end
  end

  defp flush_references_with_rate_limit(%{references_buffer: []} = state) do
    {{:ok, Results.new()}, state}
  end

  defp flush_references_with_rate_limit(state) do
    references = Enum.reverse(state.references_buffer)

    # Wait for rate limit capacity
    {delay, new_state} = wait_for_capacity(state)

    if delay > 0 do
      Process.sleep(delay)
    end

    case send_reference_batch(new_state.client, references, new_state) do
      {:ok, results} ->
        updated_state = record_request(new_state)
        {{:ok, results}, updated_state}

      {:error, error} ->
        {{:error, error}, new_state}
    end
  end

  defp send_object_batch_with_retry(client, objects, state) do
    if state.retry_on_rate_limit do
      BatchRetry.with_retry(
        fn -> send_object_batch(client, objects, state) end,
        max_retries: state.max_retries,
        sleep: state.retry_sleep
      )
    else
      send_object_batch(client, objects, state)
    end
  end

  defp send_object_batch(client, objects, state) do
    formatted_objects =
      Enum.map(objects, fn obj ->
        base = %{
          "class" => obj.collection,
          "properties" => obj.properties
        }

        base
        |> maybe_put("id", obj.uuid)
        |> maybe_put("vector", obj.vector)
        |> maybe_put("tenant", obj.tenant)
      end)

    opts = build_opts(state)

    case BatchAPI.create_objects(client, formatted_objects, Keyword.put(opts, :summary, true)) do
      {:ok, %BatchAPI.Result{} = result} ->
        {:ok, convert_api_result(result)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_reference_batch(client, references, state) do
    formatted_refs =
      Enum.map(references, fn ref ->
        %{
          "from" => "weaviate://localhost/#{ref.collection}/#{ref.from_uuid}/#{ref.property}",
          "to" => "weaviate://localhost/#{ref.collection}/#{ref.to_uuid}"
        }
      end)

    opts = build_opts(state)

    case WeaviateEx.Client.request(
           client,
           :post,
           "/v1/batch/references" <> build_query_string(opts),
           formatted_refs,
           opts
         ) do
      {:ok, results} when is_list(results) ->
        processed = process_reference_results(results)
        {:ok, processed}

      {:error, error} ->
        {:error, error}
    end
  end

  defp convert_api_result(%BatchAPI.Result{} = result) do
    base = Results.new()

    successful_results =
      result.successful
      |> Enum.with_index()
      |> Enum.reduce(base, fn {obj, idx}, acc ->
        Results.add_success(acc, idx, obj["id"])
      end)

    Enum.reduce(result.errors, successful_results, fn error, acc ->
      error_obj = %ErrorObject{
        message: Enum.join(error.messages, "; "),
        object: error.raw,
        original_uuid: error.id
      }

      Results.add_error(acc, error_obj)
    end)
  end

  defp process_reference_results(results) do
    Enum.reduce(results, Results.new(), fn result, acc ->
      case result do
        %{"status" => "SUCCESS"} ->
          Results.add_success(acc, map_size(acc.successful_uuids), "reference")

        %{"status" => "FAILED"} = failed ->
          error = %ErrorObject{
            message: Map.get(failed, "result", %{}) |> Map.get("errors", "Unknown error"),
            object: failed
          }

          Results.add_error(acc, error)

        _ ->
          acc
      end
    end)
  end

  defp merge_results(existing, obj_results, ref_results) do
    merge_batch_results(existing, obj_results)
    |> merge_batch_results(ref_results)
  end

  defp merge_batch_results(acc, new) do
    %Results{
      failed_objects: acc.failed_objects ++ new.failed_objects,
      failed_references: acc.failed_references ++ new.failed_references,
      successful_uuids: Map.merge(acc.successful_uuids, new.successful_uuids),
      elapsed_seconds: acc.elapsed_seconds + new.elapsed_seconds
    }
  end

  defp wait_for_capacity(state) do
    remaining = calculate_remaining_requests(state)

    if remaining > 0 do
      {0, state}
    else
      # Calculate how long until the oldest request expires
      now = System.monotonic_time(:millisecond)
      oldest_request = List.last(state.request_times)
      wait_time = max(0, oldest_request + @rate_window_ms - now)
      {wait_time, state}
    end
  end

  defp calculate_remaining_requests(state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @rate_window_ms

    # Clean old request times
    recent_requests =
      Enum.filter(state.request_times, fn time -> time > cutoff end)

    state.requests_per_minute - length(recent_requests)
  end

  defp record_request(state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @rate_window_ms

    # Clean old requests and add new one
    recent_requests =
      state.request_times
      |> Enum.filter(fn time -> time > cutoff end)
      |> List.insert_at(0, now)

    %{state | request_times: recent_requests}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(state) do
    opts = []

    if state.consistency_level do
      [{:consistency_level, state.consistency_level} | opts]
    else
      opts
    end
  end

  defp build_query_string([]), do: ""

  defp build_query_string(opts) do
    params =
      Enum.map_join(opts, "&", fn {key, value} ->
        "#{key}=#{URI.encode_www_form(to_string(value))}"
      end)

    "?" <> params
  end
end
