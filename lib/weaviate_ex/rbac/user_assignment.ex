defmodule WeaviateEx.RBAC.UserAssignment do
  @moduledoc """
  User assignment with type information.

  Represents a user assigned to a role, including their user type which
  indicates how the user was created/authenticated.

  ## User Types

  - `:db_user` - Database-backed user created via the Users.DB API
  - `:db_env_user` - Database user created via environment variables
  - `:oidc` - User authenticated via OpenID Connect

  ## Examples

      {:ok, assignments} = RBAC.get_user_assignments(client, "editor")
      for assignment <- assignments do
        IO.puts("\#{assignment.user_id} (type: \#{assignment.user_type})")
      end
  """

  @type user_type :: :db_user | :db_env_user | :oidc

  @type t :: %__MODULE__{
          user_id: String.t(),
          user_type: user_type()
        }

  @enforce_keys [:user_id, :user_type]
  defstruct [:user_id, :user_type]

  @doc """
  Creates a new UserAssignment struct.

  ## Examples

      assignment = UserAssignment.new("john.doe", :db_user)
  """
  @spec new(String.t(), user_type()) :: t()
  def new(user_id, user_type) when is_binary(user_id) and is_atom(user_type) do
    %__MODULE__{user_id: user_id, user_type: user_type}
  end

  @doc """
  Parse user assignment from API response.

  ## Examples

      assignment = UserAssignment.from_api(%{"userId" => "john", "userType" => "db_user"})
      # => %UserAssignment{user_id: "john", user_type: :db_user}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"userId" => user_id, "userType" => user_type}) do
    %__MODULE__{
      user_id: user_id,
      user_type: parse_user_type(user_type)
    }
  end

  def from_api(%{"user_id" => user_id, "user_type" => user_type}) do
    %__MODULE__{
      user_id: user_id,
      user_type: parse_user_type(user_type)
    }
  end

  # Handle simple string responses (just user IDs without type info)
  def from_api(user_id) when is_binary(user_id) do
    %__MODULE__{
      user_id: user_id,
      user_type: :db_user
    }
  end

  @doc """
  Convert user assignment to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = assignment) do
    %{
      "userId" => assignment.user_id,
      "userType" => user_type_to_string(assignment.user_type)
    }
  end

  @doc """
  Parse user type string to atom.
  """
  @spec parse_user_type(String.t()) :: user_type()
  def parse_user_type("db_user"), do: :db_user
  def parse_user_type("db-user"), do: :db_user
  def parse_user_type("dbUser"), do: :db_user
  def parse_user_type("db_env_user"), do: :db_env_user
  def parse_user_type("db-env-user"), do: :db_env_user
  def parse_user_type("dbEnvUser"), do: :db_env_user
  def parse_user_type("oidc"), do: :oidc
  def parse_user_type("OIDC"), do: :oidc
  def parse_user_type(_), do: :db_user

  @doc """
  Convert user type atom to API string.
  """
  @spec user_type_to_string(user_type()) :: String.t()
  def user_type_to_string(:db_user), do: "db_user"
  def user_type_to_string(:db_env_user), do: "db_env_user"
  def user_type_to_string(:oidc), do: "oidc"

  @doc """
  Check if the user is a database-backed user.
  """
  @spec db_user?(t()) :: boolean()
  def db_user?(%__MODULE__{user_type: :db_user}), do: true
  def db_user?(%__MODULE__{user_type: :db_env_user}), do: true
  def db_user?(_), do: false

  @doc """
  Check if the user is an OIDC user.
  """
  @spec oidc_user?(t()) :: boolean()
  def oidc_user?(%__MODULE__{user_type: :oidc}), do: true
  def oidc_user?(_), do: false
end
