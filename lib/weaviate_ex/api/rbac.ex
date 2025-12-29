defmodule WeaviateEx.API.RBAC do
  @moduledoc """
  Role-Based Access Control operations.

  This module provides API operations for managing roles and permissions in Weaviate's
  RBAC system. Use this module to create, modify, and query roles.

  ## Examples

      alias WeaviateEx.API.RBAC
      alias WeaviateEx.RBAC.Permissions

      # Create a role with permissions
      permissions = [
        Permissions.collections("Article", [:read]),
        Permissions.data("Article", [:read, :create])
      ]
      {:ok, role} = RBAC.create_role(client, "article-reader", permissions)

      # List all roles
      {:ok, roles} = RBAC.list_roles(client)

      # Check if role has permission
      permission = Permissions.data("Article", :read)
      {:ok, true} = RBAC.has_permissions?(client, "article-reader", [permission])

      # Delete role
      :ok = RBAC.delete_role(client, "article-reader")
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.RBAC.{Permission, Permissions, Role}

  @type opts :: keyword()

  @doc """
  List all roles.

  ## Examples

      {:ok, roles} = RBAC.list_roles(client)
  """
  @spec list_roles(Client.t(), opts()) :: {:ok, [Role.t()]} | {:error, Error.t()}
  def list_roles(client, opts \\ []) do
    case Client.request(client, :get, "/v1/authz/roles", nil, opts) do
      {:ok, roles_data} when is_list(roles_data) ->
        decode_roles(roles_data)

      {:error, error} ->
        {:error, error}
    end
  end

  defp decode_roles(roles_data) do
    results =
      Enum.reduce_while(roles_data, {:ok, []}, fn role_data, {:ok, acc} ->
        case Role.from_api(role_data) do
          {:ok, role} -> {:cont, {:ok, [role | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case results do
      {:ok, roles} -> {:ok, Enum.reverse(roles)}
      error -> error
    end
  end

  @doc """
  Check if a role exists.

  ## Examples

      {:ok, true} = RBAC.exists?(client, "admin")
      {:ok, false} = RBAC.exists?(client, "nonexistent")
  """
  @spec exists?(Client.t(), String.t(), opts()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(client, role_name, opts \\ []) do
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get a role by name.

  ## Examples

      {:ok, role} = RBAC.get_role(client, "editor")
  """
  @spec get_role(Client.t(), String.t(), opts()) :: {:ok, Role.t()} | {:error, Error.t()}
  def get_role(client, role_name, opts \\ []) do
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, role_data} ->
        Role.from_api(role_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Create a role with permissions.

  ## Parameters

    * `client` - WeaviateEx client
    * `role_name` - Name for the new role
    * `permissions` - List of permissions (or nested lists that will be flattened)

  ## Examples

      permissions = [
        Permissions.collections("Article", :read),
        Permissions.data("Article", [:create, :read])
      ]
      {:ok, role} = RBAC.create_role(client, "article-editor", permissions)
  """
  @spec create_role(Client.t(), String.t(), [Permission.t()] | Permission.t(), opts()) ::
          {:ok, Role.t()} | {:error, Error.t()}
  def create_role(client, role_name, permissions, opts \\ []) do
    role = Role.new(role_name, permissions)
    body = Role.to_api(role)

    case Client.request(client, :post, "/v1/authz/roles", body, opts) do
      {:ok, role_data} ->
        Role.from_api(role_data)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Delete a role.

  ## Examples

      :ok = RBAC.delete_role(client, "old-role")
  """
  @spec delete_role(Client.t(), String.t(), opts()) :: :ok | {:error, Error.t()}
  def delete_role(client, role_name, opts \\ []) do
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}"

    case Client.request(client, :delete, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Add permissions to an existing role.

  ## Examples

      permissions = [Permissions.data("Product", :read)]
      :ok = RBAC.add_permissions(client, "editor", permissions)
  """
  @spec add_permissions(Client.t(), String.t(), [Permission.t()] | Permission.t(), opts()) ::
          :ok | {:error, Error.t()}
  def add_permissions(client, role_name, permissions, opts \\ []) do
    flat_permissions = Permissions.flatten(permissions)
    body = %{"permissions" => Enum.map(flat_permissions, &Permission.to_api/1)}
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/add-permissions"

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Remove permissions from a role.

  ## Examples

      permissions = [Permissions.data("Product", :delete)]
      :ok = RBAC.remove_permissions(client, "editor", permissions)
  """
  @spec remove_permissions(Client.t(), String.t(), [Permission.t()] | Permission.t(), opts()) ::
          :ok | {:error, Error.t()}
  def remove_permissions(client, role_name, permissions, opts \\ []) do
    flat_permissions = Permissions.flatten(permissions)
    body = %{"permissions" => Enum.map(flat_permissions, &Permission.to_api/1)}
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/remove-permissions"

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Check if a role has specific permissions.

  ## Examples

      permissions = [Permissions.data("Article", :read)]
      {:ok, true} = RBAC.has_permissions?(client, "reader", permissions)
  """
  @spec has_permissions?(Client.t(), String.t(), [Permission.t()] | Permission.t(), opts()) ::
          {:ok, boolean()} | {:error, Error.t()}
  def has_permissions?(client, role_name, permissions, opts \\ []) do
    flat_permissions = Permissions.flatten(permissions)
    body = %{"permissions" => Enum.map(flat_permissions, &Permission.to_api/1)}
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/has-permissions"

    case Client.request(client, :post, path, body, opts) do
      {:ok, %{"hasPermission" => has}} -> {:ok, has}
      {:ok, _} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get users assigned to a role.

  ## Examples

      {:ok, users} = RBAC.get_users_for_role(client, "editor")
  """
  @spec get_users_for_role(Client.t(), String.t(), opts()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def get_users_for_role(client, role_name, opts \\ []) do
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/users"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, users} when is_list(users) -> {:ok, users}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get groups assigned to a role.

  ## Examples

      {:ok, groups} = RBAC.get_groups_for_role(client, "editor")
  """
  @spec get_groups_for_role(Client.t(), String.t(), opts()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def get_groups_for_role(client, role_name, opts \\ []) do
    path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/groups"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, groups} when is_list(groups) -> {:ok, groups}
      {:error, error} -> {:error, error}
    end
  end
end
