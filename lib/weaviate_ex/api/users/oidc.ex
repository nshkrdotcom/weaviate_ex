defmodule WeaviateEx.API.Users.OIDC do
  @moduledoc """
  OIDC-backed user management.

  This module manages users that are authenticated via OIDC (OpenID Connect).
  OIDC users are created and managed by the external identity provider,
  so this module only provides operations for:

  - Getting user information
  - Listing known OIDC users
  - Assigning/revoking roles

  Note: OIDC users cannot be created or deleted via this API - they are
  provisioned by the identity provider.

  ## Examples

      alias WeaviateEx.API.Users.OIDC

      # Get an OIDC user
      {:ok, user} = OIDC.get(client, "user@example.com")
      IO.puts("Groups: \#{inspect(user.groups)}")

      # List all OIDC users
      {:ok, users} = OIDC.list(client)

      # Assign roles
      :ok = OIDC.assign_roles(client, "user@example.com", ["viewer"])
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.Users.User

  @type opts :: keyword()

  @doc """
  Gets an OIDC user by ID.

  ## Examples

      {:ok, user} = OIDC.get(client, "user@example.com")
  """
  @spec get(Client.t(), String.t(), opts()) :: {:ok, User.OIDC.t()} | {:error, Error.t()}
  def get(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}?user_type=oidc"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, user_data} ->
        User.from_api(user_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Lists all known OIDC users.

  Returns users that have authenticated at least once or had roles assigned.

  ## Examples

      {:ok, users} = OIDC.list(client)
  """
  @spec list(Client.t(), opts()) :: {:ok, [User.OIDC.t()]} | {:error, Error.t()}
  def list(client, opts \\ []) do
    case Client.request(client, :get, "/v1/users?user_type=oidc", nil, opts) do
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
  Assigns roles to an OIDC user.

  ## Examples

      :ok = OIDC.assign_roles(client, "user@example.com", ["editor", "viewer"])
  """
  @spec assign_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def assign_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/assign-roles?user_type=oidc"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Revokes roles from an OIDC user.

  ## Examples

      :ok = OIDC.revoke_roles(client, "user@example.com", ["editor"])
  """
  @spec revoke_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def revoke_roles(client, user_id, role_names, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/revoke-roles?user_type=oidc"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Gets roles assigned to an OIDC user.

  ## Examples

      {:ok, roles} = OIDC.get_roles(client, "user@example.com")
  """
  @spec get_roles(Client.t(), String.t(), opts()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def get_roles(client, user_id, opts \\ []) do
    path = "/v1/users/#{URI.encode_www_form(user_id)}/roles?user_type=oidc"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, roles} when is_list(roles) -> {:ok, roles}
      {:error, error} -> {:error, error}
    end
  end
end
