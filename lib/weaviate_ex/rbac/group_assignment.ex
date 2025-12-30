defmodule WeaviateEx.RBAC.GroupAssignment do
  @moduledoc """
  Group assignment with type information.

  Represents a group assigned to a role, including the group type which
  indicates the source of the group (currently only OIDC groups are supported).

  ## Group Types

  - `:oidc` - Group from OpenID Connect identity provider

  ## Examples

      {:ok, assignments} = RBAC.get_group_assignments(client, "viewer")
      for assignment <- assignments do
        IO.puts("\#{assignment.group_id} (type: \#{assignment.group_type})")
      end
  """

  @type group_type :: :oidc

  @type t :: %__MODULE__{
          group_id: String.t(),
          group_type: group_type()
        }

  @enforce_keys [:group_id, :group_type]
  defstruct [:group_id, :group_type]

  @doc """
  Creates a new GroupAssignment struct.

  ## Examples

      assignment = GroupAssignment.new("engineering", :oidc)
  """
  @spec new(String.t(), group_type()) :: t()
  def new(group_id, group_type) when is_binary(group_id) and is_atom(group_type) do
    %__MODULE__{group_id: group_id, group_type: group_type}
  end

  @doc """
  Parse group assignment from API response.

  ## Examples

      assignment = GroupAssignment.from_api(%{"groupId" => "eng", "groupType" => "oidc"})
      # => %GroupAssignment{group_id: "eng", group_type: :oidc}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"groupId" => group_id, "groupType" => group_type}) do
    %__MODULE__{
      group_id: group_id,
      group_type: parse_group_type(group_type)
    }
  end

  def from_api(%{"group_id" => group_id, "group_type" => group_type}) do
    %__MODULE__{
      group_id: group_id,
      group_type: parse_group_type(group_type)
    }
  end

  # Handle simple string responses (just group IDs without type info)
  def from_api(group_id) when is_binary(group_id) do
    %__MODULE__{
      group_id: group_id,
      group_type: :oidc
    }
  end

  @doc """
  Convert group assignment to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = assignment) do
    %{
      "groupId" => assignment.group_id,
      "groupType" => group_type_to_string(assignment.group_type)
    }
  end

  @doc """
  Parse group type string to atom.
  """
  @spec parse_group_type(String.t()) :: group_type()
  def parse_group_type("oidc"), do: :oidc
  def parse_group_type("OIDC"), do: :oidc
  def parse_group_type(_), do: :oidc

  @doc """
  Convert group type atom to API string.
  """
  @spec group_type_to_string(group_type()) :: String.t()
  def group_type_to_string(:oidc), do: "oidc"
end
