defmodule WeaviateEx.Batch.Stream do
  @moduledoc """
  Stream-based batch insertion with server-side batching.

  Provides a high-level API for streaming batch insertions to Weaviate using
  bidirectional gRPC streaming. This is more efficient than traditional batch
  APIs for continuous data ingestion, as it maintains a persistent connection
  and allows the server to manage batching.

  ## Features

  - Bidirectional gRPC streaming for high throughput
  - Client-side buffering with configurable size
  - Auto-flush based on buffer size or time interval
  - Server-side batching mode (Weaviate 1.34+)
  - Automatic reconnection on stream failure
  - Result tracking and error collection

  ## Example

      alias WeaviateEx.Batch.Stream

      # Create a new stream
      {:ok, stream} = Stream.new(client, "Article", buffer_size: 100)

      # Add objects - they're buffered locally
      {:ok, stream} = Stream.add(stream, %{properties: %{title: "Article 1"}})
      {:ok, stream} = Stream.add(stream, %{properties: %{title: "Article 2"}})

      # Add many objects at once
      objects = Enum.map(1..100, &%{properties: %{title: "Article \#{&1}"}})
      {:ok, stream} = Stream.add_many(stream, objects)

      # Manually flush if needed
      {:ok, stream} = Stream.flush(stream)

      # Close the stream and get final results
      {:ok, results} = Stream.close(stream)

      IO.puts("Inserted \#{length(results)} objects")

  ## With Multi-tenancy

      {:ok, stream} = Stream.new(client, "Article",
        buffer_size: 100,
        tenant: "tenant-a"
      )

      # All objects will be inserted with the tenant
      {:ok, stream} = Stream.add_many(stream, objects)
      {:ok, results} = Stream.close(stream)
  """

  alias WeaviateEx.Client
  alias WeaviateEx.GRPC.Services.BatchStream, as: BatchStreamService
  alias WeaviateEx.Types.UUID

  @type t :: %__MODULE__{
          client: map(),
          collection: String.t(),
          stream_handle: reference() | nil,
          buffer: [object()],
          buffer_size: pos_integer(),
          results: [batch_result()],
          state: state(),
          flush_interval_ms: pos_integer(),
          server_side_batching: boolean(),
          consistency_level: :all | :quorum | :one | nil,
          tenant: String.t() | nil,
          last_flush_at: DateTime.t() | nil,
          reconnect_attempts: non_neg_integer(),
          max_reconnect_attempts: pos_integer()
        }

  @type object :: %{
          optional(:uuid) => String.t(),
          optional(:collection) => String.t(),
          optional(:tenant) => String.t(),
          optional(:vector) => [float()],
          optional(:vectors) => %{String.t() => [float()]},
          :properties => map()
        }

  @type batch_result :: %{
          uuid: String.t() | nil,
          beacon: String.t() | nil,
          status: :success | :error,
          error: String.t() | nil
        }

  @type state :: :initialized | :connected | :streaming | :closing | :closed | :error

  @valid_states [:initialized, :connected, :streaming, :closing, :closed, :error]

  defstruct client: nil,
            collection: nil,
            stream_handle: nil,
            buffer: [],
            buffer_size: 100,
            results: [],
            state: :initialized,
            flush_interval_ms: 1000,
            server_side_batching: true,
            consistency_level: nil,
            tenant: nil,
            last_flush_at: nil,
            reconnect_attempts: 0,
            max_reconnect_attempts: 3

  @doc """
  Creates a new batch stream for the given collection.

  ## Options

  - `:buffer_size` - Number of objects to buffer before auto-flush (default: 100)
  - `:flush_interval_ms` - Auto-flush interval in milliseconds (default: 1000)
  - `:server_side_batching` - Let Weaviate manage batching (default: true, requires 1.34+)
  - `:consistency_level` - Consistency level (:all, :quorum, :one)
  - `:tenant` - Tenant name for multi-tenancy
  - `:max_reconnect_attempts` - Maximum reconnection attempts (default: 3)

  ## Example

      {:ok, stream} = Stream.new(client, "Article",
        buffer_size: 200,
        flush_interval_ms: 2000,
        consistency_level: :quorum
      )
  """
  @spec new(map(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(client, collection, opts \\ []) do
    if client[:grpc_channel] == nil do
      {:error, :no_grpc_channel}
    else
      stream = %__MODULE__{
        client: client,
        collection: collection,
        buffer_size: Keyword.get(opts, :buffer_size, 100),
        flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 1000),
        server_side_batching: Keyword.get(opts, :server_side_batching, true),
        consistency_level: Keyword.get(opts, :consistency_level),
        tenant: Keyword.get(opts, :tenant),
        max_reconnect_attempts: Keyword.get(opts, :max_reconnect_attempts, 3),
        last_flush_at: DateTime.utc_now()
      }

      {:ok, stream}
    end
  end

  @doc """
  Opens the gRPC stream connection.

  This is called automatically on first flush, but can be called manually
  to establish the connection early.
  """
  @spec connect(t()) :: {:ok, t()} | {:error, term()}
  def connect(%__MODULE__{state: :initialized} = stream) do
    channel = stream.client[:grpc_channel]
    metadata = Client.grpc_metadata(stream.client)

    case BatchStreamService.open(channel, metadata: metadata) do
      {:ok, handle} ->
        # Send start message (returns the stream handle)
        _stream =
          GRPC.Stub.send_request(
            handle,
            BatchStreamService.start_message(consistency_level: stream.consistency_level)
          )

        # Wait for started confirmation and handle response
        handle_connect_response(stream, handle)

      {:error, reason} ->
        {:error, {:open_failed, reason}}
    end
  end

  def connect(%__MODULE__{state: :connected} = stream), do: {:ok, stream}
  def connect(%__MODULE__{state: :streaming} = stream), do: {:ok, stream}
  def connect(%__MODULE__{state: state}), do: {:error, {:invalid_state, state}}

  defp handle_connect_response(stream, handle) do
    case GRPC.Stub.recv(handle, timeout: 10_000) do
      {:ok, reply} ->
        handle_start_reply(stream, handle, BatchStreamService.parse_reply(reply))

      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end

  defp handle_start_reply(stream, handle, {:started, _}) do
    {:ok, %{stream | stream_handle: handle, state: :connected}}
  end

  defp handle_start_reply(_stream, handle, other) do
    GRPC.Stub.end_stream(handle)
    {:error, {:unexpected_reply, other}}
  end

  @doc """
  Adds a single object to the buffer.

  The object will be buffered locally until the buffer is full or flush
  is called. If no UUID is provided, one will be generated.

  ## Example

      {:ok, stream} = Stream.add(stream, %{
        properties: %{title: "My Article", content: "..."}
      })
  """
  @spec add(t(), object()) :: {:ok, t()} | {:error, term()}
  def add(%__MODULE__{} = stream, object) do
    prepared = prepare_object(stream, object)
    new_buffer = [prepared | stream.buffer]
    new_stream = %{stream | buffer: new_buffer}

    if buffer_full?(new_stream) do
      flush(new_stream)
    else
      {:ok, new_stream}
    end
  end

  @doc """
  Adds multiple objects to the buffer.

  UUIDs will be generated for objects that don't have them.
  May trigger multiple flushes if objects exceed buffer size.

  ## Example

      objects = Enum.map(1..1000, &%{properties: %{index: &1}})
      {:ok, stream} = Stream.add_many(stream, objects)
  """
  @spec add_many(t(), [object()]) :: {:ok, t()} | {:error, term()}
  def add_many(%__MODULE__{} = stream, objects) when is_list(objects) do
    prepared = Enum.map(objects, &prepare_object(stream, &1))
    new_buffer = Enum.reverse(prepared) ++ stream.buffer
    new_stream = %{stream | buffer: new_buffer}

    if buffer_full?(new_stream) do
      flush(new_stream)
    else
      {:ok, new_stream}
    end
  end

  @doc """
  Flushes the current buffer to the server.

  This sends all buffered objects through the gRPC stream. If the stream
  is not yet connected, it will be connected first.

  ## Example

      {:ok, stream} = Stream.flush(stream)
  """
  @spec flush(t()) :: {:ok, t()} | {:error, term()}
  def flush(%__MODULE__{buffer: []} = stream) do
    {:ok, stream}
  end

  def flush(%__MODULE__{state: :initialized} = stream) do
    case connect(stream) do
      {:ok, connected} -> flush(connected)
      error -> error
    end
  end

  def flush(%__MODULE__{state: state} = stream) when state in [:connected, :streaming] do
    objects = Enum.reverse(stream.buffer)

    case send_batch(stream, objects) do
      {:ok, results, backoff_size} ->
        new_stream = %{
          stream
          | buffer: [],
            results: stream.results ++ results,
            state: :streaming,
            last_flush_at: DateTime.utc_now()
        }

        {:ok, apply_backoff(new_stream, backoff_size)}

      {:error, reason} ->
        # Try to reconnect
        maybe_reconnect(stream, reason)
    end
  end

  def flush(%__MODULE__{state: state}), do: {:error, {:invalid_state, state}}

  @doc """
  Closes the stream and returns all results.

  Any remaining buffered objects will be flushed before closing.

  ## Example

      {:ok, results} = Stream.close(stream)
      IO.puts("Inserted \#{length(results)} objects")
  """
  @spec close(t()) :: {:ok, [batch_result()]} | {:error, term()}
  def close(%__MODULE__{state: :initialized} = stream) do
    # Never connected, just return empty results
    {:ok, stream.results}
  end

  def close(%__MODULE__{buffer: buffer} = stream) when buffer != [] do
    case flush(stream) do
      {:ok, flushed} -> close(flushed)
      error -> error
    end
  end

  def close(%__MODULE__{stream_handle: nil} = stream) do
    {:ok, stream.results}
  end

  def close(%__MODULE__{stream_handle: handle} = stream) do
    # Send stop message (returns the stream handle)
    _stream = GRPC.Stub.send_request(handle, BatchStreamService.stop_message())

    # Collect any remaining results
    final_results = collect_remaining_results(handle, stream.results)

    # End the stream
    GRPC.Stub.end_stream(handle)

    {:ok, final_results}
  rescue
    _ -> {:ok, stream.results}
  end

  @doc """
  Attempts to reconnect the stream after a failure.

  Returns an error if max reconnection attempts have been exceeded.
  """
  @spec reconnect(t(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def reconnect(%__MODULE__{} = stream, max_attempts \\ 3) do
    if stream.reconnect_attempts >= max_attempts do
      {:error, :max_reconnect_attempts_exceeded}
    else
      # Close existing handle if any
      if stream.stream_handle do
        try do
          GRPC.Stub.end_stream(stream.stream_handle)
        rescue
          _ -> :ok
        end
      end

      # Reset state and try to connect
      reset_stream = %{
        stream
        | stream_handle: nil,
          state: :initialized,
          reconnect_attempts: stream.reconnect_attempts + 1
      }

      connect(reset_stream)
    end
  end

  @doc """
  Checks if the buffer is full.
  """
  @spec buffer_full?(t()) :: boolean()
  def buffer_full?(%__MODULE__{buffer: buffer, buffer_size: size}) do
    length(buffer) >= size
  end

  @doc """
  Returns the number of objects currently in the buffer.
  """
  @spec pending_count(t()) :: non_neg_integer()
  def pending_count(%__MODULE__{buffer: buffer}) do
    length(buffer)
  end

  @doc """
  Returns the total number of results received.
  """
  @spec results_count(t()) :: non_neg_integer()
  def results_count(%__MODULE__{results: results}) do
    length(results)
  end

  @doc """
  Returns the number of successful insertions.
  """
  @spec success_count(t()) :: non_neg_integer()
  def success_count(%__MODULE__{results: results}) do
    Enum.count(results, &(&1.status == :success))
  end

  @doc """
  Returns the number of failed insertions.
  """
  @spec error_count(t()) :: non_neg_integer()
  def error_count(%__MODULE__{results: results}) do
    Enum.count(results, &(&1.status == :error))
  end

  @doc """
  Returns only the error results.
  """
  @spec get_errors(t()) :: [batch_result()]
  def get_errors(%__MODULE__{results: results}) do
    Enum.filter(results, &(&1.status == :error))
  end

  @doc """
  Checks if a state is valid.
  """
  @spec valid_state?(atom()) :: boolean()
  def valid_state?(state), do: state in @valid_states

  @doc """
  Determines if the stream should auto-flush.

  Returns true if the buffer is full or the flush interval has passed.
  """
  @spec should_flush?(t()) :: boolean()
  def should_flush?(%__MODULE__{buffer: []}) do
    false
  end

  def should_flush?(%__MODULE__{} = stream) do
    buffer_full?(stream) || flush_interval_exceeded?(stream)
  end

  @doc """
  Prepares an object for insertion.

  Adds collection, generates UUID if missing, and adds tenant if specified.
  """
  @spec prepare_object(t(), object()) :: object()
  def prepare_object(%__MODULE__{} = stream, object) do
    object
    |> ensure_uuid()
    |> ensure_collection(stream.collection)
    |> maybe_add_tenant(stream.tenant)
  end

  @doc false
  @spec apply_backoff(t(), integer() | nil) :: t()
  def apply_backoff(%__MODULE__{} = stream, backoff_size)
      when is_integer(backoff_size) and backoff_size > 0 do
    %{stream | buffer_size: backoff_size}
  end

  def apply_backoff(%__MODULE__{} = stream, _backoff_size), do: stream

  # Private helpers

  defp ensure_uuid(object) do
    uuid = Map.get(object, :uuid) || Map.get(object, "uuid")

    if uuid do
      object
    else
      Map.put(object, :uuid, UUID.generate())
    end
  end

  defp ensure_collection(object, collection) do
    existing = Map.get(object, :collection) || Map.get(object, "collection")

    if existing do
      object
    else
      Map.put(object, :collection, collection)
    end
  end

  defp maybe_add_tenant(object, nil), do: object

  defp maybe_add_tenant(object, tenant) do
    Map.put(object, :tenant, tenant)
  end

  defp flush_interval_exceeded?(%__MODULE__{last_flush_at: nil}), do: false

  defp flush_interval_exceeded?(%__MODULE__{
         last_flush_at: last_flush,
         flush_interval_ms: interval
       }) do
    diff = DateTime.diff(DateTime.utc_now(), last_flush, :millisecond)
    diff >= interval
  end

  defp send_batch(%__MODULE__{stream_handle: handle}, objects) do
    # Send the data message (returns the stream handle)
    message = BatchStreamService.data_message(objects, [])
    _stream = GRPC.Stub.send_request(handle, message)

    # Wait for results
    case GRPC.Stub.recv(handle, timeout: 30_000) do
      {:ok, reply} ->
        case BatchStreamService.parse_reply(reply) do
          {:results, %{successes: successes, errors: errors}} ->
            results = successes ++ errors
            {:ok, results, nil}

          {:acks, %{uuids: uuids}} ->
            results = Enum.map(uuids, &%{uuid: &1, status: :success})
            {:ok, results, nil}

          {:backoff, %{batch_size: size}} ->
            # Server is asking us to slow down, but we can still consider this a success
            # The objects have been received
            results = Enum.map(objects, &%{uuid: &1[:uuid], status: :success})
            {:ok, results, size}

          {:shutting_down, _} ->
            {:error, :stream_shutting_down}

          {:shutdown, _} ->
            {:error, :stream_closed}

          other ->
            {:error, {:unexpected_reply, other}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_reconnect(
         %__MODULE__{reconnect_attempts: attempts, max_reconnect_attempts: max} = stream,
         _reason
       ) do
    if attempts >= max do
      {:error, :max_reconnect_attempts_exceeded}
    else
      case reconnect(stream, max) do
        {:ok, reconnected} ->
          # Try flushing again
          flush(reconnected)

        error ->
          error
      end
    end
  end

  defp collect_remaining_results(handle, results) do
    case GRPC.Stub.recv(handle, timeout: 5_000) do
      {:ok, reply} ->
        case BatchStreamService.parse_reply(reply) do
          {:results, %{successes: successes, errors: errors}} ->
            new_results = results ++ successes ++ errors
            collect_remaining_results(handle, new_results)

          {:shutdown, _} ->
            results

          {:shutting_down, _} ->
            collect_remaining_results(handle, results)

          _ ->
            results
        end

      {:error, _} ->
        results
    end
  end
end
