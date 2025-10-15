defmodule WeaviateEx.Query do
  @moduledoc """
  GraphQL query builder for Weaviate.

  Provides a fluent interface for building GraphQL queries.

  ## Examples

      # Simple Get query
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.fields(["title", "content"])
        |> WeaviateEx.Query.limit(10)

      {:ok, results} = WeaviateEx.Query.execute(query)

      # Vector search
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.near_text("artificial intelligence", certainty: 0.7)
        |> WeaviateEx.Query.fields(["title", "content"])
        |> WeaviateEx.Query.limit(5)

      {:ok, results} = WeaviateEx.Query.execute(query)

      # Hybrid search
      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.hybrid("machine learning", alpha: 0.5)
        |> WeaviateEx.Query.fields(["title"])

      {:ok, results} = WeaviateEx.Query.execute(query)
  """

  import WeaviateEx, only: [request: 4]

  defstruct collection: nil,
            fields: [],
            where: nil,
            near_text: nil,
            near_vector: nil,
            near_object: nil,
            hybrid: nil,
            bm25: nil,
            limit: nil,
            offset: nil,
            additional: []

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
  - `:move_to` - Concepts to move towards
  - `:move_away_from` - Concepts to move away from

  ## Examples

      query
      |> WeaviateEx.Query.near_text("artificial intelligence", certainty: 0.7)
  """
  @spec near_text(t(), String.t(), Keyword.t()) :: t()
  def near_text(%__MODULE__{} = query, concepts, opts \\ []) do
    params = %{concepts: [concepts]}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params

    %{query | near_text: params}
  end

  @doc """
  Performs vector similarity search.

  ## Examples

      query
      |> WeaviateEx.Query.near_vector([0.1, 0.2, 0.3, ...], certainty: 0.8)
  """
  @spec near_vector(t(), list(float()), Keyword.t()) :: t()
  def near_vector(%__MODULE__{} = query, vector, opts \\ []) when is_list(vector) do
    params = %{vector: vector}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params

    %{query | near_vector: params}
  end

  @doc """
  Finds objects similar to a specific object.

  ## Examples

      query
      |> WeaviateEx.Query.near_object("550e8400-e29b-41d4-a716-446655440000", certainty: 0.7)
  """
  @spec near_object(t(), String.t(), Keyword.t()) :: t()
  def near_object(%__MODULE__{} = query, id, opts \\ []) do
    params = %{id: id}
    params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
    params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params

    %{query | near_object: params}
  end

  @doc """
  Performs hybrid search combining keyword and vector search.

  ## Options

  - `:alpha` - Balance between keyword (0.0) and vector (1.0) search, default: 0.5
  - `:fusion_type` - Fusion algorithm ("rankedFusion" or "relativeScoreFusion")

  ## Examples

      query
      |> WeaviateEx.Query.hybrid("machine learning", alpha: 0.75)
  """
  @spec hybrid(t(), String.t(), Keyword.t()) :: t()
  def hybrid(%__MODULE__{} = query, search_query, opts \\ []) do
    params = %{query: search_query}
    params = if opts[:alpha], do: Map.put(params, :alpha, opts[:alpha]), else: params

    params =
      if opts[:fusion_type], do: Map.put(params, :fusionType, opts[:fusion_type]), else: params

    %{query | hybrid: params}
  end

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
  def additional(%__MODULE__{} = query, fields) when is_list(fields) do
    %{query | additional: fields}
  end

  @doc """
  Executes the query and returns results.

  ## Examples

      query
      |> WeaviateEx.Query.get("Article")
      |> WeaviateEx.Query.fields(["title"])
      |> WeaviateEx.Query.limit(10)
      |> WeaviateEx.Query.execute()
  """
  @spec execute(t(), Keyword.t()) :: WeaviateEx.api_response()
  def execute(%__MODULE__{} = query, opts \\ []) do
    graphql_query = build_graphql(query)
    request(:post, "/v1/graphql", %{query: graphql_query}, opts)
  end

  # Build GraphQL query string
  defp build_graphql(%__MODULE__{} = query) do
    collection = query.collection
    fields_str = build_fields(query.fields, query.additional)
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

  defp build_fields(fields, additional) do
    field_list = fields ++ build_additional_fields(additional)
    Enum.join(field_list, "\n          ")
  end

  defp build_additional_fields([]), do: []

  defp build_additional_fields(additional) do
    additional_str = Enum.join(additional, " ")
    ["_additional { #{additional_str} }"]
  end

  defp build_args(query) do
    args =
      []
      |> maybe_add_limit(query.limit)
      |> maybe_add_offset(query.offset)
      |> maybe_add_where(query.where)
      |> maybe_add_near_text(query.near_text)
      |> maybe_add_near_vector(query.near_vector)
      |> maybe_add_near_object(query.near_object)
      |> maybe_add_hybrid(query.hybrid)
      |> maybe_add_bm25(query.bm25)

    if args == [], do: "", else: "(#{Enum.join(args, ", ")})"
  end

  defp maybe_add_limit(args, nil), do: args
  defp maybe_add_limit(args, value), do: args ++ ["limit: #{value}"]

  defp maybe_add_offset(args, nil), do: args
  defp maybe_add_offset(args, value), do: args ++ ["offset: #{value}"]

  defp maybe_add_where(args, nil), do: args

  defp maybe_add_where(args, where) do
    args ++ ["where: #{Jason.encode!(where)}"]
  end

  defp maybe_add_near_text(args, nil), do: args

  defp maybe_add_near_text(args, params) do
    args ++ ["nearText: #{Jason.encode!(params)}"]
  end

  defp maybe_add_near_vector(args, nil), do: args

  defp maybe_add_near_vector(args, params) do
    args ++ ["nearVector: #{Jason.encode!(params)}"]
  end

  defp maybe_add_near_object(args, nil), do: args

  defp maybe_add_near_object(args, params) do
    args ++ ["nearObject: #{Jason.encode!(params)}"]
  end

  defp maybe_add_hybrid(args, nil), do: args

  defp maybe_add_hybrid(args, params) do
    args ++ ["hybrid: #{Jason.encode!(params)}"]
  end

  defp maybe_add_bm25(args, nil), do: args

  defp maybe_add_bm25(args, params) do
    args ++ ["bm25: #{Jason.encode!(params)}"]
  end
end
