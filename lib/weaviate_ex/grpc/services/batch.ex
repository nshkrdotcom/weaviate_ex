defmodule WeaviateEx.GRPC.Services.Batch do
  @moduledoc """
  gRPC Batch service for bulk operations.

  This module provides high-level functions for batch insert, update,
  and delete operations using gRPC. Supports both unary and streaming modes.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      objects = [
        %{collection: "Article", properties: %{title: "First"}},
        %{collection: "Article", properties: %{title: "Second"}}
      ]

      {:ok, result} = Batch.insert_objects(channel, objects)
  """

  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel

  # Import generated protobuf modules
  alias Weaviate.V1.{
    BatchDeleteReply,
    BatchDeleteRequest,
    BatchObject,
    BatchObjectsReply,
    BatchObjectsRequest,
    BatchReference,
    BatchReferencesReply,
    BatchReferencesRequest
  }

  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @type batch_opts :: [
          consistency_level: :one | :quorum | :all,
          timeout: non_neg_integer()
        ]

  @type object :: %{
          required(:collection) => String.t(),
          required(:properties) => map(),
          optional(:uuid) => String.t(),
          optional(:vector) => [float()],
          optional(:tenant) => String.t()
        }

  @type batch_ref :: %{
          required(:from_collection) => String.t(),
          required(:from_uuid) => String.t(),
          required(:from_property) => String.t(),
          required(:to_uuid) => String.t(),
          optional(:to_collection) => String.t(),
          optional(:tenant) => String.t()
        }

  @doc """
  Insert multiple objects in a single batch request.

  ## Options

    * `:consistency_level` - Consistency level (:one, :quorum, :all)
    * `:timeout` - Request timeout in milliseconds (default: 90000)

  ## Examples

      objects = [
        %{collection: "Article", properties: %{"title" => "First"}},
        %{collection: "Article", properties: %{"title" => "Second"}}
      ]

      {:ok, result} = Batch.insert_objects(channel, objects)
  """
  @spec insert_objects(GRPC.Channel.t(), [object()], batch_opts()) ::
          {:ok, BatchObjectsReply.t()} | {:error, Error.t()}
  def insert_objects(channel, objects, opts \\ []) when is_list(objects) do
    batch_objects = Enum.map(objects, &build_batch_object/1)

    request = %BatchObjectsRequest{
      objects: batch_objects,
      consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level))
    }

    execute_batch_objects(channel, request, opts)
  end

  @doc """
  Insert multiple references in a single batch request.

  ## Examples

      refs = [
        %{from_collection: "Article", from_uuid: "uuid1", from_property: "author", to_uuid: "uuid2"},
        %{from_collection: "Article", from_uuid: "uuid3", from_property: "author", to_uuid: "uuid4"}
      ]

      {:ok, result} = Batch.insert_references(channel, refs)
  """
  @spec insert_references(GRPC.Channel.t(), [batch_ref()], batch_opts()) ::
          {:ok, BatchReferencesReply.t()} | {:error, Error.t()}
  def insert_references(channel, references, opts \\ []) when is_list(references) do
    batch_refs = Enum.map(references, &build_batch_reference/1)

    request = %BatchReferencesRequest{
      references: batch_refs,
      consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level))
    }

    execute_batch_references(channel, request, opts)
  end

  @doc """
  Delete multiple objects matching a filter.

  ## Examples

      filter = %{path: ["category"], operator: :equal, value_text: "old"}

      {:ok, result} = Batch.delete_objects(channel, "Article", filter)
  """
  @spec delete_objects(GRPC.Channel.t(), String.t(), map(), batch_opts()) ::
          {:ok, BatchDeleteReply.t()} | {:error, Error.t()}
  def delete_objects(channel, collection, filter, opts \\ []) do
    request = %BatchDeleteRequest{
      collection: collection,
      filters: build_filter(filter),
      consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level)),
      tenant: Keyword.get(opts, :tenant, ""),
      verbose: Keyword.get(opts, :verbose, false),
      dry_run: Keyword.get(opts, :dry_run, false)
    }

    execute_batch_delete(channel, request, opts)
  end

  @doc """
  Parse batch result and return failure counts and errors.

  Note: The successful count is not directly available from the gRPC reply.
  Use the object count minus failed count to derive successful count.

  ## Examples

      {:ok, reply} = Batch.insert_objects(channel, objects)
      %{failed: 2, errors: [...]} = Batch.parse_result(reply)
  """
  @spec parse_result(BatchObjectsReply.t() | BatchReferencesReply.t()) :: %{
          failed: non_neg_integer(),
          errors: [map()],
          took_ms: float()
        }
  def parse_result(%BatchObjectsReply{errors: errors, took: took}) do
    failed_count = length(errors)

    %{
      failed: failed_count,
      errors: Enum.map(errors, fn e -> %{index: e.index, error: e.error} end),
      took_ms: took * 1000
    }
  end

  def parse_result(%BatchReferencesReply{errors: errors, took: took}) do
    failed_count = length(errors)

    %{
      failed: failed_count,
      errors: Enum.map(errors, fn e -> %{index: e.index, error: e.error} end),
      took_ms: took * 1000
    }
  end

  # Private functions

  defp build_batch_object(object) do
    properties = build_object_properties(object.properties)

    batch_obj = %BatchObject{
      collection: object[:collection] || object["collection"],
      properties: properties,
      uuid: object[:uuid] || object["uuid"] || "",
      tenant: object[:tenant] || object["tenant"] || ""
    }

    # Add vector if present
    case object[:vector] || object["vector"] do
      nil ->
        batch_obj

      vector when is_list(vector) ->
        vector_bytes =
          vector
          |> Enum.map(&<<&1::float-little-32>>)
          |> IO.iodata_to_binary()

        %{batch_obj | vector_bytes: vector_bytes}
    end
  end

  defp build_object_properties(props) when is_map(props) do
    # Convert properties to Google.Protobuf.Struct format
    struct_value =
      props
      |> Enum.map(fn {k, v} ->
        key = if is_atom(k), do: Atom.to_string(k), else: k
        {key, build_struct_value(v)}
      end)
      |> Map.new()

    %BatchObject.Properties{
      non_ref_properties: %Google.Protobuf.Struct{fields: struct_value}
    }
  end

  defp build_struct_value(value) when is_binary(value) do
    %Google.Protobuf.Value{kind: {:string_value, value}}
  end

  defp build_struct_value(value) when is_number(value) do
    %Google.Protobuf.Value{kind: {:number_value, value / 1}}
  end

  defp build_struct_value(value) when is_boolean(value) do
    %Google.Protobuf.Value{kind: {:bool_value, value}}
  end

  defp build_struct_value(nil) do
    %Google.Protobuf.Value{kind: {:null_value, :NULL_VALUE}}
  end

  defp build_struct_value(value) when is_list(value) do
    list_values = Enum.map(value, &build_struct_value/1)
    %Google.Protobuf.Value{kind: {:list_value, %Google.Protobuf.ListValue{values: list_values}}}
  end

  defp build_struct_value(value) when is_map(value) do
    fields =
      value
      |> Enum.map(fn {k, v} ->
        key = if is_atom(k), do: Atom.to_string(k), else: k
        {key, build_struct_value(v)}
      end)
      |> Map.new()

    %Google.Protobuf.Value{kind: {:struct_value, %Google.Protobuf.Struct{fields: fields}}}
  end

  defp build_batch_reference(ref) do
    %BatchReference{
      from_collection: ref[:from_collection] || ref["from_collection"],
      from_uuid: ref[:from_uuid] || ref["from_uuid"],
      name: ref[:from_property] || ref["from_property"],
      to_uuid: ref[:to_uuid] || ref["to_uuid"],
      to_collection: ref[:to_collection] || ref["to_collection"],
      tenant: ref[:tenant] || ref["tenant"] || ""
    }
  end

  defp build_filter(nil), do: nil

  defp build_filter(filter) when is_map(filter) do
    filter
    |> build_base_filter()
    |> add_test_value(filter)
  end

  defp build_base_filter(filter) do
    operator = map_operator(get_field(filter, [:operator, "operator"]))
    path = get_field(filter, [:path, "path"]) || []

    %Weaviate.V1.Filters{
      operator: operator,
      target: %Weaviate.V1.FilterTarget{
        target: {:property, Enum.join(path, ".")}
      }
    }
  end

  defp add_test_value(base_filter, filter) do
    case extract_test_value(filter) do
      nil -> base_filter
      test_value -> %{base_filter | test_value: test_value}
    end
  end

  defp extract_test_value(filter) do
    extract_value_text(filter) ||
      extract_value_int(filter) ||
      extract_value_number(filter) ||
      extract_value_boolean(filter)
  end

  defp extract_value_text(filter) do
    case get_field(filter, [:value_text, "value_text"]) do
      nil -> nil
      value -> {:value_text, value}
    end
  end

  defp extract_value_int(filter) do
    case get_field(filter, [:value_int, "value_int"]) do
      nil -> nil
      value -> {:value_int, value}
    end
  end

  defp extract_value_number(filter) do
    case get_field(filter, [:value_number, "value_number"]) do
      nil -> nil
      value -> {:value_number, value}
    end
  end

  defp extract_value_boolean(filter) do
    case get_field(filter, [:value_boolean, "value_boolean"]) do
      nil -> nil
      value -> {:value_boolean, value}
    end
  end

  defp get_field(map, keys) do
    Enum.find_value(keys, fn key -> map[key] end)
  end

  defp map_operator(:equal), do: :OPERATOR_EQUAL
  defp map_operator(:not_equal), do: :OPERATOR_NOT_EQUAL
  defp map_operator(:greater_than), do: :OPERATOR_GREATER_THAN
  defp map_operator(:greater_than_equal), do: :OPERATOR_GREATER_THAN_EQUAL
  defp map_operator(:less_than), do: :OPERATOR_LESS_THAN
  defp map_operator(:less_than_equal), do: :OPERATOR_LESS_THAN_EQUAL
  defp map_operator(:like), do: :OPERATOR_LIKE
  defp map_operator(:is_null), do: :OPERATOR_IS_NULL
  defp map_operator(:contains_any), do: :OPERATOR_CONTAINS_ANY
  defp map_operator(:contains_all), do: :OPERATOR_CONTAINS_ALL
  defp map_operator(_), do: :OPERATOR_UNSPECIFIED

  defp map_consistency_level(nil), do: :CONSISTENCY_LEVEL_UNSPECIFIED
  defp map_consistency_level(:one), do: :CONSISTENCY_LEVEL_ONE
  defp map_consistency_level(:quorum), do: :CONSISTENCY_LEVEL_QUORUM
  defp map_consistency_level(:all), do: :CONSISTENCY_LEVEL_ALL
  defp map_consistency_level(_), do: :CONSISTENCY_LEVEL_UNSPECIFIED

  defp execute_batch_objects(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 90_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.batch_objects(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end

  defp execute_batch_references(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 90_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.batch_references(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end

  defp execute_batch_delete(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 90_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.batch_delete(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end
end
