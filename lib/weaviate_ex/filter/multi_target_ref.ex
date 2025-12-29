defmodule WeaviateEx.Filter.MultiTargetRef do
  @moduledoc """
  Filter builder for multi-target reference properties.

  When a reference property can point to multiple collections,
  use this module to filter by a specific target collection.

  ## Examples

      # Filter where "relatedTo" points to an Article with specific title
      MultiTargetRef.new("relatedTo", "Article")
      |> MultiTargetRef.where("title", :equal, "My Article")

      # Filter where "mentions" points to a verified Person
      MultiTargetRef.new("mentions", "Person")
      |> MultiTargetRef.where("verified", :equal, true)

      # Use with Filter combinators
      Filter.all_of([
        MultiTargetRef.new("relatedTo", "Article")
        |> MultiTargetRef.where("status", :equal, "published"),
        Filter.equal("featured", true)
      ])

      # Deep path filtering
      MultiTargetRef.new("mentions", "Person")
      |> MultiTargetRef.deep_where(fn path ->
        path
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("industry", :equal, "Tech")
      end)
  """

  alias WeaviateEx.Filter.RefPath

  @type t :: %__MODULE__{
          property: String.t(),
          target: String.t()
        }

  defstruct [:property, :target]

  @doc """
  Create a new multi-target reference filter builder.

  ## Arguments

    - `property` - The multi-target reference property name
    - `target_collection` - The specific collection to filter on

  ## Examples

      MultiTargetRef.new("relatedTo", "Article")
      MultiTargetRef.new("mentions", "Person")
  """
  @spec new(String.t(), String.t()) :: t()
  def new(property, target_collection)
      when is_binary(property) and is_binary(target_collection) do
    %__MODULE__{
      property: property,
      target: target_collection
    }
  end

  @doc """
  Add a property filter condition.

  ## Arguments

    - `ref` - The MultiTargetRef struct
    - `property` - Property name in the target collection
    - `operator` - Filter operator
    - `value` - Filter value

  ## Examples

      MultiTargetRef.new("relatedTo", "Article")
      |> MultiTargetRef.where("title", :equal, "Test")

      MultiTargetRef.new("mentions", "Person")
      |> MultiTargetRef.where("verified", :equal, true)
  """
  @spec where(t(), String.t(), atom(), term()) :: map()
  def where(%__MODULE__{property: ref_prop, target: target}, property, operator, value)
      when is_binary(property) do
    base = %{
      path: [ref_prop, target, property],
      operator: operator,
      target_collection: target
    }

    add_value(base, value)
  end

  @doc """
  Build a deep path filter through the multi-target reference.

  Use this when you need to filter through multiple levels of references
  starting from a multi-target reference.

  ## Examples

      MultiTargetRef.new("mentions", "Person")
      |> MultiTargetRef.deep_where(fn path ->
        path
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("industry", :equal, "Tech")
      end)
  """
  @spec deep_where(t(), (RefPath.t() -> map())) :: map()
  def deep_where(%__MODULE__{property: ref_prop, target: target}, path_fn)
      when is_function(path_fn, 1) do
    # Create initial RefPath with the multi-target reference
    initial_path = %RefPath{segments: [{ref_prop, target}]}
    filter = path_fn.(initial_path)
    Map.put(filter, :target_collection, target)
  end

  @doc """
  Create a reference path for chaining with RefPath.

  Use this when you want to start a RefPath from a multi-target reference.

  ## Examples

      MultiTargetRef.new("mentions", "Person")
      |> MultiTargetRef.as_ref_path()
      |> RefPath.through("worksAt", "Company")
      |> RefPath.property("name", :equal, "Acme")
  """
  @spec as_ref_path(t()) :: RefPath.t()
  def as_ref_path(%__MODULE__{property: ref_prop, target: target}) do
    %RefPath{segments: [{ref_prop, target}]}
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
