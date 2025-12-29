defmodule WeaviateEx.Query.GroupBy do
  @moduledoc """
  Group search results by property values.

  GroupBy clusters results based on a property path, returning
  groups with their objects. This is useful for organizing search
  results by category, type, or other grouping criteria.

  ## Examples

      # Group by category
      group_by = GroupBy.new("category")

      # Group by nested property
      group_by = GroupBy.new(["metadata", "type"])

      # With custom limits
      group_by = GroupBy.new("category",
        objects_per_group: 3,
        number_of_groups: 10
      )

      # Use in query
      Query.get("Article")
      |> Query.near_text("machine learning")
      |> Query.group_by(group_by)
      |> Query.execute(client)
  """

  @type t :: %__MODULE__{
          path: String.t() | [String.t()],
          objects_per_group: pos_integer(),
          number_of_groups: pos_integer()
        }

  @default_objects_per_group 10
  @default_number_of_groups 10

  defstruct [:path, objects_per_group: 10, number_of_groups: 10]

  @doc """
  Create a new group by configuration.

  ## Parameters

    - `path` - The property path to group by. Can be a string for simple
      properties or a list for nested properties.
    - `opts` - Options:
      - `:objects_per_group` - Maximum objects per group (default: 10)
      - `:number_of_groups` - Maximum number of groups to return (default: 10)

  ## Examples

      # Simple property
      GroupBy.new("category")

      # Nested property path
      GroupBy.new(["metadata", "type"])

      # With limits
      GroupBy.new("category", objects_per_group: 5, number_of_groups: 20)
  """
  @spec new(String.t() | [String.t()], keyword()) :: t()
  def new(path, opts \\ [])

  def new(path, opts) when is_binary(path) do
    %__MODULE__{
      path: path,
      objects_per_group: Keyword.get(opts, :objects_per_group, @default_objects_per_group),
      number_of_groups: Keyword.get(opts, :number_of_groups, @default_number_of_groups)
    }
  end

  def new(path, opts) when is_list(path) do
    %__MODULE__{
      path: path,
      objects_per_group: Keyword.get(opts, :objects_per_group, @default_objects_per_group),
      number_of_groups: Keyword.get(opts, :number_of_groups, @default_number_of_groups)
    }
  end

  @doc """
  Convert group by configuration to GraphQL format.

  ## Examples

      group_by = GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)
      GroupBy.to_graphql(group_by)
      # => "{path: [\"category\"], objectsPerGroup: 3, groups: 5}"
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = group_by) do
    path_list = normalize_path(group_by.path)
    path_str = Enum.map_join(path_list, ", ", fn p -> ~s("#{p}") end)

    parts = [
      "path: [#{path_str}]",
      "objectsPerGroup: #{group_by.objects_per_group}",
      "groups: #{group_by.number_of_groups}"
    ]

    "{#{Enum.join(parts, ", ")}}"
  end

  @doc """
  Convert group by configuration to map format (for gRPC).

  ## Examples

      group_by = GroupBy.new("category", objects_per_group: 5)
      GroupBy.to_map(group_by)
      # => %{path: ["category"], objects_per_group: 5, number_of_groups: 10}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = group_by) do
    %{
      path: normalize_path(group_by.path),
      objects_per_group: group_by.objects_per_group,
      number_of_groups: group_by.number_of_groups
    }
  end

  @doc """
  Validate group by configuration.

  ## Examples

      iex> GroupBy.valid?(GroupBy.new("category"))
      true

      iex> GroupBy.valid?(%GroupBy{path: nil})
      false

      iex> GroupBy.valid?(%GroupBy{path: "cat", objects_per_group: 0})
      false
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{path: path, objects_per_group: opg, number_of_groups: nog})
      when is_binary(path) and path != "" and opg > 0 and nog > 0,
      do: true

  def valid?(%__MODULE__{path: path, objects_per_group: opg, number_of_groups: nog})
      when is_list(path) and length(path) > 0 and opg > 0 and nog > 0,
      do: true

  def valid?(_), do: false

  # Normalize path to always be a list
  defp normalize_path(path) when is_binary(path), do: [path]
  defp normalize_path(path) when is_list(path), do: path
end
