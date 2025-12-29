defmodule WeaviateEx.Query.Generate do
  @moduledoc """
  Generative search query builder.

  Combines vector/keyword search with generative AI to produce both
  search results and AI-generated content in a single query.

  ## Features

  - All search types: near_text, near_vector, near_object, bm25, hybrid
  - Single prompt: Generate content for each object individually
  - Grouped task: Generate content from all results together
  - Full filter, limit, offset support

  ## Examples

      # Vector search with per-object generation
      Generate.new("Article")
      |> Generate.near_text("machine learning")
      |> Generate.single_prompt("Summarize this article: {title}")
      |> Generate.limit(5)
      |> Generate.execute(client)

      # BM25 search with grouped generation
      Generate.new("Article")
      |> Generate.bm25("elixir")
      |> Generate.grouped_task("Write a summary of these articles", properties: ["title", "content"])
      |> Generate.execute(client)

      # Hybrid search with both single and grouped prompts
      Generate.new("Article")
      |> Generate.hybrid("AI research", alpha: 0.7)
      |> Generate.single_prompt("Key point: {title}")
      |> Generate.grouped_task("Overall theme")
      |> Generate.return_properties(["title", "content"])
      |> Generate.execute(client)
  """

  alias WeaviateEx.Query.GenerativeResult

  defstruct [
    :collection,
    :search_type,
    :search_query,
    :search_opts,
    :single_prompt,
    :grouped_task,
    :grouped_properties,
    :return_properties,
    :where,
    :limit,
    :offset,
    :tenant,
    :additional
  ]

  @type search_type :: :near_text | :near_vector | :near_object | :bm25 | :hybrid

  @type t :: %__MODULE__{
          collection: String.t(),
          search_type: search_type() | nil,
          search_query: term(),
          search_opts: keyword(),
          single_prompt: String.t() | nil,
          grouped_task: String.t() | nil,
          grouped_properties: [String.t()] | nil,
          return_properties: [String.t()] | nil,
          where: map() | nil,
          limit: pos_integer() | nil,
          offset: non_neg_integer() | nil,
          tenant: String.t() | nil,
          additional: [String.t()] | nil
        }

  # ============================================================================
  # Builder Functions
  # ============================================================================

  @doc """
  Creates a new generative query builder for a collection.

  ## Examples

      builder = Generate.new("Article")
  """
  @spec new(String.t()) :: t()
  def new(collection) when is_binary(collection) do
    %__MODULE__{
      collection: collection,
      search_opts: [],
      additional: ["id"]
    }
  end

  @doc """
  Adds near_text search to the query.

  ## Options

    - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    - `:distance` - Maximum distance threshold
    - `:move_to` - Concepts to move towards
    - `:move_away` - Concepts to move away from

  ## Examples

      Generate.near_text(builder, "machine learning", certainty: 0.8)
  """
  @spec near_text(t(), String.t() | [String.t()], keyword()) :: t()
  def near_text(%__MODULE__{} = builder, query, opts \\ []) do
    %{builder | search_type: :near_text, search_query: query, search_opts: opts}
  end

  @doc """
  Adds near_vector search to the query.

  ## Options

    - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    - `:distance` - Maximum distance threshold
    - `:target_vectors` - Target named vectors

  ## Examples

      Generate.near_vector(builder, [0.1, 0.2, 0.3], certainty: 0.9)
  """
  @spec near_vector(t(), [float()], keyword()) :: t()
  def near_vector(%__MODULE__{} = builder, vector, opts \\ []) when is_list(vector) do
    %{builder | search_type: :near_vector, search_query: vector, search_opts: opts}
  end

  @doc """
  Adds near_object search to the query.

  ## Options

    - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    - `:distance` - Maximum distance threshold

  ## Examples

      Generate.near_object(builder, "uuid-123", certainty: 0.85)
  """
  @spec near_object(t(), String.t(), keyword()) :: t()
  def near_object(%__MODULE__{} = builder, object_id, opts \\ []) when is_binary(object_id) do
    %{builder | search_type: :near_object, search_query: object_id, search_opts: opts}
  end

  @doc """
  Adds BM25 keyword search to the query.

  ## Options

    - `:properties` - Properties to search in
    - `:operator` - BM25 operator (:and or :or)

  ## Examples

      Generate.bm25(builder, "elixir programming", properties: ["title", "content"])
  """
  @spec bm25(t(), String.t(), keyword()) :: t()
  def bm25(%__MODULE__{} = builder, query, opts \\ []) when is_binary(query) do
    %{builder | search_type: :bm25, search_query: query, search_opts: opts}
  end

  @doc """
  Adds hybrid search to the query.

  ## Options

    - `:alpha` - Weight between vector (1.0) and keyword (0.0) search
    - `:fusion_type` - Fusion algorithm (:ranked or :relative_score)
    - `:properties` - Properties to search for BM25 component

  ## Examples

      Generate.hybrid(builder, "machine learning", alpha: 0.7)
  """
  @spec hybrid(t(), String.t(), keyword()) :: t()
  def hybrid(%__MODULE__{} = builder, query, opts \\ []) when is_binary(query) do
    %{builder | search_type: :hybrid, search_query: query, search_opts: opts}
  end

  @doc """
  Sets the single prompt for per-object generation.

  The prompt can include property placeholders like `{title}` that will
  be replaced with actual property values for each object.

  ## Examples

      Generate.single_prompt(builder, "Summarize: {title}")
      Generate.single_prompt(builder, "Write about {title} and its {category}")
  """
  @spec single_prompt(t(), String.t()) :: t()
  def single_prompt(%__MODULE__{} = builder, prompt) when is_binary(prompt) do
    %{builder | single_prompt: prompt}
  end

  @doc """
  Sets the grouped task for generation across all results.

  ## Options

    - `:properties` - Properties to include in the context for generation

  ## Examples

      Generate.grouped_task(builder, "Summarize all articles")
      Generate.grouped_task(builder, "Write a report", properties: ["title", "content"])
  """
  @spec grouped_task(t(), String.t(), keyword()) :: t()
  def grouped_task(%__MODULE__{} = builder, task, opts \\ []) when is_binary(task) do
    properties = Keyword.get(opts, :properties)
    %{builder | grouped_task: task, grouped_properties: properties}
  end

  @doc """
  Sets the properties to return from the search.

  ## Examples

      Generate.return_properties(builder, ["title", "content", "author"])
  """
  @spec return_properties(t(), [String.t()]) :: t()
  def return_properties(%__MODULE__{} = builder, properties) when is_list(properties) do
    %{builder | return_properties: properties}
  end

  @doc """
  Sets a filter condition for the query.

  ## Examples

      Generate.where(builder, %{path: ["status"], operator: "Equal", valueText: "published"})
  """
  @spec where(t(), map()) :: t()
  def where(%__MODULE__{} = builder, filter) when is_map(filter) do
    %{builder | where: filter}
  end

  @doc """
  Sets the maximum number of results to return.

  ## Examples

      Generate.limit(builder, 10)
  """
  @spec limit(t(), pos_integer()) :: t()
  def limit(%__MODULE__{} = builder, limit) when is_integer(limit) and limit > 0 do
    %{builder | limit: limit}
  end

  @doc """
  Sets the number of results to skip.

  ## Examples

      Generate.offset(builder, 20)
  """
  @spec offset(t(), non_neg_integer()) :: t()
  def offset(%__MODULE__{} = builder, offset) when is_integer(offset) and offset >= 0 do
    %{builder | offset: offset}
  end

  @doc """
  Sets the tenant for multi-tenant collections.

  ## Examples

      Generate.tenant(builder, "tenant-a")
  """
  @spec tenant(t(), String.t()) :: t()
  def tenant(%__MODULE__{} = builder, tenant) when is_binary(tenant) do
    %{builder | tenant: tenant}
  end

  @doc """
  Sets additional metadata fields to return.

  ## Examples

      Generate.additional(builder, ["distance", "certainty", "vector"])
  """
  @spec additional(t(), [String.t()]) :: t()
  def additional(%__MODULE__{} = builder, fields) when is_list(fields) do
    %{builder | additional: fields}
  end

  # ============================================================================
  # Validation
  # ============================================================================

  @doc """
  Validates the query builder has required fields.

  A valid generative query must have:
  - A search type (near_text, near_vector, etc.)
  - At least one prompt (single_prompt or grouped_task)
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = builder) do
    has_search_type?(builder) and has_prompt?(builder)
  end

  defp has_search_type?(%__MODULE__{search_type: nil}), do: false
  defp has_search_type?(%__MODULE__{}), do: true

  defp has_prompt?(%__MODULE__{single_prompt: nil, grouped_task: nil}), do: false
  defp has_prompt?(%__MODULE__{}), do: true

  # ============================================================================
  # GraphQL Generation
  # ============================================================================

  @doc """
  Converts the builder to a GraphQL query string.
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = builder) do
    fields = build_fields(builder)
    search_clause = build_search_clause(builder)
    where_clause = build_where_clause(builder)
    generate_clause = build_generate_clause(builder)
    limit_clause = build_limit_clause(builder)
    offset_clause = build_offset_clause(builder)
    tenant_clause = build_tenant_clause(builder)

    clauses =
      [search_clause, where_clause, generate_clause, limit_clause, offset_clause, tenant_clause]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    """
    {
      Get {
        #{builder.collection}(#{clauses}) {
          #{fields}
        }
      }
    }
    """
    |> String.trim()
  end

  defp build_fields(%__MODULE__{} = builder) do
    props = builder.return_properties || []
    additional = build_additional_fields(builder)

    fields =
      props
      |> Enum.join("\n          ")

    # additional always contains _additional block
    if fields == "" do
      additional
    else
      "#{fields}\n          #{additional}"
    end
  end

  defp build_additional_fields(%__MODULE__{} = builder) do
    base_fields = builder.additional || ["id"]
    generate_fields = build_generate_additional_fields(builder)

    all_fields = base_fields ++ [generate_fields]

    fields_str =
      all_fields
      |> Enum.reject(&(&1 == "" or is_nil(&1)))
      |> Enum.join("\n            ")

    "_additional {\n            #{fields_str}\n          }"
  end

  defp build_generate_additional_fields(%__MODULE__{} = builder) do
    parts = []

    parts =
      if builder.single_prompt do
        ["singleResult" | parts]
      else
        parts
      end

    parts =
      if builder.grouped_task do
        ["groupedResult" | parts]
      else
        parts
      end

    parts = ["error" | parts]

    if length(parts) > 0 do
      "generate {\n              #{Enum.join(parts, "\n              ")}\n            }"
    else
      ""
    end
  end

  defp build_search_clause(%__MODULE__{search_type: :near_text} = builder) do
    concepts =
      case builder.search_query do
        query when is_binary(query) -> [query]
        queries when is_list(queries) -> queries
      end

    concepts_str = Enum.map_join(concepts, ", ", &"\"#{escape_string(&1)}\"")
    opts = build_search_opts(builder.search_opts, [:certainty, :distance])

    if opts == "" do
      "nearText: {concepts: [#{concepts_str}]}"
    else
      "nearText: {concepts: [#{concepts_str}], #{opts}}"
    end
  end

  defp build_search_clause(%__MODULE__{search_type: :near_vector} = builder) do
    vector_str = Enum.join(builder.search_query, ", ")
    opts = build_search_opts(builder.search_opts, [:certainty, :distance])

    if opts == "" do
      "nearVector: {vector: [#{vector_str}]}"
    else
      "nearVector: {vector: [#{vector_str}], #{opts}}"
    end
  end

  defp build_search_clause(%__MODULE__{search_type: :near_object} = builder) do
    opts = build_search_opts(builder.search_opts, [:certainty, :distance])

    if opts == "" do
      "nearObject: {id: \"#{builder.search_query}\"}"
    else
      "nearObject: {id: \"#{builder.search_query}\", #{opts}}"
    end
  end

  defp build_search_clause(%__MODULE__{search_type: :bm25} = builder) do
    query_str = escape_string(builder.search_query)
    properties = Keyword.get(builder.search_opts, :properties)

    if properties do
      props_str = Enum.map_join(properties, ", ", &"\"#{&1}\"")
      "bm25: {query: \"#{query_str}\", properties: [#{props_str}]}"
    else
      "bm25: {query: \"#{query_str}\"}"
    end
  end

  defp build_search_clause(%__MODULE__{search_type: :hybrid} = builder) do
    query_str = escape_string(builder.search_query)
    alpha = Keyword.get(builder.search_opts, :alpha)
    fusion = Keyword.get(builder.search_opts, :fusion_type)

    parts = ["query: \"#{query_str}\""]
    parts = if alpha, do: parts ++ ["alpha: #{alpha}"], else: parts

    parts =
      if fusion do
        fusion_str =
          case fusion do
            :ranked -> "rankedFusion"
            :relative_score -> "relativeScoreFusion"
            other -> to_string(other)
          end

        parts ++ ["fusionType: #{fusion_str}"]
      else
        parts
      end

    "hybrid: {#{Enum.join(parts, ", ")}}"
  end

  defp build_search_clause(_), do: nil

  defp build_search_opts(opts, keys) do
    keys
    |> Enum.map(fn key ->
      case Keyword.get(opts, key) do
        nil -> nil
        value -> "#{key}: #{value}"
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp build_where_clause(%__MODULE__{where: nil}), do: nil

  defp build_where_clause(%__MODULE__{where: filter}) do
    "where: #{encode_filter(filter)}"
  end

  defp encode_filter(filter) when is_map(filter) do
    parts =
      Enum.map_join(filter, ", ", fn {key, value} ->
        key_str = to_string(key)
        value_str = encode_filter_value(key_str, value)
        "#{key_str}: #{value_str}"
      end)

    "{#{parts}}"
  end

  defp encode_filter_value("path", paths) when is_list(paths) do
    "[#{Enum.map_join(paths, ", ", &"\"#{&1}\"")}]"
  end

  defp encode_filter_value("operator", op), do: to_string(op)

  defp encode_filter_value(key, value) when is_binary(value) do
    if String.starts_with?(key, "value") do
      "\"#{escape_string(value)}\""
    else
      "\"#{escape_string(value)}\""
    end
  end

  defp encode_filter_value(_key, value) when is_number(value), do: to_string(value)
  defp encode_filter_value(_key, value) when is_boolean(value), do: to_string(value)
  defp encode_filter_value(_key, value) when is_list(value), do: inspect(value)

  defp build_generate_clause(%__MODULE__{} = builder) do
    parts = []

    parts =
      if builder.single_prompt do
        parts ++ ["singleResult: {prompt: \"#{escape_string(builder.single_prompt)}\"}"]
      else
        parts
      end

    parts =
      if builder.grouped_task do
        grouped =
          if builder.grouped_properties do
            props_str = Enum.map_join(builder.grouped_properties, ", ", &"\"#{&1}\"")

            "groupedResult: {task: \"#{escape_string(builder.grouped_task)}\", properties: [#{props_str}]}"
          else
            "groupedResult: {task: \"#{escape_string(builder.grouped_task)}\"}"
          end

        parts ++ [grouped]
      else
        parts
      end

    if length(parts) > 0 do
      "generate: {#{Enum.join(parts, ", ")}}"
    else
      nil
    end
  end

  defp build_limit_clause(%__MODULE__{limit: nil}), do: nil
  defp build_limit_clause(%__MODULE__{limit: limit}), do: "limit: #{limit}"

  defp build_offset_clause(%__MODULE__{offset: nil}), do: nil
  defp build_offset_clause(%__MODULE__{offset: 0}), do: nil
  defp build_offset_clause(%__MODULE__{offset: offset}), do: "offset: #{offset}"

  defp build_tenant_clause(%__MODULE__{tenant: nil}), do: nil
  defp build_tenant_clause(%__MODULE__{tenant: tenant}), do: "tenant: \"#{tenant}\""

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  # ============================================================================
  # Response Parsing
  # ============================================================================

  @doc """
  Parses an API response into a GenerativeResult struct.
  """
  @spec parse_response(map(), String.t()) :: GenerativeResult.t()
  def parse_response(%{"data" => %{"Get" => get}}, collection) do
    raw_objects = Map.get(get, collection, [])
    parse_objects(raw_objects)
  end

  def parse_response(_, _collection) do
    GenerativeResult.new()
  end

  defp parse_objects([]), do: GenerativeResult.new()

  defp parse_objects(raw_objects) do
    objects = Enum.map(raw_objects, &parse_single_object/1)
    generated_per_object = extract_single_results(raw_objects)
    grouped = extract_grouped_result(raw_objects)

    GenerativeResult.new(objects, grouped, generated_per_object)
  end

  defp parse_single_object(obj) do
    additional = Map.get(obj, "_additional", %{})
    properties = Map.drop(obj, ["_additional"])

    %{
      uuid: additional["id"],
      properties: properties,
      distance: additional["distance"],
      certainty: additional["certainty"],
      score: additional["score"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_single_results(raw_objects) do
    raw_objects
    |> Enum.map(fn obj ->
      get_in(obj, ["_additional", "generate", "singleResult"])
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_grouped_result(raw_objects) do
    Enum.find_value(raw_objects, fn obj ->
      get_in(obj, ["_additional", "generate", "groupedResult"])
    end)
  end

  # ============================================================================
  # Execution
  # ============================================================================

  @doc """
  Executes the generative query against Weaviate.

  ## Examples

      {:ok, result} = Generate.execute(builder, client)
  """
  @spec execute(t(), WeaviateEx.Client.t()) :: {:ok, GenerativeResult.t()} | {:error, term()}
  def execute(%__MODULE__{} = builder, client) do
    graphql = to_graphql(builder)

    case WeaviateEx.Client.graphql(client, graphql) do
      {:ok, response} ->
        result = parse_response(response, builder.collection)
        {:ok, result}

      {:error, _} = error ->
        error
    end
  end
end
