defmodule WeaviateEx.Batch.Dynamic do
  @moduledoc """
  Dynamic batch processor that auto-adjusts batch sizes based on server queue.

  This GenServer accumulates objects and references, then sends them in batches
  to Weaviate. The batch size is dynamically adjusted based on the server's
  queue depth to optimize throughput.

  ## Features

  - Auto-adjusting batch sizes (10-1000 range by default)
  - Concurrent batch sending
  - Automatic flushing when batch size is reached
  - Error tracking for failed objects/references
  - Graceful shutdown with final flush

  ## Examples

      # Start a dynamic batcher
      {:ok, batcher} = Dynamic.start(client: client)

      # Add objects
      Dynamic.add_object(batcher, "Article", %{title: "Test"})
      Dynamic.add_object(batcher, "Article", %{title: "Test 2"}, uuid: "custom-uuid")

      # Add references
      Dynamic.add_reference(batcher, "Article", "uuid-1", "hasAuthor", "author-uuid")

      # Manually flush
      {:ok, results} = Dynamic.flush(batcher)

      # Stop and get final results
      {:ok, final_results} = Dynamic.stop(batcher)
  """

  use GenServer
  require Logger

  alias WeaviateEx.API.Batch, as: BatchAPI
  alias WeaviateEx.API.Cluster
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
          batch_size: pos_integer(),
          min_batch_size: pos_integer(),
          max_batch_size: pos_integer(),
          concurrent_requests: pos_integer(),
          auto_flush: boolean(),
          objects_buffer: [batch_object()],
          references_buffer: [batch_reference()],
          queue_size: non_neg_integer(),
          results: Results.t(),
          on_flush: (Results.t() -> any()) | nil,
          on_error: (WeaviateEx.Error.t() -> any()) | nil,
          consistency_level: String.t() | nil,
          monitor_server_stats: boolean(),
          poll_interval: pos_integer(),
          poll_timer_ref: reference() | nil
        }

  # Default options
  @default_batch_size 100
  @default_min_batch_size 10
  @default_max_batch_size 1000
  @default_concurrent_requests 2
  @default_poll_interval 5_000

  # Queue thresholds for dynamic adjustment
  @queue_high_threshold 100
  @queue_low_threshold 10
  @batch_adjustment_factor 1.5

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start a new dynamic batcher.

  ## Options

    - `:client` - WeaviateEx.Client (required)
    - `:batch_size` - Initial batch size (default: 100)
    - `:min_batch_size` - Minimum batch size (default: 10)
    - `:max_batch_size` - Maximum batch size (default: 1000)
    - `:concurrent_requests` - Number of concurrent requests (default: 2)
    - `:auto_flush` - Automatically flush when batch size is reached (default: false)
    - `:name` - Optional name for process registration
    - `:on_flush` - Callback function called after each flush
    - `:on_error` - Callback function called on errors
    - `:consistency_level` - Consistency level for requests
    - `:monitor_server_stats` - Poll server for batch stats to adjust sizing (default: false)
    - `:poll_interval` - Interval in ms between server stat polls (default: 5000)

  ## Examples

      {:ok, batcher} = Dynamic.start(client: client, batch_size: 50)

      # With server stats monitoring
      {:ok, batcher} = Dynamic.start(client: client, monitor_server_stats: true)
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

      Dynamic.add_object(batcher, "Article", %{title: "Test"})
      Dynamic.add_object(batcher, "Article", %{title: "Test"}, uuid: "custom-uuid")
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

      Dynamic.add_reference(batcher, "Article", "uuid-1", "hasAuthor", "author-uuid")
  """
  @spec add_reference(pid(), String.t(), String.t(), String.t(), String.t(), keyword()) :: :ok
  def add_reference(pid, collection, from_uuid, property, to_uuid, opts \\ []) do
    GenServer.call(pid, {:add_reference, collection, from_uuid, property, to_uuid, opts})
  end

  @doc """
  Flush all buffered objects and references to Weaviate.

  Returns aggregated results including any errors.
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
  Report the current queue size to adjust batch sizing.

  Called internally or externally to inform the batcher about server load.
  """
  @spec report_queue_size(pid(), non_neg_integer()) :: :ok
  def report_queue_size(pid, queue_size) do
    GenServer.cast(pid, {:report_queue_size, queue_size})
  end

  @type batch_stats :: %{
          queue_length: non_neg_integer(),
          rate_per_second: float(),
          failed_count: non_neg_integer()
        }

  @doc """
  Get current server batch statistics.

  Polls the `/v1/nodes` endpoint to retrieve batch queue information,
  useful for monitoring and dynamic batch sizing.

  ## Examples

      {:ok, stats} = Dynamic.get_server_batch_stats(client)
      # => %{queue_length: 42, rate_per_second: 150.5, failed_count: 0}

  ## Returns

  - `{:ok, batch_stats()}` - Current batch statistics
  - `{:error, term()}` - Error if request fails
  """
  @spec get_server_batch_stats(WeaviateEx.Client.t()) :: {:ok, batch_stats()} | {:error, term()}
  def get_server_batch_stats(client) do
    Cluster.batch_stats(client)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    monitor_server_stats = Keyword.get(opts, :monitor_server_stats, false)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)

    state = %{
      client: client,
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
      min_batch_size: Keyword.get(opts, :min_batch_size, @default_min_batch_size),
      max_batch_size: Keyword.get(opts, :max_batch_size, @default_max_batch_size),
      concurrent_requests: Keyword.get(opts, :concurrent_requests, @default_concurrent_requests),
      auto_flush: Keyword.get(opts, :auto_flush, false),
      objects_buffer: [],
      references_buffer: [],
      queue_size: 0,
      results: Results.new(),
      on_flush: Keyword.get(opts, :on_flush),
      on_error: Keyword.get(opts, :on_error),
      consistency_level: Keyword.get(opts, :consistency_level),
      monitor_server_stats: monitor_server_stats,
      poll_interval: poll_interval,
      poll_timer_ref: nil
    }

    # Start polling timer if monitoring is enabled
    state =
      if monitor_server_stats do
        timer_ref = schedule_poll(poll_interval)
        %{state | poll_timer_ref: timer_ref}
      else
        state
      end

    {:ok, state}
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_server_stats, interval)
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

    # Check if auto-flush is needed
    if new_state.auto_flush and length(new_state.objects_buffer) >= new_state.batch_size do
      case do_flush(new_state) do
        {:ok, flushed_state} ->
          {:reply, :ok, flushed_state}

        {:error, _error, flushed_state} ->
          {:reply, :ok, flushed_state}
      end
    else
      {:reply, :ok, new_state}
    end
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
  def handle_cast({:report_queue_size, queue_size}, state) do
    new_batch_size = adjust_batch_size(state.batch_size, queue_size, state)
    {:noreply, %{state | queue_size: queue_size, batch_size: new_batch_size}}
  end

  @impl true
  def handle_info(:poll_server_stats, state) do
    state = poll_and_update_stats(state)

    # Schedule next poll
    timer_ref = schedule_poll(state.poll_interval)
    {:noreply, %{state | poll_timer_ref: timer_ref}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp poll_and_update_stats(state) do
    case Cluster.batch_stats(state.client) do
      {:ok, stats} ->
        queue_size = stats.queue_length
        new_batch_size = adjust_batch_size(state.batch_size, queue_size, state)

        Logger.debug(
          "Batch stats: queue=#{queue_size}, rate=#{stats.rate_per_second}/s, " <>
            "failed=#{stats.failed_count}, batch_size=#{new_batch_size}"
        )

        %{state | queue_size: queue_size, batch_size: new_batch_size}

      {:error, reason} ->
        Logger.warning("Failed to poll server batch stats: #{inspect(reason)}")
        state
    end
  end

  defp do_flush(state) do
    start_time = System.monotonic_time(:millisecond)

    # Process objects and references
    objects_result = flush_objects(state)
    references_result = flush_references(state)

    elapsed_seconds = (System.monotonic_time(:millisecond) - start_time) / 1000

    case {objects_result, references_result} do
      {{:ok, obj_results}, {:ok, ref_results}} ->
        merged_results =
          merge_results(state.results, obj_results, ref_results)
          |> Results.set_elapsed(elapsed_seconds)

        if state.on_flush, do: state.on_flush.(merged_results)

        new_state = %{
          state
          | objects_buffer: [],
            references_buffer: [],
            results: merged_results
        }

        {:ok, new_state}

      {{:error, error}, _} ->
        if state.on_error, do: state.on_error.(error)
        {:error, error, state}

      {_, {:error, error}} ->
        if state.on_error, do: state.on_error.(error)
        {:error, error, state}
    end
  end

  defp flush_objects(%{objects_buffer: []} = _state), do: {:ok, Results.new()}

  defp flush_objects(state) do
    objects = Enum.reverse(state.objects_buffer)
    batches = Enum.chunk_every(objects, state.batch_size)

    # Send batches concurrently
    tasks =
      batches
      |> Enum.take(state.concurrent_requests)
      |> Enum.map(fn batch ->
        Task.async(fn -> send_object_batch(state.client, batch, state) end)
      end)

    # Collect results
    task_results = Enum.map(tasks, fn task -> Task.await(task, :infinity) end)

    # Process remaining batches if any
    remaining_batches = Enum.drop(batches, state.concurrent_requests)
    remaining_results = process_remaining_batches(state, remaining_batches)

    all_results = task_results ++ remaining_results

    # Check for errors
    case Enum.find(all_results, fn result -> match?({:error, _}, result) end) do
      {:error, error} ->
        {:error, error}

      nil ->
        combined =
          Enum.reduce(all_results, Results.new(), fn {:ok, batch_result}, acc ->
            merge_batch_results(acc, batch_result)
          end)

        {:ok, combined}
    end
  end

  defp flush_references(%{references_buffer: []} = _state), do: {:ok, Results.new()}

  defp flush_references(state) do
    references = Enum.reverse(state.references_buffer)

    case send_reference_batch(state.client, references, state) do
      {:ok, results} -> {:ok, results}
      {:error, error} -> {:error, error}
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

  defp process_remaining_batches(_state, []), do: []

  defp process_remaining_batches(state, batches) do
    Enum.map(batches, fn batch -> send_object_batch(state.client, batch, state) end)
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
    merged =
      merge_batch_results(existing, obj_results)
      |> merge_batch_results(ref_results)

    merged
  end

  defp merge_batch_results(acc, new) do
    %Results{
      failed_objects: acc.failed_objects ++ new.failed_objects,
      failed_references: acc.failed_references ++ new.failed_references,
      successful_uuids: Map.merge(acc.successful_uuids, new.successful_uuids),
      elapsed_seconds: acc.elapsed_seconds + new.elapsed_seconds
    }
  end

  defp adjust_batch_size(current, queue_size, state) do
    cond do
      queue_size > @queue_high_threshold ->
        # Queue is large, decrease batch size
        new_size = trunc(current / @batch_adjustment_factor)
        max(new_size, state.min_batch_size)

      queue_size < @queue_low_threshold ->
        # Queue is small, increase batch size
        new_size = trunc(current * @batch_adjustment_factor)
        min(new_size, state.max_batch_size)

      true ->
        current
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(state) do
    opts = []

    opts =
      if state.consistency_level,
        do: [{:consistency_level, state.consistency_level} | opts],
        else: opts

    opts
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
