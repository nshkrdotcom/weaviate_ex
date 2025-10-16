defmodule WeaviateEx.Filter do
  @moduledoc """
  Filter system for building complex query filters.

  Provides a fluent API for constructing filters with operators and combinators
  that can be converted to GraphQL format for Weaviate queries.

  ## Examples

      # Simple equality filter
      Filter.equal("status", "published")

      # Numeric comparison
      Filter.greater_than("views", 100)

      # Combining filters with AND
      Filter.all_of([
        Filter.equal("status", "published"),
        Filter.greater_than("views", 100)
      ])

      # Complex nested filters
      Filter.all_of([
        Filter.any_of([
          Filter.equal("type", "article"),
          Filter.equal("type", "post")
        ]),
        Filter.greater_than("createdAt", "2024-01-01")
      ])
  """

  @type filter :: map()
  @type path :: String.t() | [String.t()]
  @type operator :: atom()
  @type value :: any()

  ## Constructors

  @doc """
  Create a filter by property with an operator.

  ## Examples

      Filter.by_property("status", :equal, "published")
      Filter.by_property("views", :greater_than, 1000)
  """
  @spec by_property(String.t(), operator(), value()) :: filter()
  def by_property(property, operator, value) do
    base = %{
      path: [property],
      operator: operator
    }

    add_value(base, value)
  end

  @doc """
  Create a filter by ID.

  ## Examples

      Filter.by_id(:equal, "00000000-0000-0000-0000-000000000001")
  """
  @spec by_id(operator(), String.t()) :: filter()
  def by_id(operator, uuid) do
    %{
      path: ["id"],
      operator: operator,
      value_text: uuid
    }
  end

  @doc """
  Create a filter by reference property.

  ## Examples

      Filter.by_ref("hasAuthor", "Author", :equal, "John Doe")
  """
  @spec by_ref(String.t(), String.t(), operator(), value()) :: filter()
  def by_ref(ref_property, target_class, operator, value) when is_binary(value) do
    %{
      path: [ref_property, target_class, "name"],
      operator: operator,
      value_text: value
    }
  end

  ## Operators

  @doc "Equal operator"
  @spec equal(String.t(), value()) :: filter()
  def equal(property, value), do: by_property(property, :equal, value)

  @doc "Not equal operator"
  @spec not_equal(String.t(), value()) :: filter()
  def not_equal(property, value), do: by_property(property, :not_equal, value)

  @doc "Less than operator"
  @spec less_than(String.t(), number()) :: filter()
  def less_than(property, value), do: by_property(property, :less_than, value)

  @doc "Less than or equal operator"
  @spec less_or_equal(String.t(), number()) :: filter()
  def less_or_equal(property, value), do: by_property(property, :less_or_equal, value)

  @doc "Greater than operator"
  @spec greater_than(String.t(), number()) :: filter()
  def greater_than(property, value), do: by_property(property, :greater_than, value)

  @doc "Greater than or equal operator"
  @spec greater_or_equal(String.t(), number()) :: filter()
  def greater_or_equal(property, value), do: by_property(property, :greater_or_equal, value)

  @doc "Like operator (wildcard matching)"
  @spec like(String.t(), String.t()) :: filter()
  def like(property, pattern), do: by_property(property, :like, pattern)

  @doc "Contains any operator (array intersection)"
  @spec contains_any(String.t(), [String.t()]) :: filter()
  def contains_any(property, values) when is_list(values) do
    %{
      path: [property],
      operator: :contains_any,
      value_text_array: values
    }
  end

  @doc "Contains all operator (array subset)"
  @spec contains_all(String.t(), [String.t()]) :: filter()
  def contains_all(property, values) when is_list(values) do
    %{
      path: [property],
      operator: :contains_all,
      value_text_array: values
    }
  end

  @doc "Is null operator"
  @spec is_null(String.t()) :: filter()
  def is_null(property) do
    %{
      path: [property],
      operator: :is_null,
      value_boolean: true
    }
  end

  @doc """
  Within geo range operator.

  ## Examples

      Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)
  """
  @spec within_geo_range(String.t(), {float(), float()}, float()) :: filter()
  def within_geo_range(property, {latitude, longitude}, distance) do
    %{
      path: [property],
      operator: :within_geo_range,
      value_geo_range: %{
        latitude: latitude,
        longitude: longitude,
        distance: distance
      }
    }
  end

  ## Combinators

  @doc """
  Combine filters with AND logic.

  All filters must match for the result to be included.

  ## Examples

      Filter.all_of([
        Filter.equal("status", "published"),
        Filter.greater_than("views", 100)
      ])
  """
  @spec all_of([filter()]) :: filter()
  def all_of(filters) when is_list(filters) do
    %{
      operator: :and,
      operands: filters
    }
  end

  @doc """
  Combine filters with OR logic.

  At least one filter must match for the result to be included.

  ## Examples

      Filter.any_of([
        Filter.equal("status", "draft"),
        Filter.equal("status", "published")
      ])
  """
  @spec any_of([filter()]) :: filter()
  def any_of(filters) when is_list(filters) do
    %{
      operator: :or,
      operands: filters
    }
  end

  @doc """
  Negate a filter.

  ## Examples

      Filter.not_(Filter.equal("archived", true))
  """
  @spec not_(filter()) :: filter()
  def not_(filter) do
    %{
      operator: :not,
      operands: [filter]
    }
  end

  ## GraphQL Conversion

  @doc """
  Convert a filter to GraphQL format.

  ## Examples

      filter = Filter.equal("status", "published")
      Filter.to_graphql(filter)
      # => %{path: ["status"], operator: "Equal", valueText: "published"}
  """
  @spec to_graphql(filter()) :: map()
  def to_graphql(%{operator: combinator, operands: operands})
      when combinator in [:and, :or, :not] do
    %{
      operator: capitalize_operator(combinator),
      operands: Enum.map(operands, &to_graphql/1)
    }
  end

  def to_graphql(%{path: path, operator: operator} = filter) do
    base = %{
      path: path,
      operator: capitalize_operator(operator)
    }

    base
    |> maybe_add_graphql_value(:value_text, :valueText, filter)
    |> maybe_add_graphql_value(:value_int, :valueInt, filter)
    |> maybe_add_graphql_value(:value_number, :valueNumber, filter)
    |> maybe_add_graphql_value(:value_boolean, :valueBoolean, filter)
    |> maybe_add_graphql_value(:value_text_array, :valueTextArray, filter)
    |> maybe_add_graphql_value(:value_int_array, :valueIntArray, filter)
    |> maybe_add_graphql_value(:value_number_array, :valueNumberArray, filter)
    |> maybe_add_graphql_value(:value_boolean_array, :valueBooleanArray, filter)
    |> maybe_add_graphql_value(:value_date, :valueDate, filter)
    |> maybe_add_graphql_value(:value_geo_range, :valueGeoRange, filter)
  end

  ## Private Helpers

  defp add_value(filter, value) when is_binary(value), do: Map.put(filter, :value_text, value)
  defp add_value(filter, value) when is_integer(value), do: Map.put(filter, :value_int, value)
  defp add_value(filter, value) when is_float(value), do: Map.put(filter, :value_number, value)
  defp add_value(filter, value) when is_boolean(value), do: Map.put(filter, :value_boolean, value)
  defp add_value(filter, value) when is_list(value), do: Map.put(filter, :value_text_array, value)
  defp add_value(filter, value), do: Map.put(filter, :value_text, to_string(value))

  defp maybe_add_graphql_value(result, key, graphql_key, filter) do
    case Map.get(filter, key) do
      nil -> result
      value -> Map.put(result, graphql_key, value)
    end
  end

  defp capitalize_operator(:and), do: "And"
  defp capitalize_operator(:or), do: "Or"
  defp capitalize_operator(:not), do: "Not"
  defp capitalize_operator(:equal), do: "Equal"
  defp capitalize_operator(:not_equal), do: "NotEqual"
  defp capitalize_operator(:less_than), do: "LessThan"
  defp capitalize_operator(:less_or_equal), do: "LessThanEqual"
  defp capitalize_operator(:greater_than), do: "GreaterThan"
  defp capitalize_operator(:greater_or_equal), do: "GreaterThanEqual"
  defp capitalize_operator(:like), do: "Like"
  defp capitalize_operator(:contains_any), do: "ContainsAny"
  defp capitalize_operator(:contains_all), do: "ContainsAll"
  defp capitalize_operator(:is_null), do: "IsNull"
  defp capitalize_operator(:within_geo_range), do: "WithinGeoRange"
  defp capitalize_operator(op), do: op |> to_string() |> Macro.camelize()
end
