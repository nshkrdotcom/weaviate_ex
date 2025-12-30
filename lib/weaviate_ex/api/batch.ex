defmodule WeaviateEx.API.Batch do
  @moduledoc """
  Batch API for Weaviate with gRPC support.

  This module powers the public `WeaviateEx.Batch` wrapper while providing
  structured summaries for batch create/delete operations.

  When used with a client that has an active gRPC connection, operations
  use gRPC for optimal performance. Falls back to HTTP otherwise.

  ## Wait for Vector Indexing

  After batch operations, vectors are indexed asynchronously. Use
  `wait_for_vector_indexing/3` to ensure all vectors are queryable:

      {:ok, _} = Batch.create_objects(client, objects)
      :ok = Batch.wait_for_vector_indexing(client, "Article")
  """

  alias WeaviateEx.Batch.VectorIndexing
  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Services.Batch, as: GRPCBatch

  defmodule Result do
    @moduledoc """
    Structured summary for batch operations.
    """

    @enforce_keys [:successful, :errors, :statistics]
    defstruct successful: [],
              errors: [],
              statistics: %{processed: 0, successful: 0, failed: 0}

    @typedoc """
    Summary returned when `summary: true` is passed to batch operations.
    """
    @type t :: %__MODULE__{
            successful: list(),
            errors: list(),
            statistics: %{
              processed: non_neg_integer(),
              successful: non_neg_integer(),
              failed: non_neg_integer()
            }
          }
  end

  @type t :: Result.t()

  @type opts :: keyword()
  @type objects_payload :: list(map())
  @type delete_payload :: map()

  @doc """
  Create objects in batch.

  Uses gRPC when available for optimal performance, falls back to HTTP otherwise.

  Pass `summary: true` to receive a `%WeaviateEx.API.Batch.Result{}` summary instead of the raw payload.
  """
  @spec create_objects(Client.t(), objects_payload(), opts()) ::
          {:ok, map() | Result.t()} | {:error, Error.t()}
  def create_objects(client, objects, opts \\ []) when is_list(objects) do
    summary? = Keyword.get(opts, :summary, false)
    request_opts = Keyword.drop(opts, [:summary])

    result =
      if grpc_available?(client) do
        create_objects_grpc(client, objects, request_opts)
      else
        create_objects_http(client, objects, request_opts)
      end

    case result do
      {:ok, response} ->
        case ensure_not_all_failed(response) do
          {:error, error} ->
            {:error, error}

          {:ok, response} when summary? ->
            {:ok, build_summary(response)}

          {:ok, response} ->
            {:ok, normalize_batch_response(response)}
        end

      error ->
        error
    end
  end

  defp grpc_available?(client) do
    channel = Client.grpc_channel(client)
    not is_nil(channel)
  end

  defp create_objects_grpc(client, objects, opts) do
    with {:ok, channel} <- get_grpc_channel(client),
         grpc_objects = convert_objects_to_grpc(objects, opts),
         grpc_opts = build_grpc_opts(client, opts),
         {:ok, reply} <- GRPCBatch.insert_objects(channel, grpc_objects, grpc_opts) do
      parsed = GRPCBatch.parse_result(reply)
      {:ok, %{"results" => build_http_compatible_results(grpc_objects, parsed)}}
    end
  end

  defp get_grpc_channel(client) do
    case Client.grpc_channel(client) do
      nil ->
        {:error, Error.exception(type: :connection_error, message: "gRPC channel not available")}

      channel ->
        {:ok, channel}
    end
  end

  defp convert_objects_to_grpc(objects, opts) do
    default_tenant = Keyword.get(opts, :tenant)
    Enum.map(objects, &convert_single_object_to_grpc(&1, default_tenant))
  end

  defp convert_single_object_to_grpc(obj, default_tenant) do
    %{
      collection: obj["class"] || obj[:class],
      properties: obj["properties"] || obj[:properties] || %{},
      uuid: obj["id"] || obj[:id],
      vector: obj["vector"] || obj[:vector],
      tenant: obj["tenant"] || obj[:tenant] || default_tenant
    }
  end

  defp build_grpc_opts(client, opts) do
    [
      consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level)),
      api_key: client.config.api_key,
      auth: client.config.auth,
      token_manager: client.config.token_manager,
      additional_headers: client.config.additional_headers,
      timeout: Keyword.get(opts, :timeout, 90_000)
    ]
  end

  defp create_objects_http(client, objects, opts) do
    path =
      "/v1/batch/objects" <>
        build_query(opts, [:tenant, :consistency_level, :wait_for_completion])

    body = %{"objects" => objects}
    Client.request(client, :post, path, body, opts)
  end

  defp map_consistency_level(nil), do: nil
  defp map_consistency_level(:one), do: :one
  defp map_consistency_level(:quorum), do: :quorum
  defp map_consistency_level(:all), do: :all
  defp map_consistency_level("ONE"), do: :one
  defp map_consistency_level("QUORUM"), do: :quorum
  defp map_consistency_level("ALL"), do: :all
  defp map_consistency_level(_), do: nil

  defp build_http_compatible_results(objects, %{errors: errors}) do
    error_map = build_error_map(errors)

    objects
    |> Enum.with_index()
    |> Enum.map(fn {obj, idx} -> build_object_result(obj, idx, error_map) end)
  end

  defp build_error_map(errors) do
    Map.new(errors, fn e -> {e.index, e.error} end)
  end

  defp build_object_result(obj, idx, error_map) do
    case Map.fetch(error_map, idx) do
      {:ok, error_message} -> build_failed_result(obj, error_message)
      :error -> build_success_result(obj)
    end
  end

  defp build_failed_result(obj, error_message) do
    %{
      "id" => obj.uuid,
      "class" => obj.collection,
      "status" => "FAILED",
      "result" => %{"errors" => [%{"message" => error_message}]}
    }
  end

  defp build_success_result(obj) do
    %{
      "id" => obj.uuid,
      "class" => obj.collection,
      "status" => "SUCCESS"
    }
  end

  @doc """
  Delete objects in batch using match criteria.

  Uses gRPC when available for optimal performance, falls back to HTTP otherwise.
  """
  @spec delete_objects(Client.t(), delete_payload(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete_objects(client, criteria, opts \\ []) when is_map(criteria) do
    if grpc_available?(client) do
      delete_objects_grpc(client, criteria, opts)
    else
      delete_objects_http(client, criteria, opts)
    end
  end

  defp delete_objects_grpc(client, criteria, opts) do
    case Client.grpc_channel(client) do
      nil ->
        {:error, Error.exception(type: :connection_error, message: "gRPC channel not available")}

      channel ->
        collection = criteria["class"] || criteria[:class]
        filter = criteria["where"] || criteria[:where]

        grpc_opts = [
          consistency_level: map_consistency_level(Keyword.get(opts, :consistency_level)),
          tenant: Keyword.get(opts, :tenant),
          verbose: Keyword.get(opts, :verbose, false),
          dry_run: Keyword.get(opts, :dry_run, false),
          api_key: client.config.api_key,
          auth: client.config.auth,
          token_manager: client.config.token_manager,
          additional_headers: client.config.additional_headers,
          timeout: Keyword.get(opts, :timeout, 90_000)
        ]

        # Convert where filter to gRPC format
        grpc_filter = convert_where_filter(filter)

        case GRPCBatch.delete_objects(channel, collection, grpc_filter, grpc_opts) do
          {:ok, reply} ->
            # Convert gRPC reply to HTTP-like format
            {:ok,
             %{
               "results" => %{
                 "matches" => reply.matches,
                 "successful" => reply.successful,
                 "failed" => reply.failed,
                 "dryRun" => reply.dry_run
               }
             }}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp delete_objects_http(client, criteria, opts) do
    path =
      "/v1/batch/objects" <>
        build_query(opts, [:tenant, :consistency_level, :wait_for_completion])

    body = %{"match" => criteria}
    Client.request(client, :delete, path, body, opts)
  end

  defp convert_where_filter(nil), do: nil

  defp convert_where_filter(filter) when is_map(filter) do
    %{
      path: get_filter_field(filter, [:path, "path"], []),
      operator: convert_operator(get_filter_field(filter, [:operator, "operator"], nil)),
      value_text: get_filter_value(filter, :text),
      value_int: get_filter_value(filter, :int),
      value_number: get_filter_value(filter, :number),
      value_boolean: get_filter_value(filter, :boolean)
    }
  end

  defp get_filter_field(filter, keys, default) do
    Enum.find_value(keys, default, fn key -> filter[key] end)
  end

  defp get_filter_value(filter, :text) do
    get_filter_field(filter, ["valueText", :valueText, :value_text], nil)
  end

  defp get_filter_value(filter, :int) do
    get_filter_field(filter, ["valueInt", :valueInt, :value_int], nil)
  end

  defp get_filter_value(filter, :number) do
    get_filter_field(filter, ["valueNumber", :valueNumber, :value_number], nil)
  end

  defp get_filter_value(filter, :boolean) do
    get_filter_field(filter, ["valueBoolean", :valueBoolean, :value_boolean], nil)
  end

  defp convert_operator("Equal"), do: :equal
  defp convert_operator("NotEqual"), do: :not_equal
  defp convert_operator("GreaterThan"), do: :greater_than
  defp convert_operator("GreaterThanEqual"), do: :greater_than_equal
  defp convert_operator("LessThan"), do: :less_than
  defp convert_operator("LessThanEqual"), do: :less_than_equal
  defp convert_operator("Like"), do: :like
  defp convert_operator("IsNull"), do: :is_null
  defp convert_operator("ContainsAny"), do: :contains_any
  defp convert_operator("ContainsAll"), do: :contains_all
  defp convert_operator(op) when is_atom(op), do: op
  defp convert_operator(_), do: nil

  defp build_summary(response) do
    objects = extract_objects(response)

    {successful, failed} =
      Enum.split_with(objects, fn item ->
        case Map.get(item, "status") do
          nil -> false
          status -> String.upcase(status) == "SUCCESS"
        end
      end)

    errors =
      failed
      |> Enum.map(&build_error/1)
      |> Enum.reject(&is_nil/1)

    %Result{
      successful: successful,
      errors: errors,
      statistics: %{
        processed: length(objects),
        successful: length(successful),
        failed: length(errors)
      }
    }
  end

  defp extract_objects(%{"results" => %{"objects" => objects}}) when is_list(objects), do: objects
  defp extract_objects(%{"results" => results}) when is_list(results), do: results
  defp extract_objects(%{} = response) when not is_struct(response), do: []
  defp extract_objects(objects) when is_list(objects), do: objects
  defp extract_objects(_), do: []

  defp build_error(item) do
    messages =
      item
      |> Map.get("result", %{})
      |> Map.get("errors", [])
      |> List.wrap()
      |> Enum.map(fn
        %{"message" => message} -> message
        %{"error" => message} -> message
        other when is_binary(other) -> other
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    %{
      id: item["id"],
      class: item["class"],
      status: item["status"],
      messages: messages,
      raw: item
    }
  end

  defp normalize_batch_response(%{"results" => results}) when is_list(results) do
    %{"results" => results}
  end

  defp normalize_batch_response(results) when is_list(results) do
    %{"results" => results}
  end

  defp normalize_batch_response(response), do: response

  defp ensure_not_all_failed(response) do
    objects = extract_objects(response)

    if all_failed_objects?(objects) do
      {:error, build_all_failed_error(objects)}
    else
      {:ok, response}
    end
  end

  defp all_failed_objects?([]), do: false

  defp all_failed_objects?(objects) do
    Enum.all?(objects, fn item ->
      status = item["status"] || item[:status]

      case status do
        nil -> false
        :failed -> true
        other -> String.upcase(to_string(other)) == "FAILED"
      end
    end)
  end

  defp build_all_failed_error(objects) do
    errors = Enum.map(objects, &build_error/1)

    Error.exception(
      type: :batch_all_failed,
      message: "All batch objects failed",
      details: %{failed: length(objects), errors: errors}
    )
  end

  defp build_query(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _} -> key in allowed_keys end)
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{encode_value(value)}" end)

    if params == "", do: "", else: "?" <> params
  end

  defp encode_value(value) when is_list(value) do
    value
    |> Enum.map_join(",", &to_string/1)
    |> URI.encode_www_form()
  end

  defp encode_value(value) do
    value
    |> to_string()
    |> URI.encode_www_form()
  end

  @doc """
  Wait for all vectors to be indexed after batch operations.

  After batch inserts, vectors are indexed asynchronously. This function
  polls shard status until all vectors are indexed and queryable.

  ## Options

  - `:timeout` - Maximum wait time in milliseconds (default: 60_000)
  - `:poll_interval` - Milliseconds between status checks (default: 250)
  - `:how_many_failures` - Number of consecutive failures before giving up (default: 5)
  - `:tenant` - Filter to specific tenant (optional)

  ## Examples

      # Wait for all shards in a collection
      :ok = Batch.wait_for_vector_indexing(client, "Article")

      # Wait with custom timeout
      :ok = Batch.wait_for_vector_indexing(client, "Article", timeout: 120_000)

      # Wait for specific tenant
      :ok = Batch.wait_for_vector_indexing(client, "Article", tenant: "tenant-a")

  ## Returns

  - `:ok` - All vectors indexed
  - `{:error, :timeout}` - Timed out waiting for indexing
  - `{:error, {:max_failures_exceeded, last_error}}` - Too many consecutive failures
  """
  @spec wait_for_vector_indexing(Client.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def wait_for_vector_indexing(client, collection, opts \\ []) do
    VectorIndexing.wait_for_indexing(client, collection, opts)
  end
end
