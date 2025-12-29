defmodule WeaviateEx.API.Users do
  @moduledoc """
  User management operations.

  This module provides API operations for managing users in Weaviate.
  Users can be database-managed (DB users) or OIDC-managed.

  ## Examples

      alias WeaviateEx.API.Users

      # Create a new DB user (returns API key)
      {:ok, user} = Users.create(client, "new-user-id")
      IO.puts("API Key: \#{user.api_key}")

      # Get current user info
      {:ok, me} = Users.get_my_user(client)

      # Assign roles to user
      :ok = Users.assign_roles(client, "user-id", ["admin", "reader"])

      # Deactivate user
      :ok = Users.deactivate(client, "user-id")

      # Rotate API key
      {:ok, new_key} = Users.rotate_key(client, "user-id")
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.Users.User

  @type opts :: keyword()

  @doc """
  Create a new DB user.

  Returns the created user with their generated API key.

  ## Examples

      {:ok, user} = Users.create(client, "john.doe")
      IO.puts("API Key: \#{user.api_key}")
  """
  @spec create(Client.t(), String.t(), opts()) :: {:ok, User.DB.t()} | {:error, Error.t()}
  def create(client, user_id, opts \\ []) do
    body = %{"userId" => user_id}

    case Client.request(client, :post, "/v1/users", body, opts) do
      {:ok, user_data} ->
        User.from_api(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get a user by ID.

  Returns either a DB user or OIDC user depending on the user type.

  ## Examples

      {:ok, user} = Users.get(client, "john.doe")
  """
  @spec get(Client.t(), String.t(), opts()) ::
          {:ok, User.DB.t() | User.OIDC.t()} | {:error, Error.t()}
  def get(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, user_data} ->
        User.from_api(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get the current authenticated user.

  ## Examples

      {:ok, me} = Users.get_my_user(client)
  """
  @spec get_my_user(Client.t(), opts()) :: {:ok, User.Own.t()} | {:error, Error.t()}
  def get_my_user(client, opts \\ []) do
    case Client.request(client, :get, "/v1/users/own", nil, opts) do
      {:ok, user_data} ->
        User.from_api_own(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  List all users.

  Returns both DB users and OIDC users.

  ## Examples

      {:ok, users} = Users.list_all(client)
  """
  @spec list_all(Client.t(), opts()) ::
          {:ok, [User.DB.t() | User.OIDC.t()]} | {:error, Error.t()}
  def list_all(client, opts \\ []) do
    case Client.request(client, :get, "/v1/users", nil, opts) do
      {:ok, users_data} when is_list(users_data) ->
        decode_users(users_data)

      {:error, error} ->
        {:error, error}
    end
  end

  defp decode_users(users_data) do
    users =
      Enum.map(users_data, fn user_data ->
        {:ok, user} = User.from_api(user_data)
        user
      end)

    {:ok, users}
  end

  @doc """
  Delete a user.

  ## Examples

      :ok = Users.delete(client, "john.doe")
  """
  @spec delete(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def delete(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}"

    case Client.request(client, :delete, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Activate a user.

  ## Examples

      :ok = Users.activate(client, "john.doe")
  """
  @spec activate(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def activate(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/activate"

    case Client.request(client, :post, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Deactivate a user.

  ## Examples

      :ok = Users.deactivate(client, "john.doe")
  """
  @spec deactivate(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def deactivate(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/deactivate"

    case Client.request(client, :post, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Rotate a user's API key.

  Returns the new API key. Only works for DB users.

  ## Examples

      {:ok, new_key} = Users.rotate_key(client, "john.doe")
  """
  @spec rotate_key(Client.t(), String.t(), opts()) :: {:ok, String.t()} | {:error, Error.t()}
  def rotate_key(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/rotate-key"

    case Client.request(client, :post, path, nil, opts) do
      {:ok, %{"apiKey" => key}} -> {:ok, key}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Assign roles to a user.

  ## Examples

      :ok = Users.assign_roles(client, "john.doe", ["admin", "editor"])
  """
  @spec assign_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def assign_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/assign-roles"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Revoke roles from a user.

  ## Examples

      :ok = Users.revoke_roles(client, "john.doe", ["admin"])
  """
  @spec revoke_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def revoke_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/revoke-roles"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get roles assigned to a user.

  ## Examples

      {:ok, roles} = Users.get_assigned_roles(client, "john.doe")
  """
  @spec get_assigned_roles(Client.t(), String.t(), opts()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def get_assigned_roles(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/roles"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, roles} when is_list(roles) -> {:ok, roles}
      {:error, error} -> {:error, error}
    end
  end
end
