defmodule WeaviateEx.GRPC.Services.Search do
  @moduledoc """
  gRPC Search service for vector queries.

  This module provides high-level functions for performing vector searches
  against Weaviate using gRPC.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      {:ok, results} = Search.near_vector(channel, "Article", [0.1, 0.2, ...],
        limit: 10,
        return_properties: ["title", "content"]
      )
  """

  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel

  # Import generated protobuf modules
  alias Weaviate.V1.{
    BM25,
    Hybrid,
    MetadataRequest,
    NearObject,
    NearTextSearch,
    NearVector,
    PropertiesRequest,
    SearchReply,
    SearchRequest
  }

  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @type search_opts :: [
          limit: non_neg_integer(),
          offset: non_neg_integer(),
          return_properties: [String.t()],
          return_metadata: [atom()],
          tenant: String.t(),
          certainty: float(),
          distance: float(),
          autocut: non_neg_integer()
        ]

  @doc """
  Perform a vector similarity search.

  ## Options

    * `:limit` - Maximum number of results (default: 10)
    * `:offset` - Number of results to skip
    * `:return_properties` - List of property names to return
    * `:return_metadata` - List of metadata fields (e.g., [:uuid, :distance, :vector])
    * `:tenant` - Tenant name for multi-tenant collections
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold

  ## Examples

      {:ok, results} = Search.near_vector(channel, "Article", vector,
        limit: 10,
        return_properties: ["title", "content"]
      )
  """
  @spec near_vector(GRPC.Channel.t(), String.t(), [float()], search_opts()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def near_vector(channel, collection, vector, opts \\ []) do
    near_vector_msg = build_near_vector(vector, opts)

    request = build_search_request(collection, opts)
    request = %{request | near_vector: near_vector_msg}

    execute_search(channel, request, opts)
  end

  @doc """
  Perform a text-based vector search using a text-to-vector model.

  ## Options

    * `:move_to` - Concepts to move towards
    * `:move_away` - Concepts to move away from
    * Plus all options from `near_vector/4`

  ## Examples

      {:ok, results} = Search.near_text(channel, "Article", "machine learning",
        limit: 10
      )
  """
  @spec near_text(GRPC.Channel.t(), String.t(), String.t() | [String.t()], search_opts()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def near_text(channel, collection, query, opts \\ []) do
    concepts = if is_binary(query), do: [query], else: query

    near_text_msg = %NearTextSearch{
      query: concepts,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }

    request = build_search_request(collection, opts)
    request = %{request | near_text: near_text_msg}

    execute_search(channel, request, opts)
  end

  @doc """
  Perform a search for objects similar to a given object.

  ## Examples

      {:ok, results} = Search.near_object(channel, "Article", "uuid-of-object",
        limit: 10
      )
  """
  @spec near_object(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def near_object(channel, collection, object_id, opts \\ []) do
    near_object_msg = %NearObject{
      id: object_id,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }

    request = build_search_request(collection, opts)
    request = %{request | near_object: near_object_msg}

    execute_search(channel, request, opts)
  end

  @doc """
  Perform a BM25 keyword search.

  ## Options

    * `:properties` - List of properties to search in

  ## Examples

      {:ok, results} = Search.bm25(channel, "Article", "machine learning",
        properties: ["title", "content"],
        limit: 10
      )
  """
  @spec bm25(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def bm25(channel, collection, query, opts \\ []) do
    bm25_msg = %BM25{
      query: query,
      properties: Keyword.get(opts, :properties, [])
    }

    request = build_search_request(collection, opts)
    request = %{request | bm25_search: bm25_msg}

    execute_search(channel, request, opts)
  end

  @doc """
  Perform a hybrid search combining vector and keyword search.

  ## Options

    * `:alpha` - Weight between vector (1.0) and keyword (0.0) search
    * `:fusion_type` - Fusion algorithm (:ranked or :relative_score)
    * `:properties` - Properties to search for BM25

  ## Examples

      {:ok, results} = Search.hybrid(channel, "Article", "machine learning",
        alpha: 0.5,
        limit: 10
      )
  """
  @spec hybrid(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def hybrid(channel, collection, query, opts \\ []) do
    alpha = Keyword.get(opts, :alpha, 0.5)
    properties = Keyword.get(opts, :properties, [])

    hybrid_msg = %Hybrid{
      query: query,
      alpha: alpha,
      properties: properties
    }

    request = build_search_request(collection, opts)
    request = %{request | hybrid_search: hybrid_msg}

    execute_search(channel, request, opts)
  end

  @doc """
  Execute a raw SearchRequest.

  Useful for complex queries that need full control over the request.

  ## Examples

      request = %SearchRequest{
        collection: "Article",
        limit: 10,
        near_vector: %NearVector{vector_bytes: <<...>>}
      }
      {:ok, results} = Search.execute(channel, request)
  """
  @spec execute(GRPC.Channel.t(), SearchRequest.t(), keyword()) ::
          {:ok, SearchReply.t()} | {:error, Error.t()}
  def execute(channel, %SearchRequest{} = request, opts \\ []) do
    execute_search(channel, request, opts)
  end

  # Private functions

  defp build_search_request(collection, opts) do
    %SearchRequest{
      collection: collection,
      tenant: Keyword.get(opts, :tenant, ""),
      limit: Keyword.get(opts, :limit, 10),
      offset: Keyword.get(opts, :offset, 0),
      autocut: Keyword.get(opts, :autocut, 0),
      properties: build_properties_request(opts),
      metadata: build_metadata_request(opts),
      uses_127_api: true
    }
  end

  defp build_near_vector(vector, opts) when is_list(vector) do
    # Convert float list to bytes for efficiency
    vector_bytes =
      vector
      |> Enum.map(&<<&1::float-little-32>>)
      |> IO.iodata_to_binary()

    %NearVector{
      vector_bytes: vector_bytes,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  defp build_properties_request(opts) do
    case Keyword.get(opts, :return_properties) do
      nil ->
        nil

      props when is_list(props) ->
        %PropertiesRequest{
          non_ref_properties: props,
          return_all_nonref_properties: false
        }
    end
  end

  defp build_metadata_request(opts) do
    case Keyword.get(opts, :return_metadata) do
      nil ->
        # Return common metadata by default
        %MetadataRequest{
          uuid: true,
          distance: true,
          certainty: true
        }

      fields when is_list(fields) ->
        %MetadataRequest{
          uuid: :uuid in fields,
          vector: :vector in fields,
          creation_time_unix: :creation_time in fields,
          last_update_time_unix: :update_time in fields,
          distance: :distance in fields,
          certainty: :certainty in fields,
          score: :score in fields,
          explain_score: :explain_score in fields,
          is_consistent: :is_consistent in fields
        }
    end
  end

  defp execute_search(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.search(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end
end
