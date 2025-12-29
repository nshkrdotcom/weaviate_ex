defmodule WeaviateEx.Filter.RefPath do
  @moduledoc """
  Fluent API for building deep reference path filters.

  Allows filtering through chains of references to reach nested properties.
  This enables complex filtering scenarios where you need to filter based
  on properties of objects that are multiple reference hops away.

  ## Examples

      # Filter articles where the author's company is in technology
      RefPath.through("hasAuthor", "Author")
      |> RefPath.through("worksAt", "Company")
      |> RefPath.property("industry", :equal, "Technology")

      # Filter by author name
      RefPath.through("hasAuthor", "Author")
      |> RefPath.property("name", :like, "John*")

      # Use with Filter combinators
      Filter.all_of([
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("verified", :equal, true),
        Filter.equal("status", "published")
      ])
  """

  @type segment :: {String.t(), String.t()}

  @type t :: %__MODULE__{
          segments: [segment()]
        }

  defstruct segments: []

  @doc """
  Start a reference path with the first reference.

  ## Arguments

    - `property` - Reference property name
    - `target_collection` - Target collection name

  ## Examples

      RefPath.through("hasAuthor", "Author")
  """
  @spec through(String.t(), String.t()) :: t()
  def through(property, target_collection)
      when is_binary(property) and is_binary(target_collection) do
    %__MODULE__{segments: [{property, target_collection}]}
  end

  @doc """
  Continue a reference path with another reference hop.

  ## Arguments

    - `ref_path` - Existing reference path
    - `property` - Reference property name
    - `target_collection` - Target collection name

  ## Examples

      RefPath.through("hasAuthor", "Author")
      |> RefPath.through("worksAt", "Company")
  """
  @spec through(t(), String.t(), String.t()) :: t()
  def through(%__MODULE__{segments: segments}, property, target_collection)
      when is_binary(property) and is_binary(target_collection) do
    %__MODULE__{segments: segments ++ [{property, target_collection}]}
  end

  @doc """
  Terminate the path with a property filter.

  Creates a filter that can be used with `WeaviateEx.Filter` combinators.

  ## Arguments

    - `ref_path` - The reference path built with `through/2`
    - `property` - Final property name to filter on
    - `operator` - Filter operator (`:equal`, `:greater_than`, etc.)
    - `value` - Filter value

  ## Examples

      RefPath.through("hasAuthor", "Author")
      |> RefPath.property("name", :equal, "John")

      RefPath.through("hasAuthor", "Author")
      |> RefPath.through("worksAt", "Company")
      |> RefPath.property("industry", :equal, "Technology")
  """
  @spec property(t(), String.t(), atom(), term()) :: map()
  def property(%__MODULE__{segments: segments}, property, operator, value)
      when is_binary(property) do
    path = build_path(segments, property)

    %{
      path: path,
      operator: operator
    }
    |> add_value(value)
  end

  @doc """
  Build the full path list from segments.

  ## Examples

      segments = [{"hasAuthor", "Author"}, {"worksAt", "Company"}]
      RefPath.build_path(segments, "name")
      #=> ["hasAuthor", "Author", "worksAt", "Company", "name"]
  """
  @spec build_path([segment()], String.t()) :: [String.t()]
  def build_path(segments, final_property) when is_list(segments) and is_binary(final_property) do
    path_parts =
      Enum.flat_map(segments, fn {prop, collection} ->
        [prop, collection]
      end)

    path_parts ++ [final_property]
  end

  @doc """
  Get the path without a final property.

  Useful for reference count filters or other operations
  that don't need a final property.

  ## Examples

      path = RefPath.through("hasAuthor", "Author")
      RefPath.to_path(path)
      #=> ["hasAuthor", "Author"]
  """
  @spec to_path(t()) :: [String.t()]
  def to_path(%__MODULE__{segments: segments}) do
    Enum.flat_map(segments, fn {prop, collection} ->
      [prop, collection]
    end)
  end

  @doc """
  Get the number of hops in the reference path.

  ## Examples

      RefPath.through("hasAuthor", "Author")
      |> RefPath.through("worksAt", "Company")
      |> RefPath.depth()
      #=> 2
  """
  @spec depth(t()) :: non_neg_integer()
  def depth(%__MODULE__{segments: segments}) do
    length(segments)
  end

  # Private helpers

  defp add_value(filter, value) when is_binary(value), do: Map.put(filter, :value_text, value)
  defp add_value(filter, value) when is_integer(value), do: Map.put(filter, :value_int, value)
  defp add_value(filter, value) when is_float(value), do: Map.put(filter, :value_number, value)
  defp add_value(filter, value) when is_boolean(value), do: Map.put(filter, :value_boolean, value)

  defp add_value(filter, value) when is_list(value) do
    cond do
      Enum.all?(value, &is_binary/1) -> Map.put(filter, :value_text_array, value)
      Enum.all?(value, &is_integer/1) -> Map.put(filter, :value_int_array, value)
      Enum.all?(value, &is_number/1) -> Map.put(filter, :value_number_array, value)
      true -> Map.put(filter, :value_text_array, Enum.map(value, &to_string/1))
    end
  end

  defp add_value(filter, value), do: Map.put(filter, :value_text, to_string(value))
end
