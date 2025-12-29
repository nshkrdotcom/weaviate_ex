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

      # Cursor pagination with sorting
      alias WeaviateEx.Query.Sort

      query = WeaviateEx.Query.get("Article")
        |> WeaviateEx.Query.fields(["title"])
        |> WeaviateEx.Query.sort(Sort.by_id())
        |> WeaviateEx.Query.limit(100)
        |> WeaviateEx.Query.after_cursor("last-cursor-id")

      {:ok, results} = WeaviateEx.Query.execute(query)
  """

  import WeaviateEx, only: [request: 4]

  alias WeaviateEx.Query.QueryReference
  alias WeaviateEx.Query.Sort

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
            additional: [],
            auto_limit: nil,
            after: nil,
            sort: nil,
            return_references: nil

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

    case request(:post, "/v1/graphql", %{query: graphql_query}, opts) do
      {:ok, response} -> parse_response(response, query.collection)
      error -> error
    end
  end

  # Parse GraphQL response and extract collection results
  defp parse_response(%{"data" => %{"Get" => get_results}}, collection)
       when is_map(get_results) do
    # Get collection results, defaulting to [] if missing or nil
    collection_results = Map.get(get_results, collection, []) || []
    {:ok, collection_results}
  end

  defp parse_response(%{"errors" => errors}, _collection) do
    {:error, %{graphql_errors: errors}}
  end

  defp parse_response(response, _collection) do
    # Fallback - return the raw response
    {:ok, response}
  end

  # Build GraphQL query string
  defp build_graphql(%__MODULE__{} = query) do
    collection = query.collection
    fields_str = build_fields(query.fields, query.additional, query.return_references)
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

  defp build_fields(fields, additional, return_references) do
    field_list =
      fields ++
        build_additional_fields(additional) ++
        build_reference_fields(return_references)

    Enum.join(field_list, "\n          ")
  end

  defp build_reference_fields(nil), do: []

  defp build_reference_fields(refs) when is_list(refs) do
    [QueryReference.list_to_graphql(refs)]
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
      |> maybe_add_auto_limit(query.auto_limit)
      |> maybe_add_after(query.after)
      |> maybe_add_sort(query.sort)
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
    args ++ ["nearText: #{map_to_graphql(params)}"]
  end

  defp maybe_add_near_vector(args, nil), do: args

  defp maybe_add_near_vector(args, params) do
    args ++ ["nearVector: #{map_to_graphql(params)}"]
  end

  defp maybe_add_near_object(args, nil), do: args

  defp maybe_add_near_object(args, params) do
    args ++ ["nearObject: #{map_to_graphql(params)}"]
  end

  defp maybe_add_hybrid(args, nil), do: args

  defp maybe_add_hybrid(args, params) do
    args ++ ["hybrid: #{map_to_graphql(params)}"]
  end

  defp maybe_add_bm25(args, nil), do: args

  defp maybe_add_bm25(args, params) do
    args ++ ["bm25: #{map_to_graphql(params)}"]
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
    # Escape quotes and wrap in quotes for strings
    escaped = String.replace(value, "\"", "\\\"")
    "\"#{escaped}\""
  end

  defp map_to_graphql(value) when is_number(value) or is_boolean(value) or is_nil(value) do
    to_string(value)
  end

  # Version with key context for enum detection
  defp map_to_graphql(value, key) when is_binary(value) and key in ["operator", "fusionType"] do
    # These fields are enums in GraphQL - don't quote them
    value
  end

  defp map_to_graphql(value, _key) when is_binary(value) do
    # Regular strings - quote them
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
