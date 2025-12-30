defmodule WeaviateEx.API.Users.DB do
  @moduledoc """
  Database-backed user management.

  This module manages users that are stored in Weaviate's database,
  as opposed to OIDC users which are managed by an external identity provider.

  DB users:
  - Have API keys for authentication
  - Can be created and deleted via this API
  - Can have their API keys rotated
  - Can be activated/deactivated

  ## Examples

      alias WeaviateEx.API.Users.DB

      # Create a new DB user
      {:ok, user} = DB.create(client, "new-user")
      IO.puts("API Key: \#{user.api_key}")

      # Rotate API key
      {:ok, new_key} = DB.rotate_api_key(client, "new-user")

      # Assign roles
      :ok = DB.assign_roles(client, "new-user", ["editor", "viewer"])

      # Delete user
      :ok = DB.delete(client, "new-user")
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.Users.User

  @type opts :: keyword()

  @doc """
  Creates a new database user.

  Returns the user with their generated API key.

  ## Examples

      {:ok, user} = DB.create(client, "john.doe")
      IO.puts("API Key: \#{user.api_key}")
  """
  @spec create(Client.t(), String.t(), opts()) :: {:ok, User.DB.t()} | {:error, Error.t()}
  def create(client, user_id, opts \\ []) do
    body = %{"userId" => user_id, "userType" => "db"}

    case Client.request(client, :post, "/v1/users", body, opts) do
      {:ok, user_data} ->
        User.from_api(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets a database user by ID.

  ## Examples

      {:ok, user} = DB.get(client, "john.doe")
  """
  @spec get(Client.t(), String.t(), opts()) :: {:ok, User.DB.t()} | {:error, Error.t()}
  def get(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}?user_type=db"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, user_data} ->
        User.from_api(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Lists all database users.

  ## Examples

      {:ok, users} = DB.list(client)
  """
  @spec list(Client.t(), opts()) :: {:ok, [User.DB.t()]} | {:error, Error.t()}
  def list(client, opts \\ []) do
    case Client.request(client, :get, "/v1/users?user_type=db", nil, opts) do
      {:ok, users_data} when is_list(users_data) ->
        users =
          Enum.map(users_data, fn user_data ->
            {:ok, user} = User.from_api(user_data)
            user
          end)

        {:ok, users}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Deletes a database user.

  ## Examples

      :ok = DB.delete(client, "john.doe")
  """
  @spec delete(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def delete(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}?user_type=db"

    case Client.request(client, :delete, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Rotates a user's API key.

  Returns the new API key.

  ## Examples

      {:ok, new_key} = DB.rotate_api_key(client, "john.doe")
  """
  @spec rotate_api_key(Client.t(), String.t(), opts()) :: {:ok, String.t()} | {:error, Error.t()}
  def rotate_api_key(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/rotate-key?user_type=db"

    case Client.request(client, :post, path, nil, opts) do
      {:ok, %{"apiKey" => key}} -> {:ok, key}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Assigns roles to a user.

  ## Examples

      :ok = DB.assign_roles(client, "john.doe", ["admin", "editor"])
  """
  @spec assign_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def assign_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/assign-roles?user_type=db"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Revokes roles from a user.

  ## Examples

      :ok = DB.revoke_roles(client, "john.doe", ["admin"])
  """
  @spec revoke_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def revoke_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/revoke-roles?user_type=db"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Gets roles assigned to a user.

  ## Options

  - `:include_permissions` - If true, returns a map of role names to Role structs
    with full permission details instead of just role names (default: false)

  ## Examples

      # Get role names only
      {:ok, ["admin", "editor"]} = DB.get_roles(client, "john.doe")

      # Get roles with full permission details
      {:ok, %{"admin" => %Role{...}}} = DB.get_roles(client, "john.doe", include_permissions: true)
  """
  @spec get_roles(Client.t(), String.t(), opts()) ::
          {:ok, [String.t()] | map()} | {:error, Error.t()}
  def get_roles(client, user_id, opts \\ []) do
    include_permissions = Keyword.get(opts, :include_permissions, false)
    query = if include_permissions, do: "&include_permissions=true", else: ""
    path = "/v1/users/#{URI.encode_www_form(user_id)}/roles?user_type=db#{query}"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, roles} when is_list(roles) and not include_permissions ->
        {:ok, roles}

      {:ok, roles} when is_map(roles) and include_permissions ->
        {:ok, roles}

      {:ok, roles} when is_list(roles) and include_permissions ->
        # Server may return list even with include_permissions
        {:ok, roles}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Activates a user.

  ## Examples

      :ok = DB.activate(client, "john.doe")
  """
  @spec activate(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def activate(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/activate?user_type=db"

    case Client.request(client, :post, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Deactivates a user.

  ## Options

  - `:revoke_key` - If true, also revokes the user's API key (default: false)

  ## Examples

      # Deactivate user, keeping API key
      :ok = DB.deactivate(client, "john.doe")

      # Deactivate user and revoke their API key
      :ok = DB.deactivate(client, "john.doe", revoke_key: true)
  """
  @spec deactivate(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def deactivate(client, user_id, opts \\ []) do
    revoke_key = Keyword.get(opts, :revoke_key, false)
    path = "/v1/users/#{URI.encode_www_form(user_id)}/deactivate?user_type=db"
    body = if revoke_key, do: %{"revokeKey" => true}, else: nil

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
