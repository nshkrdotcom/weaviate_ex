defmodule WeaviateEx.Groups.Group do
  @moduledoc """
  OIDC Group representation.

  Groups are used in Weaviate when OIDC authentication is enabled.
  Users authenticated via OIDC can belong to groups, and roles can be
  assigned to these groups.

  ## Examples

      %Group{
        name: "engineering",
        roles: ["developer", "viewer"]
      }
  """

  @type t :: %__MODULE__{
          name: String.t(),
          roles: [String.t()]
        }

  defstruct [:name, roles: []]

  @doc """
  Decode a group from API response.

  ## Examples

      {:ok, group} = Group.from_api(%{
        "name" => "engineering",
        "roles" => ["developer"]
      })
  """
  @spec from_api(map()) :: {:ok, t()}
  def from_api(api_data) when is_map(api_data) do
    {:ok,
     %__MODULE__{
       name: Map.get(api_data, "name"),
       roles: Map.get(api_data, "roles", [])
     }}
  end
end
