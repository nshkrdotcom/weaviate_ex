defmodule WeaviateEx.Users.User do
  @moduledoc """
  User structs for Weaviate user management.

  This module defines structs for different user types:

  - `User.DB` - Database-managed users (created via API)
  - `User.OIDC` - OIDC-managed users (authenticated via external provider)
  - `User.Own` - Current authenticated user information

  ## Examples

      # DB User
      %User.DB{
        user_id: "john.doe",
        api_key: "secret-key",
        active: true,
        roles: ["editor"]
      }

      # OIDC User
      %User.OIDC{
        user_id: "oauth@company.com",
        groups: ["engineering"],
        roles: ["developer"]
      }

      # Current user info
      %User.Own{
        user_id: "me",
        user_type: :db_user,
        roles: ["admin"],
        groups: []
      }
  """

  @type user_type :: :db_user | :db_env_user | :oidc

  defmodule DB do
    @moduledoc """
    Database-managed user.

    These users are created and managed via the Weaviate API.
    They authenticate using API keys.
    """

    @type t :: %__MODULE__{
            user_id: String.t(),
            api_key: String.t() | nil,
            active: boolean(),
            roles: [String.t()]
          }

    defstruct [:user_id, :api_key, :active, roles: []]
  end

  defmodule OIDC do
    @moduledoc """
    OIDC-managed user.

    These users are authenticated via an external OIDC provider.
    Their groups are managed by the OIDC provider.
    """

    @type t :: %__MODULE__{
            user_id: String.t(),
            groups: [String.t()],
            roles: [String.t()]
          }

    defstruct [:user_id, groups: [], roles: []]
  end

  defmodule Own do
    @moduledoc """
    Current authenticated user information.

    Represents the currently authenticated user making the request.
    """

    @type t :: %__MODULE__{
            user_id: String.t(),
            user_type: WeaviateEx.Users.User.user_type(),
            roles: [String.t()],
            groups: [String.t()]
          }

    defstruct [:user_id, :user_type, roles: [], groups: []]
  end

  @doc """
  Decode a user from API response.

  Returns the appropriate user struct based on the userType field.

  ## Examples

      {:ok, user} = User.from_api(%{
        "userId" => "john",
        "userType" => "db_user",
        "active" => true,
        "roles" => ["admin"]
      })
  """
  @spec from_api(map()) :: {:ok, DB.t() | OIDC.t()} | {:error, String.t()}
  def from_api(api_data) when is_map(api_data) do
    user_type = parse_user_type(Map.get(api_data, "userType"))

    case user_type do
      type when type in [:db_user, :db_env_user] ->
        {:ok, decode_db_user(api_data)}

      :oidc ->
        {:ok, decode_oidc_user(api_data)}
    end
  end

  defp decode_db_user(api_data) do
    %DB{
      user_id: Map.get(api_data, "userId"),
      api_key: Map.get(api_data, "apiKey"),
      active: Map.get(api_data, "active", false),
      roles: Map.get(api_data, "roles", [])
    }
  end

  defp decode_oidc_user(api_data) do
    %OIDC{
      user_id: Map.get(api_data, "userId"),
      groups: Map.get(api_data, "groups", []),
      roles: Map.get(api_data, "roles", [])
    }
  end

  @doc """
  Decode the current user (own) from API response.

  ## Examples

      {:ok, user} = User.from_api_own(%{
        "userId" => "me",
        "userType" => "db_user",
        "roles" => ["admin"],
        "groups" => []
      })
  """
  @spec from_api_own(map()) :: {:ok, Own.t()}
  def from_api_own(api_data) when is_map(api_data) do
    {:ok,
     %Own{
       user_id: Map.get(api_data, "userId"),
       user_type: parse_user_type(Map.get(api_data, "userType")),
       roles: Map.get(api_data, "roles", []),
       groups: Map.get(api_data, "groups", [])
     }}
  end

  @doc """
  Parse user type string to atom.

  ## Examples

      User.parse_user_type("db_user")     # => :db_user
      User.parse_user_type("db_env_user") # => :db_env_user
      User.parse_user_type("oidc")        # => :oidc
  """
  @spec parse_user_type(String.t() | nil) :: user_type()
  def parse_user_type("db_user"), do: :db_user
  def parse_user_type("db_env_user"), do: :db_env_user
  def parse_user_type("oidc"), do: :oidc
  def parse_user_type(_), do: :db_user
end
