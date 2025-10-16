defmodule WeaviateEx.API.Aggregate do
  @moduledoc """
  Aggregation operations for Phase 2.2.

  Provides statistical aggregation capabilities including:
  - Count, sum, mean, median, mode
  - Maximum, minimum
  - Top occurrences for text fields
  - Percentage true/false for boolean fields
  - GroupBy aggregations
  - Aggregation with semantic search context
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type collection_name :: String.t()
  @type opts :: keyword()
  @type metric ::
          :count
          | :sum
          | :mean
          | :median
          | :mode
          | :maximum
          | :minimum
          | :topOccurrences
          | :percentageTrue
          | :percentageFalse
          | :totalTrue
          | :totalFalse

  ## Aggregation Operations

  @doc """
  Aggregate entire collection with specified metrics.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `opts` - Options:
      - `:metrics` - List of meta metrics ([:count])
      - `:properties` - List of {property, metrics} or {property, metrics, opts} tuples

  ## Examples

      # Count all objects
      {:ok, results} = Aggregate.over_all(client, "Article", metrics: [:count])

      # Aggregate numeric properties
      {:ok, results} = Aggregate.over_all(client, "Product",
        properties: [
          {:price, [:sum, :mean, :maximum, :minimum]}
        ]
      )

      # Text property with top occurrences
      {:ok, results} = Aggregate.over_all(client, "Article",
        properties: [
          {:category, [:topOccurrences], limit: 5}
        ]
      )

  ## Returns
    * `{:ok, [map()]}` - List of aggregation results
    * `{:error, Error.t()}` - Error if aggregation fails
  """
  @spec over_all(Client.t(), collection_name(), opts()) :: {:ok, [map()]} | {:error, Error.t()}
  def over_all(client, collection_name, opts \\ []) do
    execute_aggregate(client, collection_name, nil, nil, nil, opts)
  end

  @doc """
  Aggregate with semantic text search context.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `concepts` - Search concepts/query
    * `opts` - Options (same as over_all/3 plus :certainty, :distance)

  ## Examples

      {:ok, results} = Aggregate.with_near_text(client, "Article",
        "artificial intelligence",
        metrics: [:count]
      )

      {:ok, results} = Aggregate.with_near_text(client, "Article",
        "popular topics",
        certainty: 0.7,
        properties: [
          {:views, [:mean, :sum]}
        ]
      )

  ## Returns
    * `{:ok, [map()]}` - List of aggregation results
    * `{:error, Error.t()}` - Error if aggregation fails
  """
  @spec with_near_text(Client.t(), collection_name(), String.t(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def with_near_text(client, collection_name, concepts, opts \\ []) do
    execute_aggregate(client, collection_name, :near_text, concepts, nil, opts)
  end

  @doc """
  Aggregate with vector similarity search.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `vector` - Search vector
    * `opts` - Options (same as over_all/3 plus :certainty, :distance)

  ## Examples

      {:ok, results} = Aggregate.with_near_vector(client, "Article", vector,
        metrics: [:count]
      )

  ## Returns
    * `{:ok, [map()]}` - List of aggregation results
    * `{:error, Error.t()}` - Error if aggregation fails
  """
  @spec with_near_vector(Client.t(), collection_name(), [float()], opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def with_near_vector(client, collection_name, vector, opts \\ []) do
    execute_aggregate(client, collection_name, :near_vector, vector, nil, opts)
  end

  @doc """
  Aggregate with filter conditions.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `filter` - Filter map (GraphQL where clause format)
    * `opts` - Options (same as over_all/3)

  ## Examples

      filter = %{
        path: ["status"],
        operator: "Equal",
        valueText: "published"
      }

      {:ok, results} = Aggregate.with_where(client, "Article", filter,
        metrics: [:count]
      )

  ## Returns
    * `{:ok, [map()]}` - List of aggregation results
    * `{:error, Error.t()}` - Error if aggregation fails
  """
  @spec with_where(Client.t(), collection_name(), map(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def with_where(client, collection_name, filter, opts \\ []) do
    execute_aggregate(client, collection_name, :where, nil, filter, opts)
  end

  @doc """
  Aggregate results grouped by property.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `property` - Property to group by (supports nested paths like "author.name")
    * `opts` - Options (same as over_all/3)

  ## Examples

      {:ok, results} = Aggregate.group_by(client, "Article", "category",
        metrics: [:count]
      )

      {:ok, results} = Aggregate.group_by(client, "Article", "author",
        properties: [
          {:views, [:mean, :sum]}
        ],
        metrics: [:count]
      )

  ## Returns
    * `{:ok, [map()]}` - List of grouped aggregation results
    * `{:error, Error.t()}` - Error if aggregation fails
  """
  @spec group_by(Client.t(), collection_name(), String.t(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def group_by(client, collection_name, property, opts \\ []) do
    # Parse nested property paths
    path = String.split(property, ".") |> Enum.map(&String.trim/1)
    group_opts = Keyword.put(opts, :group_by_path, path)
    execute_aggregate(client, collection_name, nil, nil, nil, group_opts)
  end

  ## Private Implementation

  defp execute_aggregate(client, collection_name, search_type, search_param, filter, opts) do
    # Build the fields to aggregate
    fields = build_aggregate_fields(opts)

    # Build search parameters
    search_clause = build_search_clause(search_type, search_param, filter, opts)

    # Build groupBy clause if present
    group_by_clause = build_group_by_clause(Keyword.get(opts, :group_by_path))

    # Build full GraphQL query
    query = """
    {
      Aggregate {
        #{collection_name}#{search_clause} {
          #{group_by_clause}
          #{fields}
        }
      }
    }
    """

    # Execute query
    case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
      {:ok, %{"data" => %{"Aggregate" => aggregate_results}}} ->
        results = Map.get(aggregate_results, collection_name, [])
        {:ok, results}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  defp build_aggregate_fields(opts) do
    parts = []

    # Add meta metrics (count, etc.)
    parts =
      if metrics = Keyword.get(opts, :metrics) do
        meta_fields = Enum.map(metrics, &metric_to_string/1) |> Enum.join("\n        ")
        ["meta {\n        #{meta_fields}\n      }" | parts]
      else
        parts
      end

    # Add property-specific metrics
    parts =
      if properties = Keyword.get(opts, :properties) do
        prop_fields =
          Enum.map(properties, fn
            {prop, metrics} ->
              build_property_metrics(prop, metrics, [])

            {prop, metrics, prop_opts} ->
              build_property_metrics(prop, metrics, prop_opts)
          end)

        prop_fields ++ parts
      else
        parts
      end

    if Enum.empty?(parts) do
      # Default: just count
      "meta { count }"
    else
      Enum.join(Enum.reverse(parts), "\n      ")
    end
  end

  defp build_property_metrics(property, metrics, opts) do
    prop_name = if is_atom(property), do: Atom.to_string(property), else: property

    metrics_str =
      Enum.map(metrics, fn metric ->
        case metric do
          :topOccurrences ->
            limit = Keyword.get(opts, :limit, 5)
            "topOccurrences(limit: #{limit}) { value occurs }"

          other ->
            metric_to_string(other)
        end
      end)
      |> Enum.join("\n        ")

    "#{prop_name} {\n        #{metrics_str}\n      }"
  end

  defp metric_to_string(:count), do: "count"
  defp metric_to_string(:sum), do: "sum"
  defp metric_to_string(:mean), do: "mean"
  defp metric_to_string(:median), do: "median"
  defp metric_to_string(:mode), do: "mode"
  defp metric_to_string(:maximum), do: "maximum"
  defp metric_to_string(:minimum), do: "minimum"
  defp metric_to_string(:topOccurrences), do: "topOccurrences { value occurs }"
  defp metric_to_string(:percentageTrue), do: "percentageTrue"
  defp metric_to_string(:percentageFalse), do: "percentageFalse"
  defp metric_to_string(:totalTrue), do: "totalTrue"
  defp metric_to_string(:totalFalse), do: "totalFalse"

  defp build_search_clause(nil, nil, nil, _opts), do: ""

  defp build_search_clause(:near_text, concepts, _filter, opts) do
    certainty = Keyword.get(opts, :certainty)
    distance = Keyword.get(opts, :distance)

    parts = [~s(concepts: ["#{concepts}"])]

    parts =
      if certainty do
        [~s(certainty: #{certainty}) | parts]
      else
        parts
      end

    parts =
      if distance do
        [~s(distance: #{distance}) | parts]
      else
        parts
      end

    "(\n      nearText: { #{Enum.join(Enum.reverse(parts), ", ")} }\n    )"
  end

  defp build_search_clause(:near_vector, vector, _filter, opts) do
    certainty = Keyword.get(opts, :certainty)
    distance = Keyword.get(opts, :distance)

    vector_str = "[#{Enum.join(vector, ", ")}]"
    parts = ["vector: #{vector_str}"]

    parts =
      if certainty do
        [~s(certainty: #{certainty}) | parts]
      else
        parts
      end

    parts =
      if distance do
        [~s(distance: #{distance}) | parts]
      else
        parts
      end

    "(\n      nearVector: { #{Enum.join(Enum.reverse(parts), ", ")} }\n    )"
  end

  defp build_search_clause(:where, _param, filter, _opts) do
    filter_str = build_filter_string(filter)
    "(\n      where: #{filter_str}\n    )"
  end

  defp build_filter_string(%{path: path, operator: operator} = filter) do
    parts = [
      ~s(path: ["#{Enum.join(path, "\", \"")}"]),
      "operator: #{operator}"
    ]

    parts = maybe_add_filter_value(parts, filter, :valueText)
    parts = maybe_add_filter_value(parts, filter, :valueInt)
    parts = maybe_add_filter_value(parts, filter, :valueNumber)
    parts = maybe_add_filter_value(parts, filter, :valueBoolean)

    "{ #{Enum.join(parts, ", ")} }"
  end

  defp maybe_add_filter_value(parts, filter, key) do
    case Map.get(filter, key) do
      nil ->
        parts

      value when is_binary(value) ->
        parts ++ [~s(#{key}: "#{value}")]

      value ->
        parts ++ ["#{key}: #{value}"]
    end
  end

  defp build_group_by_clause(nil), do: ""

  defp build_group_by_clause(path) do
    ~s(groupedBy {\n        path: ["#{Enum.join(path, "\", \"")}"]\n        value\n      })
  end
end
