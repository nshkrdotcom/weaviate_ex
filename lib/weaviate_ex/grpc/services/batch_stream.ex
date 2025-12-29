defmodule WeaviateEx.GRPC.Services.BatchStream do
  @moduledoc """
  Bidirectional gRPC streaming for batch operations (Weaviate 1.34+).

  This module provides low-level gRPC streaming operations for batch object
  and reference insertion. For most use cases, prefer `WeaviateEx.Batch.Stream`
  which provides a higher-level API.

  ## Protocol Flow

  1. Client sends a Start message to initiate the stream
  2. Server responds with Started
  3. Client sends Data messages containing objects/references
  4. Server responds with Acks (acknowledgments) or Results (final results)
  5. Server may send Backoff to request slower sending
  6. Client sends Stop to close the stream
  7. Server responds with ShuttingDown, then Shutdown

  ## Example

      alias WeaviateEx.GRPC.Services.BatchStream

      # Open stream
      {:ok, stream} = BatchStream.open(channel)

      # Send start message
      :ok = GRPC.Stub.send_request(stream, BatchStream.start_message())

      # Wait for started confirmation
      {:ok, reply} = GRPC.Stub.recv(stream)
      {:started, _} = BatchStream.parse_reply(reply)

      # Send data
      objects = [%{uuid: "...", collection: "Test", properties: %{}}]
      :ok = GRPC.Stub.send_request(stream, BatchStream.data_message(objects, []))

      # Receive results
      {:ok, reply} = GRPC.Stub.recv(stream)
      {:results, results} = BatchStream.parse_reply(reply)

      # Close stream
      :ok = GRPC.Stub.send_request(stream, BatchStream.stop_message())
  """

  @type stream_handle :: GRPC.Client.Stream.t()
  @type object :: map()
  @type batch_ref :: map()
  @type consistency_level :: :all | :quorum | :one | nil

  @type batch_result :: %{
          uuid: String.t() | nil,
          beacon: String.t() | nil,
          status: :success | :error,
          error: String.t() | nil
        }

  @doc """
  Opens a bidirectional batch stream on the given gRPC channel.

  ## Options

  - `:timeout` - Stream open timeout in milliseconds (default: 30000)
  - `:metadata` - Additional gRPC metadata headers
  """
  @spec open(GRPC.Channel.t(), keyword()) :: {:ok, stream_handle()} | {:error, term()}
  def open(channel, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    metadata = Keyword.get(opts, :metadata, %{})

    try do
      stream =
        Weaviate.V1.Weaviate.Stub.batch_stream(channel, metadata: metadata, timeout: timeout)

      {:ok, stream}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Sends objects through an open batch stream.
  """
  @spec send_objects(stream_handle(), [object()]) :: stream_handle()
  def send_objects(stream, objects) when is_list(objects) do
    message = data_message(objects, [])
    GRPC.Stub.send_request(stream, message)
  end

  @doc """
  Sends references through an open batch stream.
  """
  @spec send_references(stream_handle(), [batch_ref()]) :: stream_handle()
  def send_references(stream, references) when is_list(references) do
    message = data_message([], references)
    GRPC.Stub.send_request(stream, message)
  end

  @doc """
  Receives results from the batch stream.

  Returns the next reply from the stream, or an error if the stream
  is closed or times out.
  """
  @spec receive_results(stream_handle(), timeout()) ::
          {:ok, term()} | {:error, term()}
  def receive_results(stream, timeout \\ 30_000) do
    case GRPC.Stub.recv(stream, timeout: timeout) do
      {:ok, reply} -> {:ok, parse_reply(reply)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Closes the batch stream gracefully.

  Sends a stop message and waits for the server to acknowledge shutdown.
  """
  @spec close(stream_handle()) :: :ok | {:error, term()}
  def close(stream) do
    GRPC.Stub.send_request(stream, stop_message())
    GRPC.Stub.end_stream(stream)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc """
  Creates a Start message for initiating the batch stream.

  ## Options

  - `:consistency_level` - Consistency level (:all, :quorum, :one)
  """
  @spec start_message(keyword()) :: Weaviate.V1.BatchStreamRequest.t()
  def start_message(opts \\ []) do
    consistency = Keyword.get(opts, :consistency_level)

    start = %Weaviate.V1.BatchStreamRequest.Start{
      consistency_level: consistency_level_to_proto(consistency)
    }

    %Weaviate.V1.BatchStreamRequest{message: {:start, start}}
  end

  @doc """
  Creates a Stop message for gracefully closing the batch stream.
  """
  @spec stop_message() :: Weaviate.V1.BatchStreamRequest.t()
  def stop_message do
    %Weaviate.V1.BatchStreamRequest{
      message: {:stop, %Weaviate.V1.BatchStreamRequest.Stop{}}
    }
  end

  @doc """
  Creates a Data message containing objects and/or references.
  """
  @spec data_message([object()], [batch_ref()]) :: Weaviate.V1.BatchStreamRequest.t()
  def data_message(objects, references) do
    objects_data =
      case objects do
        [] ->
          nil

        objs ->
          %Weaviate.V1.BatchStreamRequest.Data.Objects{
            values: Enum.map(objs, &build_batch_object/1)
          }
      end

    references_data =
      case references do
        [] ->
          nil

        refs ->
          %Weaviate.V1.BatchStreamRequest.Data.References{
            values: Enum.map(refs, &build_batch_reference/1)
          }
      end

    data = %Weaviate.V1.BatchStreamRequest.Data{
      objects: objects_data,
      references: references_data
    }

    %Weaviate.V1.BatchStreamRequest{message: {:data, data}}
  end

  @doc """
  Builds a BatchObject from a map.
  """
  @spec build_batch_object(object()) :: Weaviate.V1.BatchObject.t()
  def build_batch_object(obj) do
    properties = build_properties(Map.get(obj, :properties, %{}))

    %Weaviate.V1.BatchObject{
      uuid: Map.get(obj, :uuid) || Map.get(obj, "uuid"),
      collection: Map.get(obj, :collection) || Map.get(obj, "collection"),
      tenant: Map.get(obj, :tenant) || Map.get(obj, "tenant") || "",
      properties: properties,
      vector_bytes: encode_vector(Map.get(obj, :vector)),
      vectors: encode_named_vectors(Map.get(obj, :vectors))
    }
  end

  @doc """
  Builds a BatchReference from a map.
  """
  @spec build_batch_reference(batch_ref()) :: Weaviate.V1.BatchReference.t()
  def build_batch_reference(ref) do
    %Weaviate.V1.BatchReference{
      name: Map.get(ref, :name) || Map.get(ref, "name"),
      from_collection: Map.get(ref, :from_collection) || Map.get(ref, "from_collection"),
      from_uuid: Map.get(ref, :from_uuid) || Map.get(ref, "from_uuid"),
      to_collection: Map.get(ref, :to_collection) || Map.get(ref, "to_collection"),
      to_uuid: Map.get(ref, :to_uuid) || Map.get(ref, "to_uuid"),
      tenant: Map.get(ref, :tenant) || Map.get(ref, "tenant") || ""
    }
  end

  @doc """
  Parses a BatchStreamReply into a more usable format.
  """
  @spec parse_reply(Weaviate.V1.BatchStreamReply.t()) :: {atom(), map()}
  def parse_reply(%Weaviate.V1.BatchStreamReply{message: message}) do
    case message do
      {:started, _} ->
        {:started, %{}}

      {:shutdown, _} ->
        {:shutdown, %{}}

      {:shutting_down, _} ->
        {:shutting_down, %{}}

      {:backoff, %{batch_size: batch_size}} ->
        {:backoff, %{batch_size: batch_size}}

      {:acks, %{uuids: uuids, beacons: beacons}} ->
        {:acks, %{uuids: uuids, beacons: beacons}}

      {:results, results} ->
        {:results, parse_results(results)}

      nil ->
        {:unknown, %{}}
    end
  end

  @doc """
  Converts a consistency level atom to the protobuf enum value.
  """
  @spec consistency_level_to_proto(consistency_level()) :: atom() | nil
  def consistency_level_to_proto(nil), do: nil
  def consistency_level_to_proto(:all), do: :CONSISTENCY_LEVEL_ALL
  def consistency_level_to_proto(:quorum), do: :CONSISTENCY_LEVEL_QUORUM
  def consistency_level_to_proto(:one), do: :CONSISTENCY_LEVEL_ONE

  # Private helpers

  defp build_properties(props) when is_map(props) do
    non_ref_props =
      props
      |> Enum.map(fn {k, v} -> {to_string(k), wrap_value(v)} end)
      |> Map.new()

    struct = %Google.Protobuf.Struct{fields: non_ref_props}

    %Weaviate.V1.BatchObject.Properties{
      non_ref_properties: struct,
      single_target_ref_props: [],
      multi_target_ref_props: [],
      number_array_properties: [],
      int_array_properties: [],
      text_array_properties: [],
      boolean_array_properties: [],
      object_properties: [],
      object_array_properties: [],
      empty_list_props: []
    }
  end

  defp wrap_value(nil), do: %Google.Protobuf.Value{kind: {:null_value, :NULL_VALUE}}
  defp wrap_value(v) when is_boolean(v), do: %Google.Protobuf.Value{kind: {:bool_value, v}}
  defp wrap_value(v) when is_number(v), do: %Google.Protobuf.Value{kind: {:number_value, v / 1}}
  defp wrap_value(v) when is_binary(v), do: %Google.Protobuf.Value{kind: {:string_value, v}}

  defp wrap_value(v) when is_list(v) do
    values = Enum.map(v, &wrap_value/1)
    %Google.Protobuf.Value{kind: {:list_value, %Google.Protobuf.ListValue{values: values}}}
  end

  defp wrap_value(v) when is_map(v) do
    fields = Map.new(v, fn {k, val} -> {to_string(k), wrap_value(val)} end)
    %Google.Protobuf.Value{kind: {:struct_value, %Google.Protobuf.Struct{fields: fields}}}
  end

  defp encode_vector(nil), do: <<>>

  defp encode_vector(vector) when is_list(vector) do
    vector
    |> Enum.map(&<<&1::float-32-little>>)
    |> IO.iodata_to_binary()
  end

  defp encode_named_vectors(nil), do: []

  defp encode_named_vectors(vectors) when is_map(vectors) do
    Enum.map(vectors, fn {name, vector} ->
      %Weaviate.V1.Vectors{
        name: to_string(name),
        vector_bytes: encode_vector(vector)
      }
    end)
  end

  defp parse_results(%Weaviate.V1.BatchStreamReply.Results{
         successes: successes,
         errors: errors
       }) do
    parsed_successes =
      Enum.map(successes, fn success ->
        case success.detail do
          {:uuid, uuid} -> %{uuid: uuid, beacon: nil, status: :success}
          {:beacon, beacon} -> %{uuid: nil, beacon: beacon, status: :success}
          nil -> %{uuid: nil, beacon: nil, status: :success}
        end
      end)

    parsed_errors =
      Enum.map(errors, fn error ->
        {uuid, beacon} =
          case error.detail do
            {:uuid, uuid} -> {uuid, nil}
            {:beacon, beacon} -> {nil, beacon}
            nil -> {nil, nil}
          end

        %{uuid: uuid, beacon: beacon, status: :error, error: error.error}
      end)

    %{
      successes: parsed_successes,
      errors: parsed_errors
    }
  end
end
