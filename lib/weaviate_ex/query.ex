defmodule WeaviateEx.Query do
  @moduledoc """
  Query builder for Weaviate using gRPC.

  Provides a fluent interface for building search queries that execute
  via gRPC for optimal performance.

  ## Examples

      # Simple Get query
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.fields(["title", "content"])
        |> WeaviateEx.Query.limit(10)

      {:ok, results} = WeaviateEx.Query.execute(query, client)

      # Vector search
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.near_text("artificial intelligence", certainty: 0.7)
        |> WeaviateEx.Query.fields(["title", "content"])
        |> WeaviateEx.Query.limit(5)

      {:ok, results} = WeaviateEx.Query.execute(query, client)

      # Hybrid search
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.hybrid("machine learning", alpha: 0.5)
        |> WeaviateEx.Query.fields(["title"])

      {:ok, results} = WeaviateEx.Query.execute(query, client)

      # Cursor pagination with sorting
      alias WeaviateEx.Query.Sort

      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.fields(["title"])
        |> WeaviateEx.Query.sort(Sort.by_id())
        |> WeaviateEx.Query.limit(100)
        |> WeaviateEx.Query.after_cursor("last-cursor-id")

      {:ok, results} = WeaviateEx.Query.execute(query, client)
  """

  alias WeaviateEx.Client
  alias WeaviateEx.GRPC.Services.Search, as: GRPCSearch
  alias WeaviateEx.Query.Generate
  alias WeaviateEx.Query.GroupBy
  alias WeaviateEx.Query.HybridVector
  alias WeaviateEx.Query.Move
  alias WeaviateEx.Query.NearImage
  alias WeaviateEx.Query.NearMedia
  alias WeaviateEx.Query.QueryReference
  alias WeaviateEx.Query.Rerank
  alias WeaviateEx.Query.Sort

  defstruct collection: nil,
            fields: [],
            where: nil,
            near_text: nil,
            near_vector: nil,
            near_object: nil,
            near_image: nil,
            near_media: nil,
            hybrid: nil,
            bm25: nil,
            limit: nil,
            offset: nil,
            additional: [],
            auto_limit: nil,
            after: nil,
            sort: nil,
            return_references: nil,
            tenant: nil,
            rerank: nil,
            group_by: nil

  @type t :: %__MODULE__{}

  @doc """
  Starts a Get query for a collection.

  ## Examples

      query = WeaviateEx.Query.get("Article")
  """
  @spec get(String.t()) :: t()
  def get(collection) do
    %__MODULE__{collection: collection}
  end

  @doc """
  Specifies which fields to retrieve.

  ## Examples

      query
      |> WeaviateEx.Query.fields(["title", "content", "publishedAt"])
  """
  @spec fields(t(), list(String.t())) :: t()
  def fields(%__MODULE__{} = query, field_list) when is_list(field_list) do
    %{query | fields: field_list}
  end

  @doc """
  Sets the maximum number of results.

  ## Examples

      query |> WeaviateEx.Query.limit(10)
  """
  @spec limit(t(), integer()) :: t()
  def limit(%__MODULE__{} = query, value) when is_integer(value) do
    %{query | limit: value}
  end

  @doc """
  Sets the offset for pagination.

  ## Examples

      query |> WeaviateEx.Query.offset(20)
  """
  @spec offset(t(), integer()) :: t()
  def offset(%__MODULE__{} = query, value) when is_integer(value) do
    %{query | offset: value}
  end

  @doc """
  Adds a where filter clause.

  ## Examples

      query
      |> WeaviateEx.Query.where(%{
        path: ["title"],
        operator: "Equal",
        valueText: "Hello World"
      })
  """
  @spec where(t(), map()) :: t()
  def where(%__MODULE__{} = query, clause) when is_map(clause) do
    %{query | where: clause}
  end

  @doc """
  Performs semantic search using natural language.

  ## Options

  - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
  - `:distance` - Maximum distance threshold
  - `:move_to` - Move struct to shift results towards concepts/objects
  - `:move_away` - Move struct to shift results away from concepts/objects
  - `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      # Simple near_text query
      query
      |> WeaviateEx.Query.near_text("artificial intelligence", certainty: 0.7)

      # With move_to to shift towards concepts
      alias WeaviateEx.Query.Move
      move_to = Move.to(0.5, concepts: ["summer", "beach"])
      query
      |> WeaviateEx.Query.near_text("vacation", move_to: move_to)

      # With move_away to shift away from concepts
      move_away = Move.to(0.3, concepts: ["winter", "cold"])
      query
      |> WeaviateEx.Query.near_text("vacation", move_away: move_away)

      # With both move_to and move_away
      query
      |> WeaviateEx.Query.near_text("vacation",
        certainty: 0.7,
        move_to: Move.to(0.5, concepts: ["summer"]),
        move_away: Move.to(0.25, concepts: ["winter"])
      )

      # With target vectors for multi-vector collections
      query
      |> WeaviateEx.Query.near_text("machine learning", target_vectors: "content_vector")
  """
  @spec near_text(t(), String.t(), Keyword.t()) :: t()
  def near_text(%__MODULE__{} = query, concepts, opts \\ []) do
    params = %{concepts: [concepts]}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params
    params = if opts[:move_to], do: Map.put(params, :move_to, opts[:move_to]), else: params
    params = if opts[:move_away], do: Map.put(params, :move_away, opts[:move_away]), else: params

    params =
      if opts[:target_vectors],
        do: Map.put(params, :target_vectors, opts[:target_vectors]),
        else: params

    %{query | near_text: params}
  end

  @doc """
  Performs vector similarity search.

  ## Options

  - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
  - `:distance` - Maximum distance threshold
  - `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      # Single vector collection
      query
      |> WeaviateEx.Query.near_vector([0.1, 0.2, 0.3, ...], certainty: 0.8)

      # Multi-vector collection with single target
      query
      |> WeaviateEx.Query.near_vector([0.1, 0.2, 0.3],
        target_vectors: "title_vector",
        distance: 0.2
      )

      # Combined target vectors
      target = TargetVectors.combine(["vec1", "vec2"], method: :average)
      query
      |> WeaviateEx.Query.near_vector(vector, target_vectors: target)
  """
  @spec near_vector(t(), list(float()), Keyword.t()) :: t()
  def near_vector(%__MODULE__{} = query, vector, opts \\ []) when is_list(vector) do
    params = %{vector: vector}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params

    params =
      if opts[:target_vectors],
        do: Map.put(params, :target_vectors, opts[:target_vectors]),
        else: params

    %{query | near_vector: params}
  end

  @doc """
  Finds objects similar to a specific object.

  ## Options

  - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
  - `:distance` - Maximum distance threshold
  - `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      query
      |> WeaviateEx.Query.near_object("550e8400-e29b-41d4-a716-446655440000", certainty: 0.7)

      # With target vectors
      query
      |> WeaviateEx.Query.near_object("550e8400-e29b-41d4-a716-446655440000",
        target_vectors: "title_vector"
      )
  """
  @spec near_object(t(), String.t(), Keyword.t()) :: t()
  def near_object(%__MODULE__{} = query, id, opts \\ []) do
    params = %{id: id}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params

    params =
      if opts[:target_vectors],
        do: Map.put(params, :target_vectors, opts[:target_vectors]),
        else: params

    %{query | near_object: params}
  end

  @doc """
  Performs image-based vector search for multimodal collections.

  Supports multi2vec-clip, multi2vec-bind, and other image vectorizers.

  ## Options

    * `:image` - Base64-encoded image data
    * `:image_file` - Path to image file (will be read and base64 encoded)
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold
    * `:target_vectors` - List of named vectors to target

  Either `:image` or `:image_file` must be provided, but not both.

  ## Examples

      # Search by base64 encoded image
      query
      |> WeaviateEx.Query.near_image(image: base64_data, certainty: 0.8)

      # Search by file path
      query
      |> WeaviateEx.Query.near_image(image_file: "/path/to/image.png")

      # With named vectors
      query
      |> WeaviateEx.Query.near_image(image: data, target_vectors: ["image_vector"])
  """
  @spec near_image(t(), keyword()) :: t()
  def near_image(%__MODULE__{} = query, opts) do
    %{query | near_image: NearImage.new(opts)}
  end

  @doc """
  Performs media-based vector search for multimodal collections.

  Supports audio, video, thermal, depth, and IMU data types for
  multi2vec-bind and similar multimodal vectorizers.

  ## Media Types

    * `:audio` - Audio files (wav, mp3, etc.)
    * `:video` - Video files (mp4, avi, etc.)
    * `:thermal` - Thermal imaging data
    * `:depth` - Depth sensor data
    * `:imu` - Inertial measurement unit data

  ## Options

    * `:media` - Base64-encoded media data
    * `:media_file` - Path to media file (will be read and base64 encoded)
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold
    * `:target_vectors` - List of named vectors to target

  Either `:media` or `:media_file` must be provided, but not both.

  ## Examples

      # Search by audio
      query
      |> WeaviateEx.Query.near_media(:audio, media: base64_audio, certainty: 0.7)

      # Search by video file
      query
      |> WeaviateEx.Query.near_media(:video, media_file: "/path/to/video.mp4")

      # With named vectors
      query
      |> WeaviateEx.Query.near_media(:thermal, media: data, target_vectors: ["thermal_vec"])
  """
  @spec near_media(t(), NearMedia.media_type(), keyword()) :: t()
  def near_media(%__MODULE__{} = query, type, opts) do
    %{query | near_media: NearMedia.new(type, opts)}
  end

  @doc """
  Performs hybrid search combining keyword and vector search.

  ## Options

  - `:alpha` - Balance between keyword (0.0) and vector (1.0) search, default: 0.5
  - `:vector` - HybridVector configuration for advanced vector search
  - `:fusion_type` - Fusion algorithm: `:ranked` or `:relative_score`
  - `:properties` - Properties to search for BM25 component
  - `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      # Basic hybrid search
      query
      |> WeaviateEx.Query.hybrid("machine learning", alpha: 0.75)

      # With HybridVector for advanced vector search
      hv = HybridVector.near_text("concepts",
        move_to: Move.to(0.5, concepts: ["AI"])
      )
      query
      |> WeaviateEx.Query.hybrid("search term", vector: hv, alpha: 0.7)

      # With explicit vector
      hv = HybridVector.near_vector(embedding)
      query
      |> WeaviateEx.Query.hybrid("search", vector: hv, fusion_type: :relative_score)
  """
  @spec hybrid(t(), String.t(), Keyword.t()) :: t()
  def hybrid(%__MODULE__{} = query, search_query, opts \\ []) do
    vector = normalize_hybrid_vector(Keyword.get(opts, :vector))

    params =
      %{query: search_query}
      |> put_if_present(:alpha, opts[:alpha])
      |> put_if_present(:fusion_type, opts[:fusion_type])
      |> put_if_present(:fusionType, opts[:fusion_type])
      |> put_if_present(:vector, vector)
      |> put_if_present(:properties, opts[:properties])
      |> put_if_present(:target_vectors, opts[:target_vectors])

    %{query | hybrid: params}
  end

  defp normalize_hybrid_vector(nil), do: nil
  defp normalize_hybrid_vector(%HybridVector{} = hv), do: hv
  defp normalize_hybrid_vector(vec) when is_list(vec), do: HybridVector.near_vector(vec)

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Performs BM25 keyword search.

  ## Examples

      query
      |> WeaviateEx.Query.bm25("machine learning")
  """
  @spec bm25(t(), String.t(), Keyword.t()) :: t()
  def bm25(%__MODULE__{} = query, search_query, opts \\ []) do
    params = %{query: search_query}

    params =
      if opts[:properties], do: Map.put(params, :properties, opts[:properties]), else: params

    %{query | bm25: params}
  end

  @doc """
  Adds additional fields to retrieve (like id, certainty, distance).

  ## Examples

      query
      |> WeaviateEx.Query.additional(["id", "certainty", "distance"])
  """
  @spec additional(t(), list(String.t())) :: t()
  def additional(%__MODULE__{} = query, add_fields) when is_list(add_fields) do
    %{query | additional: add_fields}
  end

  @doc """
  Sets the auto-limit for automatically cutting off results at natural score boundaries.

  Auto-limit is useful with vector searches where you want to stop returning results
  when there's a natural gap in similarity scores. The value represents the number
  of "jumps" or score discontinuities to allow before cutting off.

  ## Examples

      # Cut off after 3 natural score boundaries
      query
      |> WeaviateEx.Query.auto_limit(3)

      # Combined with near_text for semantic search with auto-cutoff
      query
      |> WeaviateEx.Query.near_text("machine learning")
      |> WeaviateEx.Query.auto_limit(2)
  """
  @spec auto_limit(t(), pos_integer()) :: t()
  def auto_limit(%__MODULE__{} = query, value) when is_integer(value) and value > 0 do
    %{query | auto_limit: value}
  end

  @doc """
  Sets the cursor for cursor-based pagination.

  Cursor pagination is more memory-efficient than offset-based pagination for large
  result sets. Use the cursor value from the last object's `_additional.id` to
  fetch the next page.

  Note: Cursor pagination requires consistent sorting. Use with `sort/2` for
  deterministic results, typically sorting by ID.

  ## Examples

      # First page
      query
      |> WeaviateEx.Query.limit(100)
      |> WeaviateEx.Query.sort(Sort.by_id())

      # Subsequent pages using the last ID as cursor
      query
      |> WeaviateEx.Query.limit(100)
      |> WeaviateEx.Query.sort(Sort.by_id())
      |> WeaviateEx.Query.after_cursor("last-object-id")
  """
  @spec after_cursor(t(), String.t()) :: t()
  def after_cursor(%__MODULE__{} = query, cursor) when is_binary(cursor) do
    %{query | after: cursor}
  end

  @doc """
  Sets the sort criteria for the query.

  Accepts sort criteria built using the `WeaviateEx.Query.Sort` module.
  Sort can be used for ordering results and is required for deterministic
  cursor-based pagination.

  ## Examples

      # Sort by a single property
      query
      |> WeaviateEx.Query.sort(Sort.by_property("title", :asc))

      # Sort by ID (useful for cursor pagination)
      query
      |> WeaviateEx.Query.sort(Sort.by_id())

      # Sort by creation time descending (newest first)
      query
      |> WeaviateEx.Query.sort(Sort.by_creation_time(:desc))

      # Sort by update time
      query
      |> WeaviateEx.Query.sort(Sort.by_update_time(:desc))

      # Multiple sort criteria
      query
      |> WeaviateEx.Query.sort(
        Sort.by_property("category")
        |> Sort.then_by_property("title", :desc)
      )
  """
  @spec sort(t(), Sort.t()) :: t()
  def sort(%__MODULE__{} = query, sort_criteria) when is_list(sort_criteria) do
    %{query | sort: sort_criteria}
  end

  @doc """
  Sets the cross-references to fetch with the query results.

  Allows fetching related objects through cross-reference properties.
  Use `WeaviateEx.Query.QueryReference` to build reference configurations
  with property selection and nested reference support.

  ## Examples

      # Simple reference
      ref = QueryReference.new("hasAuthor", return_properties: ["name"])
      query
      |> WeaviateEx.Query.return_references([ref])

      # Reference with nested references
      nested = QueryReference.new("hasPublisher", return_properties: ["name"])
      ref = QueryReference.new("hasAuthor",
        return_properties: ["name", "bio"],
        return_references: [nested]
      )
      query
      |> WeaviateEx.Query.return_references([ref])

      # Multiple references
      author_ref = QueryReference.new("hasAuthor", return_properties: ["name"])
      category_ref = QueryReference.new("hasCategory", return_properties: ["name"])
      query
      |> WeaviateEx.Query.return_references([author_ref, category_ref])
  """
  @spec return_references(t(), [QueryReference.t()]) :: t()
  def return_references(%__MODULE__{} = query, refs) when is_list(refs) do
    %{query | return_references: refs}
  end

  @doc """
  Sets the tenant for multi-tenant collections.

  ## Examples

      query
      |> WeaviateEx.Query.tenant("TenantA")
  """
  @spec tenant(t(), String.t()) :: t()
  def tenant(%__MODULE__{} = query, tenant_name) when is_binary(tenant_name) do
    %{query | tenant: tenant_name}
  end

  @doc """
  Adds reranking to the query results.

  Reranking uses a reranker model configured on the collection to re-order
  search results based on relevance to the query. The reranker scores are
  available in the `_additional { rerank { score } }` field.

  ## Parameters

  - `query` - The query struct
  - `rerank` - A `WeaviateEx.Query.Rerank` struct

  ## Examples

      alias WeaviateEx.Query.Rerank

      # Basic rerank
      rerank = Rerank.new("content")
      query
      |> WeaviateEx.Query.rerank(rerank)

      # Rerank with custom query
      rerank = Rerank.new("content", query: "What is machine learning?")
      query
      |> WeaviateEx.Query.near_text("AI")
      |> WeaviateEx.Query.rerank(rerank)
  """
  @spec rerank(t(), Rerank.t()) :: t()
  def rerank(%__MODULE__{} = query, %Rerank{} = rerank_config) do
    %{query | rerank: rerank_config}
  end

  @doc """
  Groups query results by a property.

  GroupBy clusters results based on a property path, returning groups
  with their objects. This is useful for organizing search results by
  category, type, or other grouping criteria.

  ## Parameters

  - `query` - The query struct
  - `group_by` - A `WeaviateEx.Query.GroupBy` struct

  ## Examples

      alias WeaviateEx.Query.GroupBy

      # Group by category
      group_by = GroupBy.new("category")
      query
      |> WeaviateEx.Query.group_by(group_by)

      # Group with custom limits
      group_by = GroupBy.new("category", objects_per_group: 5, number_of_groups: 20)
      query
      |> WeaviateEx.Query.near_text("technology")
      |> WeaviateEx.Query.group_by(group_by)

      # Group by nested property
      group_by = GroupBy.new(["metadata", "type"])
      query
      |> WeaviateEx.Query.group_by(group_by)
  """
  @spec group_by(t(), GroupBy.t()) :: t()
  def group_by(%__MODULE__{} = query, %GroupBy{} = group_by_config) do
    %{query | group_by: group_by_config}
  end

  @doc """
  Adds generative AI capabilities to a query.

  Combines the existing query with generative configuration to produce
  AI-generated content alongside search results.

  ## Parameters

  - `query` - The existing query struct
  - `type` - Generation type (`:single` for per-object, `:grouped` for all results)
  - `prompt` - The prompt to use for generation
  - `opts` - Additional options

  ## Options

  - `:properties` - Properties to include in grouped context (for `:grouped` type)

  ## Examples

      # Add per-object generation to existing query
      query
      |> Query.near_text("machine learning")
      |> Query.generate(:single, "Summarize: {title}")
      |> Query.execute(client)

      # Add grouped generation with specific properties
      query
      |> Query.bm25("elixir")
      |> Query.generate(:grouped, "Write an overview", properties: ["title", "content"])
      |> Query.execute(client)

  ## Returns

  A `Generate` struct that can be executed to get `GenerativeResult`.
  """
  @spec generate(t(), :single | :grouped, String.t(), keyword()) :: Generate.t()
  def generate(query, type, prompt, opts \\ [])

  def generate(%__MODULE__{} = query, :single, prompt, _opts) do
    builder = convert_query_to_generate(query)
    Generate.single_prompt(builder, prompt)
  end

  def generate(%__MODULE__{} = query, :grouped, prompt, opts) do
    builder = convert_query_to_generate(query)
    Generate.grouped_task(builder, prompt, opts)
  end

  # Convert a Query struct to a Generate builder, preserving search configuration
  defp convert_query_to_generate(%__MODULE__{} = query) do
    query.collection
    |> Generate.new()
    |> apply_search_type(query)
    |> apply_query_settings(query)
  end

  defp apply_search_type(builder, %{near_text: params}) when not is_nil(params) do
    concepts = params[:concepts] || []
    text = if is_list(concepts), do: hd(concepts), else: concepts
    opts = extract_search_opts(params, [:certainty, :distance])
    Generate.near_text(builder, text, opts)
  end

  defp apply_search_type(builder, %{near_vector: params}) when not is_nil(params) do
    opts = extract_search_opts(params, [:certainty, :distance])
    Generate.near_vector(builder, params[:vector], opts)
  end

  defp apply_search_type(builder, %{near_object: params}) when not is_nil(params) do
    opts = extract_search_opts(params, [:certainty, :distance])
    Generate.near_object(builder, params[:id], opts)
  end

  defp apply_search_type(builder, %{bm25: params}) when not is_nil(params) do
    opts = extract_search_opts(params, [:properties])
    Generate.bm25(builder, params[:query], opts)
  end

  defp apply_search_type(builder, %{hybrid: params}) when not is_nil(params) do
    opts = extract_search_opts(params, [:alpha, :fusion_type])
    Generate.hybrid(builder, params[:query], opts)
  end

  defp apply_search_type(builder, _query), do: builder

  defp apply_query_settings(builder, query) do
    builder
    |> maybe_set_properties(query.fields)
    |> maybe_set_where(query.where)
    |> maybe_set_limit(query.limit)
    |> maybe_set_offset(query.offset)
    |> maybe_set_tenant(query.tenant)
  end

  defp maybe_set_properties(builder, []), do: builder
  defp maybe_set_properties(builder, fields), do: Generate.return_properties(builder, fields)

  defp maybe_set_where(builder, nil), do: builder
  defp maybe_set_where(builder, where), do: Generate.where(builder, where)

  defp maybe_set_limit(builder, nil), do: builder
  defp maybe_set_limit(builder, limit), do: Generate.limit(builder, limit)

  defp maybe_set_offset(builder, nil), do: builder
  defp maybe_set_offset(builder, offset), do: Generate.offset(builder, offset)

  defp maybe_set_tenant(builder, nil), do: builder
  defp maybe_set_tenant(builder, tenant), do: Generate.tenant(builder, tenant)

  defp extract_search_opts(params, keys) when is_map(params) do
    keys
    |> Enum.map(fn key -> {key, Map.get(params, key)} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  @doc """
  Executes the query and returns results.

  When called with a WeaviateEx.Client, uses gRPC for optimal performance.
  When called without a client (legacy mode), uses HTTP/GraphQL.

  ## Examples

      # With client (uses gRPC)
      {:ok, client} = WeaviateEx.Client.connect(base_url: "http://localhost:8080")
      {:ok, results} = Query.execute(query, client)

      # Legacy mode (uses HTTP/GraphQL)
      {:ok, results} = Query.execute(query)
  """
  @spec execute(t()) :: WeaviateEx.api_response()
  @spec execute(t(), Keyword.t()) :: WeaviateEx.api_response()
  @spec execute(t(), Client.t()) :: WeaviateEx.api_response()
  @spec execute(t(), Client.t(), Keyword.t()) :: WeaviateEx.api_response()

  # Legacy HTTP mode - no client
  def execute(%__MODULE__{} = query) do
    execute_http(query, [])
  end

  # Legacy HTTP mode - with opts but no client
  def execute(%__MODULE__{} = query, opts) when is_list(opts) do
    execute_http(query, opts)
  end

  # gRPC mode - with client
  def execute(%__MODULE__{} = query, %Client{} = client) do
    execute_with_client(query, client, [])
  end

  # gRPC mode - with client and opts
  def execute(%__MODULE__{} = query, %Client{} = client, opts) when is_list(opts) do
    execute_with_client(query, client, opts)
  end

  defp execute_with_client(query, client, opts) do
    channel = Client.grpc_channel(client)

    if is_nil(channel) do
      # Fall back to HTTP if no gRPC channel
      execute_http(query, opts)
    else
      execute_grpc(query, channel, client, opts)
    end
  end

  # Legacy HTTP/GraphQL execution
  defp execute_http(%__MODULE__{} = query, opts) do
    import WeaviateEx, only: [request: 4]

    graphql_query = build_graphql(query)

    case request(:post, "/v1/graphql", %{query: graphql_query}, opts) do
      {:ok, response} -> parse_http_response(response, query.collection)
      error -> error
    end
  end

  # Parse GraphQL response and extract collection results
  defp parse_http_response(%{"data" => %{"Get" => get_results}}, collection)
       when is_map(get_results) do
    collection_results = Map.get(get_results, collection, []) || []
    {:ok, collection_results}
  end

  defp parse_http_response(%{"errors" => errors}, _collection) do
    {:error, %{graphql_errors: errors}}
  end

  defp parse_http_response(response, _collection) do
    {:ok, response}
  end

  # Execute via gRPC based on search type
  defp execute_grpc(%__MODULE__{} = query, channel, client, opts) do
    grpc_opts = build_grpc_opts(query, client, opts)
    result = dispatch_grpc_search(query, channel, grpc_opts)

    case result do
      {:ok, reply} -> {:ok, parse_grpc_reply(reply, query.fields, query.additional)}
      error -> error
    end
  end

  # Dispatch to the appropriate gRPC search method based on query type
  defp dispatch_grpc_search(%{near_vector: %{vector: vector}} = query, channel, opts)
       when not is_nil(vector) do
    GRPCSearch.near_vector(channel, query.collection, vector, opts)
  end

  defp dispatch_grpc_search(%{near_text: %{concepts: concepts}} = query, channel, opts)
       when not is_nil(concepts) do
    text = if is_list(concepts), do: hd(concepts), else: concepts
    GRPCSearch.near_text(channel, query.collection, text, opts)
  end

  defp dispatch_grpc_search(%{near_object: %{id: id}} = query, channel, opts)
       when not is_nil(id) do
    GRPCSearch.near_object(channel, query.collection, id, opts)
  end

  defp dispatch_grpc_search(%{hybrid: %{query: hybrid_query}} = query, channel, opts)
       when not is_nil(hybrid_query) do
    GRPCSearch.hybrid(channel, query.collection, hybrid_query, opts)
  end

  defp dispatch_grpc_search(%{bm25: %{query: bm25_query}} = query, channel, opts)
       when not is_nil(bm25_query) do
    GRPCSearch.bm25(channel, query.collection, bm25_query, opts)
  end

  defp dispatch_grpc_search(query, channel, opts) do
    # Default: basic search (uses gRPC Search with no vector search type)
    execute_basic_search(channel, query, opts)
  end

  # Basic search without vector search - uses near_vector with empty vector
  # or falls back to HTTP for simple queries
  defp execute_basic_search(channel, query, opts) do
    # For basic searches without any search operator, we need to use a different approach
    # The gRPC API requires at least one search type, so we use bm25 with empty query
    # which effectively returns all objects matching any filters
    GRPCSearch.bm25(channel, query.collection, "", opts)
  end

  defp build_grpc_opts(%__MODULE__{} = query, client, opts) do
    [
      limit: query.limit || 10,
      offset: query.offset || 0,
      autocut: query.auto_limit || 0,
      return_properties: query.fields,
      return_metadata: build_metadata_list(query.additional),
      api_key: client.config.api_key
    ]
    |> maybe_add_grpc_opt(:tenant, query.tenant)
    |> add_search_opts(query)
    |> Keyword.merge(Keyword.take(opts, [:timeout]))
  end

  # Add search-specific options based on query type
  defp add_search_opts(opts, %{near_text: params}) when is_map(params) do
    opts
    |> maybe_add_grpc_opt(:certainty, params[:certainty])
    |> maybe_add_grpc_opt(:distance, params[:distance])
  end

  defp add_search_opts(opts, %{near_vector: params}) when is_map(params) do
    opts
    |> maybe_add_grpc_opt(:certainty, params[:certainty])
    |> maybe_add_grpc_opt(:distance, params[:distance])
  end

  defp add_search_opts(opts, %{near_object: params}) when is_map(params) do
    opts
    |> maybe_add_grpc_opt(:certainty, params[:certainty])
    |> maybe_add_grpc_opt(:distance, params[:distance])
  end

  defp add_search_opts(opts, %{hybrid: params}) when is_map(params) do
    maybe_add_grpc_opt(opts, :alpha, params[:alpha])
  end

  defp add_search_opts(opts, %{bm25: params}) when is_map(params) do
    maybe_add_grpc_opt(opts, :properties, params[:properties])
  end

  defp add_search_opts(opts, _query), do: opts

  # Helper to conditionally add an option
  defp maybe_add_grpc_opt(opts, _key, nil), do: opts
  defp maybe_add_grpc_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp build_metadata_list(additional) when is_list(additional) do
    Enum.map(additional, fn
      "id" -> :uuid
      "uuid" -> :uuid
      "distance" -> :distance
      "certainty" -> :certainty
      "vector" -> :vector
      "creationTimeUnix" -> :creation_time
      "lastUpdateTimeUnix" -> :update_time
      "score" -> :score
      "explainScore" -> :explain_score
      other when is_atom(other) -> other
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_metadata_list(_), do: [:uuid, :distance, :certainty]

  # Parse gRPC SearchReply to match expected format
  defp parse_grpc_reply(%Weaviate.V1.SearchReply{results: results}, fields, additional) do
    Enum.map(results, fn result ->
      object = parse_result_object(result, fields)

      # Add _additional fields if requested
      if additional && length(additional) > 0 do
        additional_data = parse_additional_metadata(result.metadata)
        Map.put(object, "_additional", additional_data)
      else
        object
      end
    end)
  end

  defp parse_result_object(result, _fields) do
    # Extract properties from the result
    case result.properties do
      %Weaviate.V1.PropertiesResult{non_ref_props: props} when not is_nil(props) ->
        parse_properties_to_map(props)

      _ ->
        %{}
    end
  end

  # Parse Weaviate.V1.Properties (with fields map) to Elixir map
  defp parse_properties_to_map(%Weaviate.V1.Properties{fields: fields}) when is_map(fields) do
    fields
    |> Enum.map(fn {key, value} -> {key, parse_weaviate_value(value)} end)
    |> Map.new()
  end

  defp parse_properties_to_map(_), do: %{}

  # Parse Weaviate.V1.Value (oneof kind)
  # Uses pattern matching in function heads to reduce cyclomatic complexity
  defp parse_weaviate_value(%Weaviate.V1.Value{kind: kind}), do: parse_value_kind(kind)
  defp parse_weaviate_value(_), do: nil

  # Simple scalar values - return as-is
  defp parse_value_kind({:text_value, v}), do: v
  defp parse_value_kind({:number_value, v}), do: v
  defp parse_value_kind({:int_value, v}), do: v
  defp parse_value_kind({:bool_value, v}), do: v
  defp parse_value_kind({:date_value, v}), do: v
  defp parse_value_kind({:uuid_value, v}), do: v
  defp parse_value_kind({:blob_value, v}), do: v

  # Complex values - delegate to specialized parsers
  defp parse_value_kind({:geo_value, v}), do: parse_geo_value(v)
  defp parse_value_kind({:phone_value, v}), do: parse_phone_value(v)
  defp parse_value_kind({:object_value, v}), do: parse_properties_to_map(v)
  defp parse_value_kind({:list_value, v}), do: parse_list_value(v)

  # Null and unknown values
  defp parse_value_kind({:null_value, _}), do: nil
  defp parse_value_kind(nil), do: nil
  defp parse_value_kind(_), do: nil

  defp parse_geo_value(%Weaviate.V1.GeoCoordinate{} = geo) do
    %{"latitude" => geo.latitude, "longitude" => geo.longitude}
  end

  defp parse_phone_value(%Weaviate.V1.PhoneNumber{} = phone) do
    %{
      "input" => phone.input,
      "valid" => phone.valid,
      "internationalFormatted" => phone.international_formatted
    }
  end

  # Parse list values using pattern matching in function heads
  defp parse_list_value(%Weaviate.V1.ListValue{kind: kind}), do: parse_list_kind(kind)

  # Simple list values - return as-is
  defp parse_list_kind({:text_values, %{values: values}}), do: values
  defp parse_list_kind({:bool_values, %{values: values}}), do: values
  defp parse_list_kind({:date_values, %{values: values}}), do: values
  defp parse_list_kind({:uuid_values, %{values: values}}), do: values

  # Binary-encoded numeric lists - need parsing
  defp parse_list_kind({:number_values, %{values: bytes}}), do: parse_number_bytes(bytes)
  defp parse_list_kind({:int_values, %{values: bytes}}), do: parse_int_bytes(bytes)

  # Object lists - recursive parsing
  defp parse_list_kind({:object_values, %{values: values}}),
    do: Enum.map(values, &parse_properties_to_map/1)

  # Empty or unknown list kinds
  defp parse_list_kind(nil), do: []
  defp parse_list_kind(_), do: []

  defp parse_number_bytes(bytes) when is_binary(bytes) do
    # Numbers are stored as little-endian doubles
    for <<value::float-little-64 <- bytes>>, do: value
  end

  defp parse_number_bytes(_), do: []

  defp parse_int_bytes(bytes) when is_binary(bytes) do
    # Ints are stored as little-endian int64s
    for <<value::signed-little-64 <- bytes>>, do: value
  end

  defp parse_int_bytes(_), do: []

  defp parse_additional_metadata(nil), do: %{}

  defp parse_additional_metadata(metadata) do
    result = %{}

    result =
      if metadata.id && metadata.id != "", do: Map.put(result, "id", metadata.id), else: result

    result =
      if metadata.distance_present,
        do: Map.put(result, "distance", metadata.distance),
        else: result

    result =
      if metadata.certainty_present,
        do: Map.put(result, "certainty", metadata.certainty),
        else: result

    result = if metadata.score_present, do: Map.put(result, "score", metadata.score), else: result

    result =
      if metadata.creation_time_unix_present do
        Map.put(result, "creationTimeUnix", metadata.creation_time_unix)
      else
        result
      end

    result =
      if metadata.last_update_time_unix_present do
        Map.put(result, "lastUpdateTimeUnix", metadata.last_update_time_unix)
      else
        result
      end

    result
  end

  # ============================================================================
  # GraphQL Building Helpers (for legacy HTTP mode)
  # ============================================================================

  defp build_graphql(%__MODULE__{} = query) do
    collection = query.collection

    fields_str =
      build_fields(query.fields, query.additional, query.return_references, query.rerank)

    args = build_args(query)

    """
    {
      Get {
        #{collection}#{args} {
          #{fields_str}
        }
      }
    }
    """
  end

  defp build_fields(fields, additional, return_references, rerank) do
    field_list =
      fields ++
        build_additional_fields(additional, rerank) ++
        build_reference_fields(return_references)

    Enum.join(field_list, "\n          ")
  end

  defp build_reference_fields(nil), do: []

  defp build_reference_fields(refs) when is_list(refs) do
    [QueryReference.list_to_graphql(refs)]
  end

  defp build_additional_fields([], nil), do: []

  defp build_additional_fields(additional, rerank) do
    # Build base additional fields
    base_fields = additional || []
    additional_str = Enum.join(base_fields, " ")

    # Add rerank if configured
    rerank_str = build_rerank_additional(rerank)

    content =
      [additional_str, rerank_str]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")

    if content == "" do
      []
    else
      ["_additional { #{content} }"]
    end
  end

  defp build_rerank_additional(nil), do: ""

  defp build_rerank_additional(%Rerank{} = rerank) do
    "rerank#{Rerank.to_graphql(rerank)} { score }"
  end

  defp build_args(query) do
    args =
      []
      |> maybe_add_limit(query.limit)
      |> maybe_add_offset(query.offset)
      |> maybe_add_auto_limit(query.auto_limit)
      |> maybe_add_after(query.after)
      |> maybe_add_sort(query.sort)
      |> maybe_add_where(query.where)
      |> maybe_add_near_text(query.near_text)
      |> maybe_add_near_vector(query.near_vector)
      |> maybe_add_near_object(query.near_object)
      |> maybe_add_near_image(query.near_image)
      |> maybe_add_near_media(query.near_media)
      |> maybe_add_hybrid(query.hybrid)
      |> maybe_add_bm25(query.bm25)
      |> maybe_add_group_by(query.group_by)

    if args == [], do: "", else: "(#{Enum.join(args, ", ")})"
  end

  defp maybe_add_limit(args, nil), do: args
  defp maybe_add_limit(args, value), do: args ++ ["limit: #{value}"]

  defp maybe_add_offset(args, nil), do: args
  defp maybe_add_offset(args, value), do: args ++ ["offset: #{value}"]

  defp maybe_add_auto_limit(args, nil), do: args
  defp maybe_add_auto_limit(args, value), do: args ++ ["autoLimit: #{value}"]

  defp maybe_add_after(args, nil), do: args
  defp maybe_add_after(args, cursor), do: args ++ ["after: \"#{cursor}\""]

  defp maybe_add_sort(args, nil), do: args

  defp maybe_add_sort(args, sort_criteria) do
    args ++ ["sort: #{Sort.to_graphql(sort_criteria)}"]
  end

  defp maybe_add_where(args, nil), do: args

  defp maybe_add_where(args, where_clause) do
    args ++ ["where: #{map_to_graphql(where_clause)}"]
  end

  defp maybe_add_near_text(args, nil), do: args

  defp maybe_add_near_text(args, params) do
    # Build nearText parameters, handling Move structs specially
    near_text_parts = []

    # Add concepts
    concepts = params[:concepts] || []
    concepts_str = Enum.map_join(concepts, ", ", &~s("#{&1}"))
    near_text_parts = near_text_parts ++ ["concepts: [#{concepts_str}]"]

    # Add certainty if present
    near_text_parts =
      if params[:certainty] do
        near_text_parts ++ ["certainty: #{params[:certainty]}"]
      else
        near_text_parts
      end

    # Add distance if present
    near_text_parts =
      if params[:distance] do
        near_text_parts ++ ["distance: #{params[:distance]}"]
      else
        near_text_parts
      end

    # Add moveTo if present (Move struct)
    near_text_parts =
      if params[:move_to] do
        near_text_parts ++ ["moveTo: #{Move.to_graphql(params[:move_to])}"]
      else
        near_text_parts
      end

    # Add moveAwayFrom if present (Move struct)
    near_text_parts =
      if params[:move_away] do
        near_text_parts ++ ["moveAwayFrom: #{Move.to_graphql(params[:move_away])}"]
      else
        near_text_parts
      end

    args ++ ["nearText: {#{Enum.join(near_text_parts, ", ")}}"]
  end

  defp maybe_add_near_vector(args, nil), do: args

  defp maybe_add_near_vector(args, params) do
    args ++ ["nearVector: #{map_to_graphql(params)}"]
  end

  defp maybe_add_near_object(args, nil), do: args

  defp maybe_add_near_object(args, params) do
    args ++ ["nearObject: #{map_to_graphql(params)}"]
  end

  defp maybe_add_near_image(args, nil), do: args

  defp maybe_add_near_image(args, %NearImage{} = near_image) do
    args ++ ["nearImage: #{map_to_graphql(NearImage.to_graphql(near_image))}"]
  end

  defp maybe_add_near_media(args, nil), do: args

  defp maybe_add_near_media(args, %NearMedia{} = near_media) do
    args ++ ["nearMedia: #{map_to_graphql(NearMedia.to_graphql(near_media))}"]
  end

  defp maybe_add_hybrid(args, nil), do: args

  defp maybe_add_hybrid(args, params) do
    args ++ ["hybrid: #{map_to_graphql(params)}"]
  end

  defp maybe_add_bm25(args, nil), do: args

  defp maybe_add_bm25(args, params) do
    args ++ ["bm25: #{map_to_graphql(params)}"]
  end

  defp maybe_add_group_by(args, nil), do: args

  defp maybe_add_group_by(args, %GroupBy{} = group_by) do
    args ++ ["groupBy: #{GroupBy.to_graphql(group_by)}"]
  end

  # Convert Elixir map/list to GraphQL object syntax (without quotes on keys)
  defp map_to_graphql(value) when is_map(value) do
    entries =
      value
      |> Enum.map_join(", ", fn {k, v} ->
        key_str = to_string(k)
        "#{key_str}: #{map_to_graphql(v, key_str)}"
      end)

    "{#{entries}}"
  end

  defp map_to_graphql(value) when is_list(value) do
    items =
      value
      |> Enum.map_join(", ", &map_to_graphql(&1, nil))

    "[#{items}]"
  end

  defp map_to_graphql(value) when is_binary(value) do
    escaped = String.replace(value, "\"", "\\\"")
    "\"#{escaped}\""
  end

  defp map_to_graphql(value) when is_number(value) or is_boolean(value) or is_nil(value) do
    to_string(value)
  end

  # Version with key context for enum detection
  defp map_to_graphql(value, key) when is_binary(value) and key in ["operator", "fusionType"] do
    value
  end

  defp map_to_graphql(value, _key) when is_binary(value) do
    escaped = String.replace(value, "\"", "\\\"")
    "\"#{escaped}\""
  end

  defp map_to_graphql(value, _key) when is_map(value) do
    entries =
      value
      |> Enum.map_join(", ", fn {k, v} ->
        key_str = to_string(k)
        "#{key_str}: #{map_to_graphql(v, key_str)}"
      end)

    "{#{entries}}"
  end

  defp map_to_graphql(value, _key) when is_list(value) do
    items =
      value
      |> Enum.map_join(", ", &map_to_graphql(&1, nil))

    "[#{items}]"
  end

  defp map_to_graphql(value, _key) when is_number(value) or is_boolean(value) or is_nil(value) do
    to_string(value)
  end
end
