defmodule WeaviateEx.Query.Sort do
  @moduledoc """
  Sort builder for Weaviate queries.

  Provides a fluent API for building sort criteria.

  ## Examples

      # Single sort
      Sort.by_property("title")

      # Multiple sorts (chained)
      Sort.by_property("category")
      |> Sort.then_by_property("title", :desc)

      # Sort by timestamps
      Sort.by_creation_time(:desc)
  """

  @type order :: :asc | :desc
  @type sort_criterion :: %{path: [String.t()], order: String.t()}
  @type t :: [sort_criterion()]

  @doc """
  Create a sort by property name.

  ## Examples

      Sort.by_property("title")
      Sort.by_property("title", :desc)
  """
  @spec by_property(String.t(), order()) :: t()
  def by_property(property, order \\ :asc) do
    [%{path: [property], order: order_to_string(order)}]
  end

  @doc """
  Create a sort by creation timestamp.

  ## Examples

      Sort.by_creation_time()
      Sort.by_creation_time(:desc)
  """
  @spec by_creation_time(order()) :: t()
  def by_creation_time(order \\ :asc) do
    [%{path: ["_creationTimeUnix"], order: order_to_string(order)}]
  end

  @doc """
  Create a sort by last update timestamp.

  ## Examples

      Sort.by_update_time()
      Sort.by_update_time(:desc)
  """
  @spec by_update_time(order()) :: t()
  def by_update_time(order \\ :asc) do
    [%{path: ["_lastUpdateTimeUnix"], order: order_to_string(order)}]
  end

  @doc """
  Create a sort by object ID.

  ## Examples

      Sort.by_id()
      Sort.by_id(:desc)
  """
  @spec by_id(order()) :: t()
  def by_id(order \\ :asc) do
    [%{path: ["id"], order: order_to_string(order)}]
  end

  @doc """
  Add a secondary sort by property.

  ## Examples

      Sort.by_property("category")
      |> Sort.then_by_property("title", :desc)
  """
  @spec then_by_property(t(), String.t(), order()) :: t()
  def then_by_property(sorts, property, order \\ :asc) when is_list(sorts) do
    sorts ++ [%{path: [property], order: order_to_string(order)}]
  end

  @doc """
  Add a secondary sort by creation time.

  ## Examples

      Sort.by_property("category")
      |> Sort.then_by_creation_time(:desc)
  """
  @spec then_by_creation_time(t(), order()) :: t()
  def then_by_creation_time(sorts, order \\ :asc) when is_list(sorts) do
    sorts ++ [%{path: ["_creationTimeUnix"], order: order_to_string(order)}]
  end

  @doc """
  Add a secondary sort by update time.
  """
  @spec then_by_update_time(t(), order()) :: t()
  def then_by_update_time(sorts, order \\ :asc) when is_list(sorts) do
    sorts ++ [%{path: ["_lastUpdateTimeUnix"], order: order_to_string(order)}]
  end

  @doc """
  Add a secondary sort by ID.
  """
  @spec then_by_id(t(), order()) :: t()
  def then_by_id(sorts, order \\ :asc) when is_list(sorts) do
    sorts ++ [%{path: ["id"], order: order_to_string(order)}]
  end

  @doc """
  Convert sort criteria to GraphQL format.

  ## Examples

      Sort.by_property("title", :desc)
      |> Sort.to_graphql()
      # => "[{path: [\"title\"], order: desc}]"
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(sorts) when is_list(sorts) do
    criteria =
      Enum.map_join(sorts, ", ", fn %{path: path, order: order} ->
        path_str = Enum.map_join(path, ", ", &~s("#{&1}"))
        ~s({path: [#{path_str}], order: #{order}})
      end)

    "[#{criteria}]"
  end

  # Private helpers

  defp order_to_string(:asc), do: "asc"
  defp order_to_string(:desc), do: "desc"
end
