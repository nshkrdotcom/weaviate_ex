defmodule WeaviateEx.Query.GroupBy do
  @moduledoc """
  GroupBy configuration for search queries.

  Groups search results by a specified property.

  ## Examples

      # Basic group by
      group_by = GroupBy.new("category")

      # With custom limits
      group_by = GroupBy.new("category",
        objects_per_group: 3,
        number_of_groups: 5
      )

      # Use in query
      Query.get("Article")
      |> Query.near_text("search")
      |> Query.group_by(group_by)
  """

  @type t :: %__MODULE__{
          prop: String.t(),
          objects_per_group: pos_integer(),
          number_of_groups: pos_integer()
        }

  defstruct [:prop, objects_per_group: 10, number_of_groups: 10]

  @doc """
  Create a new group by configuration.

  ## Parameters

    - `prop` - The property to group by
    - `opts` - Options:
      - `:objects_per_group` - Number of objects per group (default: 10)
      - `:number_of_groups` - Number of groups to return (default: 10)

  ## Examples

      GroupBy.new("category")
      GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)
  """
  @spec new(String.t(), keyword()) :: t()
  def new(prop, opts \\ []) when is_binary(prop) do
    %__MODULE__{
      prop: prop,
      objects_per_group: Keyword.get(opts, :objects_per_group, 10),
      number_of_groups: Keyword.get(opts, :number_of_groups, 10)
    }
  end

  @doc """
  Convert group by configuration to GraphQL format.

  ## Examples

      group_by = GroupBy.new("category", objects_per_group: 3, number_of_groups: 5)
      GroupBy.to_graphql(group_by)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = group_by) do
    parts = [
      ~s(path: ["#{group_by.prop}"]),
      "objectsPerGroup: #{group_by.objects_per_group}",
      "groups: #{group_by.number_of_groups}"
    ]

    "{#{Enum.join(parts, ", ")}}"
  end
end
