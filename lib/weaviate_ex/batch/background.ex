defmodule WeaviateEx.Batch.Background do
  @moduledoc """
  Background batch processor using Elixir processes.

  Provides continuous, asynchronous batch processing similar to Python's
  daemon thread model, but using Elixir's OTP patterns.

  ## Features

    * Automatic flushing based on batch size or time interval
    * Concurrent request management with configurable limits
    * UUID tracking for reference ordering
    * Error tracking and retry support
    * Graceful shutdown with final flush

  ## Examples

      {:ok, batcher} = Background.start_link(
        client: client,
        collection: "Article",
        batch_size: 100,
        concurrent_requests: 2
      )

      # Add objects asynchronously
      for article <- articles do
        :ok = Background.add_object(batcher, article)
      end

      # Get results and stop
      results = Background.stop(batcher, flush: true)
  """

  use GenServer
  import Bitwise
  require Logger

  alias WeaviateEx.API.Batch, as: BatchAPI
  alias WeaviateEx.Batch.ErrorTracking.{ErrorObject, Results}
  alias WeaviateEx.Client

  @default_batch_size 100
  @default_concurrent_requests 2
  @default_flush_interval 1_000
  @max_stored_results 100_000

  @type option ::
          {:client, Client.t()}
          | {:collection, String.t()}
          | {:batch_size, pos_integer()}
          | {:concurrent_requests, pos_integer()}
          | {:flush_interval, pos_integer()}
          | {:on_flush, (Results.t() -> any())}
          | {:on_error, (ErrorObject.t() -> any())}
          | {:tenant, String.t()}

  defstruct [
    :client,
    :collection,
    :tenant,
    :batch_size,
    :concurrent_requests,
    :flush_interval,
    :on_flush,
    :on_error,
    :flush_timer_ref,
    object_queue: :queue.new(),
    reference_queue: :queue.new(),
    pending_uuids: MapSet.new(),
    processed_uuids: MapSet.new(),
    active_requests: 0,
    results: %Results{},
    flush_count: 0,
    object_index: 0
  ]

  ## Client API

  @doc """
  Start a background batch processor.

  ## Options

    * `:client` - WeaviateEx client (required)
    * `:collection` - Collection name (required)
    * `:batch_size` - Objects per batch (default: 100)
    * `:concurrent_requests` - Max concurrent requests (default: 2)
    * `:flush_interval` - Auto-flush interval in ms (default: 1000)
    * `:on_flush` - Callback on each flush completion
    * `:on_error` - Callback on each error
    * `:tenant` - Tenant name for multi-tenancy
  """
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Add an object to the batch queue.

  ## Options

    * `:uuid` - Explicit UUID for the object
    * `:vector` - Vector embedding
    * `:vectors` - Named vectors map
  """
  @spec add_object(GenServer.server(), map(), keyword()) :: :ok
  def add_object(server, properties, opts \\ []) do
    GenServer.cast(server, {:add_object, properties, opts})
  end

  @doc """
  Add a reference to the batch queue.

  References are held until both the source and target objects
  have been successfully processed.
  """
  @spec add_reference(GenServer.server(), String.t(), String.t(), String.t(), keyword()) :: :ok
  def add_reference(server, from_uuid, property, to_uuid, opts \\ []) do
    GenServer.cast(server, {:add_reference, from_uuid, property, to_uuid, opts})
  end

  @doc """
  Trigger an immediate flush of queued items.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(server) do
    GenServer.call(server, :flush)
  end

  @doc """
  Get current accumulated results.
  """
  @spec get_results(GenServer.server()) :: Results.t()
  def get_results(server) do
    GenServer.call(server, :get_results)
  end

  @doc """
  Get current state (for debugging/testing).
  """
  @spec get_state(GenServer.server()) :: map()
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Stop the background processor.

  ## Options

    * `:flush` - Whether to flush remaining items before stopping (default: true)
  """
  @spec stop(GenServer.server(), keyword()) :: Results.t() | :ok
  def stop(server, opts \\ []) do
    flush? = Keyword.get(opts, :flush, true)

    if flush? do
      GenServer.call(server, :stop_with_flush, :infinity)
    else
      GenServer.stop(server, :normal)
      :ok
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    collection = Keyword.fetch!(opts, :collection)

    state = %__MODULE__{
      client: client,
      collection: collection,
      tenant: Keyword.get(opts, :tenant),
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
      concurrent_requests: Keyword.get(opts, :concurrent_requests, @default_concurrent_requests),
      flush_interval: Keyword.get(opts, :flush_interval, @default_flush_interval),
      on_flush: Keyword.get(opts, :on_flush),
      on_error: Keyword.get(opts, :on_error),
      results: Results.new()
    }

    # Schedule first flush timer
    timer_ref = schedule_flush(state.flush_interval)

    {:ok, %{state | flush_timer_ref: timer_ref}}
  end

  @impl true
  def handle_cast({:add_object, properties, opts}, state) do
    uuid = Keyword.get(opts, :uuid, generate_uuid())

    object = %{
      properties: properties,
      uuid: uuid,
      vector: Keyword.get(opts, :vector),
      vectors: Keyword.get(opts, :vectors),
      index: state.object_index
    }

    new_queue = :queue.in(object, state.object_queue)
    new_pending = MapSet.put(state.pending_uuids, uuid)

    state = %{
      state
      | object_queue: new_queue,
        pending_uuids: new_pending,
        object_index: state.object_index + 1
    }

    # Check if we should flush
    state = maybe_trigger_flush(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_reference, from_uuid, property, to_uuid, opts}, state) do
    reference = %{
      from_uuid: from_uuid,
      property: property,
      to_uuid: to_uuid,
      to_collection: Keyword.get(opts, :to_collection, state.collection),
      tenant: Keyword.get(opts, :tenant, state.tenant)
    }

    new_queue = :queue.in(reference, state.reference_queue)
    {:noreply, %{state | reference_queue: new_queue}}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    state = do_flush(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_results, _from, state) do
    {:reply, state.results, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state_map = %{
      queue_size: :queue.len(state.object_queue),
      reference_queue_size: :queue.len(state.reference_queue),
      pending_uuids: state.pending_uuids,
      pending_references_count: count_pending_references(state),
      active_requests: state.active_requests,
      batch_size: state.batch_size,
      concurrent_requests: state.concurrent_requests,
      flush_count: state.flush_count,
      object_queue: state.object_queue
    }

    {:reply, state_map, state}
  end

  @impl true
  def handle_call(:stop_with_flush, _from, state) do
    # Cancel timer
    if state.flush_timer_ref, do: Process.cancel_timer(state.flush_timer_ref)

    # Flush all remaining objects
    state = flush_all(state)

    # Wait for active requests to complete
    state = wait_for_completion(state)

    {:stop, :normal, state.results, state}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    state = do_flush(state)
    timer_ref = schedule_flush(state.flush_interval)
    {:noreply, %{state | flush_timer_ref: timer_ref}}
  end

  @impl true
  def handle_info({:batch_result, result}, state) do
    state = process_batch_result(state, result)

    # Try to send more if we have capacity
    state = maybe_trigger_flush(state)

    {:noreply, state}
  end

  @impl true
  def handle_info({:reference_result, result}, state) do
    state = process_reference_result(state, result)
    {:noreply, state}
  end

  ## Private Functions

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush_timer, interval)
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    # Set version 4 and variant bits
    c_with_version = (c &&& 0x0FFF) ||| 0x4000
    d_with_variant = (d &&& 0x3FFF) ||| 0x8000

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [
      a,
      b,
      c_with_version,
      d_with_variant,
      e
    ])
    |> IO.iodata_to_binary()
  end

  defp maybe_trigger_flush(state) do
    queue_size = :queue.len(state.object_queue)
    can_send = state.active_requests < state.concurrent_requests

    if queue_size >= state.batch_size and can_send do
      do_flush(state)
    else
      state
    end
  end

  defp do_flush(state) do
    if :queue.is_empty(state.object_queue) and :queue.is_empty(state.reference_queue) do
      state
    else
      state
      |> send_object_batch()
      |> send_ready_references()
    end
  end

  defp send_object_batch(state) do
    cond do
      state.active_requests >= state.concurrent_requests ->
        state

      :queue.is_empty(state.object_queue) ->
        state

      true ->
        do_send_object_batch(state)
    end
  end

  defp do_send_object_batch(state) do
    {objects, remaining_queue} = pop_batch(state.object_queue, state.batch_size)
    parent = self()

    Task.start(fn ->
      result = execute_object_batch(state.client, state.collection, objects, state.tenant)
      send(parent, {:batch_result, result})
    end)

    %{
      state
      | object_queue: remaining_queue,
        active_requests: state.active_requests + 1,
        flush_count: state.flush_count + 1
    }
  end

  defp send_ready_references(state) do
    {ready, pending} = partition_ready_references(state)

    if Enum.empty?(ready) do
      state
    else
      parent = self()

      Task.start(fn ->
        result = execute_reference_batch(state.client, state.collection, ready)
        send(parent, {:reference_result, result})
      end)

      %{state | reference_queue: :queue.from_list(pending)}
    end
  end

  defp partition_ready_references(state) do
    all_refs = :queue.to_list(state.reference_queue)

    Enum.split_with(all_refs, fn ref ->
      # Reference is ready if both from and to UUIDs have been processed
      not MapSet.member?(state.pending_uuids, ref.from_uuid) and
        not MapSet.member?(state.pending_uuids, ref.to_uuid)
    end)
  end

  defp count_pending_references(state) do
    state.reference_queue
    |> :queue.to_list()
    |> Enum.count(fn ref ->
      MapSet.member?(state.pending_uuids, ref.from_uuid) or
        MapSet.member?(state.pending_uuids, ref.to_uuid)
    end)
  end

  defp pop_batch(queue, count) do
    pop_batch(queue, count, [])
  end

  defp pop_batch(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp pop_batch(queue, count, acc) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        pop_batch(new_queue, count - 1, [item | acc])

      {:empty, queue} ->
        {Enum.reverse(acc), queue}
    end
  end

  defp execute_object_batch(client, collection, objects, tenant) do
    batch_objects =
      Enum.map(objects, fn obj ->
        %{
          class: collection,
          properties: obj.properties,
          id: obj.uuid,
          vector: obj.vector,
          vectors: obj.vectors,
          tenant: tenant
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end)

    case BatchAPI.create_objects(client, batch_objects) do
      {:ok, response} ->
        {:ok, objects, response}

      {:error, reason} ->
        {:error, objects, reason}
    end
  end

  defp execute_reference_batch(client, collection, references) do
    batch_refs =
      Enum.map(references, fn ref ->
        %{
          from: "weaviate://localhost/#{collection}/#{ref.from_uuid}/#{ref.property}",
          to: "weaviate://localhost/#{ref.to_collection}/#{ref.to_uuid}",
          tenant: ref.tenant
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end)

    case Client.request(client, :post, "/v1/batch/references", batch_refs, []) do
      {:ok, response} ->
        {:ok, references, response}

      {:error, reason} ->
        {:error, references, reason}
    end
  end

  defp process_batch_result(state, {:ok, objects, _response}) do
    # Mark UUIDs as processed
    uuids = Enum.map(objects, & &1.uuid)
    new_pending = Enum.reduce(uuids, state.pending_uuids, &MapSet.delete(&2, &1))
    new_processed = Enum.reduce(uuids, state.processed_uuids, &MapSet.put(&2, &1))

    # Update results
    new_results = update_results_success(state.results, objects)

    # Call on_flush callback
    if state.on_flush, do: state.on_flush.(new_results)

    %{
      state
      | pending_uuids: new_pending,
        processed_uuids: new_processed,
        active_requests: state.active_requests - 1,
        results: new_results
    }
  end

  defp process_batch_result(state, {:error, objects, reason}) do
    # Track errors
    errors =
      Enum.map(objects, fn obj ->
        error = %ErrorObject{
          message: inspect(reason),
          object: obj.properties,
          original_uuid: obj.uuid
        }

        # Call on_error callback
        if state.on_error, do: state.on_error.(error)

        error
      end)

    new_results = %{state.results | failed_objects: state.results.failed_objects ++ errors}

    %{
      state
      | active_requests: state.active_requests - 1,
        results: new_results
    }
  end

  defp process_reference_result(state, {:ok, _references, _response}) do
    state
  end

  defp process_reference_result(state, {:error, references, reason}) do
    errors =
      Enum.map(references, fn ref ->
        %{
          message: inspect(reason),
          from_uuid: ref.from_uuid,
          property: ref.property,
          to_uuid: ref.to_uuid
        }
      end)

    new_results = %{state.results | failed_references: state.results.failed_references ++ errors}

    %{state | results: new_results}
  end

  defp update_results_success(results, objects) do
    new_uuids =
      Enum.reduce(objects, results.successful_uuids, fn obj, acc ->
        # Cap stored results
        if map_size(acc) >= @max_stored_results do
          acc
        else
          Map.put(acc, obj.index, obj.uuid)
        end
      end)

    %{results | successful_uuids: new_uuids}
  end

  defp flush_all(state) do
    if :queue.is_empty(state.object_queue) do
      state
    else
      state
      |> send_object_batch()
      |> flush_all()
    end
  end

  defp wait_for_completion(state) do
    if state.active_requests == 0 do
      state
    else
      receive do
        {:batch_result, result} ->
          state
          |> process_batch_result(result)
          |> wait_for_completion()

        {:reference_result, result} ->
          state
          |> process_reference_result(result)
          |> wait_for_completion()
      after
        30_000 ->
          Logger.warning("Timeout waiting for batch completion")
          state
      end
    end
  end
end
