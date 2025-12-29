# Gap Analysis: RBAC and Multi-Tenancy

## Executive Summary

This document analyzes the gap between the Python Weaviate client and the Elixir WeaviateEx client for Role-Based Access Control (RBAC) and Multi-Tenancy features.

### Critical Findings

| Area | Python Client | Elixir Client | Gap Level |
|------|--------------|---------------|-----------|
| **RBAC - Roles Management** | Full implementation | **Missing entirely** | **CRITICAL** |
| **RBAC - Users Management** | Full implementation (DB/OIDC) | **Missing entirely** | **CRITICAL** |
| **RBAC - Permissions** | Comprehensive permission system | **Missing entirely** | **CRITICAL** |
| **Multi-Tenancy - Core CRUD** | Complete | Complete | None |
| **Multi-Tenancy - Activity Status** | ACTIVE/INACTIVE/OFFLOADED + transitions | HOT/COLD/FROZEN (legacy naming) | Low |
| **Multi-Tenancy - Offload** | Yes | **Missing** | High |
| **Multi-Tenancy - Get By Name(s)** | gRPC + REST fallback | **Missing** | Medium |
| **Multi-Tenancy - Collection Config** | Full auto-tenant options | Basic only | Medium |

### Priority Summary

- **Critical (5 items)**: Full RBAC module missing - Roles, Users (DB + OIDC), Permissions, Groups
- **High (3 items)**: Tenant offload, role/user assignment, permission validation
- **Medium (4 items)**: Get tenant by name, auto-tenant config, tenant activity transitions
- **Low (2 items)**: Naming convention updates (HOT->ACTIVE, COLD->INACTIVE, FROZEN->OFFLOADED)

---

## Detailed Comparison

### 1. RBAC - Role Management

#### Python Client Features

| Feature | Python Method | Elixir Status |
|---------|--------------|---------------|
| List all roles | `client.roles.list_all()` | **MISSING** |
| Get role by name | `client.roles.get(role_name)` | **MISSING** |
| Check role exists | `client.roles.exists(role_name)` | **MISSING** |
| Create role | `client.roles.create(role_name, permissions)` | **MISSING** |
| Delete role | `client.roles.delete(role_name)` | **MISSING** |
| Add permissions to role | `client.roles.add_permissions(role_name, permissions)` | **MISSING** |
| Remove permissions from role | `client.roles.remove_permissions(role_name, permissions)` | **MISSING** |
| Check role has permission | `client.roles.has_permissions(role, permissions)` | **MISSING** |
| Get user assignments for role | `client.roles.get_user_assignments(role_name)` | **MISSING** |
| Get group assignments for role | `client.roles.get_group_assignments(role_name)` | **MISSING** |
| Get current user's roles | `client.users.get_my_user()` | **MISSING** |

#### Python Code Example - Role Creation

```python
from weaviate.classes.rbac import Permissions, Actions

# Create a role with specific permissions
client.roles.create(
    role_name="article_editor",
    permissions=[
        Permissions.data(
            collection="Article",
            create=True, read=True, update=True, delete=False
        ),
        Permissions.collections(
            collection="Article",
            read_config=True
        ),
        Permissions.tenants(
            collection="Article",
            tenant="*",  # All tenants
            read=True, update=True
        )
    ]
)

# Get all roles
roles = client.roles.list_all()

# Check if role exists
exists = client.roles.exists("article_editor")

# Add more permissions
client.roles.add_permissions(
    role_name="article_editor",
    permissions=Permissions.backup(collection="Article", manage=True)
)

# Remove permissions
client.roles.remove_permissions(
    role_name="article_editor",
    permissions=Permissions.backup(collection="Article", manage=True)
)
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.API.Roles do
  @moduledoc """
  RBAC Role management operations.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.RBAC.Permissions

  @type role_name :: String.t()
  @type permission :: map()

  @doc """
  List all roles in the system.

  ## Examples

      {:ok, roles} = Roles.list(client)
      # => %{"admin" => %{name: "admin", permissions: [...]}, ...}
  """
  @spec list(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(client) do
    Client.request(client, :get, "/v1/authz/roles", nil, [])
  end

  @doc """
  Get a specific role by name.

  ## Examples

      {:ok, role} = Roles.get(client, "article_editor")
  """
  @spec get(Client.t(), role_name()) :: {:ok, map() | nil} | {:error, Error.t()}
  def get(client, role_name) do
    case Client.request(client, :get, "/v1/authz/roles/#{role_name}", nil, []) do
      {:ok, role} -> {:ok, role}
      {:error, %Error{type: :not_found}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Check if a role exists.

  ## Examples

      {:ok, true} = Roles.exists?(client, "article_editor")
  """
  @spec exists?(Client.t(), role_name()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(client, role_name) do
    case get(client, role_name) do
      {:ok, nil} -> {:ok, false}
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  @doc """
  Create a new role with permissions.

  ## Examples

      permissions = [
        Permissions.data("Article", create: true, read: true),
        Permissions.collections("Article", read_config: true)
      ]
      {:ok, role} = Roles.create(client, "article_editor", permissions)
  """
  @spec create(Client.t(), role_name(), [permission()]) :: {:ok, map()} | {:error, Error.t()}
  def create(client, role_name, permissions) do
    body = %{
      "name" => role_name,
      "permissions" => Enum.flat_map(permissions, &Permissions.to_weaviate/1)
    }
    Client.request(client, :post, "/v1/authz/roles", body, [])
  end

  @doc """
  Delete a role.

  ## Examples

      {:ok, _} = Roles.delete(client, "article_editor")
  """
  @spec delete(Client.t(), role_name()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, role_name) do
    Client.request(client, :delete, "/v1/authz/roles/#{role_name}", nil, [])
  end

  @doc """
  Add permissions to an existing role.

  ## Examples

      permissions = [Permissions.backup("Article", manage: true)]
      {:ok, _} = Roles.add_permissions(client, "article_editor", permissions)
  """
  @spec add_permissions(Client.t(), role_name(), [permission()]) :: {:ok, map()} | {:error, Error.t()}
  def add_permissions(client, role_name, permissions) do
    body = %{
      "permissions" => Enum.flat_map(permissions, &Permissions.to_weaviate/1)
    }
    Client.request(client, :post, "/v1/authz/roles/#{role_name}/add-permissions", body, [])
  end

  @doc """
  Remove permissions from a role.
  """
  @spec remove_permissions(Client.t(), role_name(), [permission()]) :: {:ok, map()} | {:error, Error.t()}
  def remove_permissions(client, role_name, permissions) do
    body = %{
      "permissions" => Enum.flat_map(permissions, &Permissions.to_weaviate/1)
    }
    Client.request(client, :post, "/v1/authz/roles/#{role_name}/remove-permissions", body, [])
  end

  @doc """
  Check if a role has specific permissions.

  ## Examples

      {:ok, true} = Roles.has_permissions?(client, "article_editor", permissions)
  """
  @spec has_permissions?(Client.t(), role_name(), [permission()]) :: {:ok, boolean()} | {:error, Error.t()}
  def has_permissions?(client, role_name, permissions) do
    permissions
    |> Enum.flat_map(&Permissions.to_weaviate/1)
    |> Enum.reduce_while({:ok, true}, fn perm, _acc ->
      case Client.request(client, :post, "/v1/authz/roles/#{role_name}/has-permission", perm, []) do
        {:ok, _} -> {:cont, {:ok, true}}
        {:error, %Error{type: :not_found}} -> {:halt, {:ok, false}}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Get users assigned to a role.
  """
  @spec get_user_assignments(Client.t(), role_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def get_user_assignments(client, role_name) do
    Client.request(client, :get, "/v1/authz/roles/#{role_name}/user-assignments", nil, [])
  end

  @doc """
  Get groups assigned to a role.
  """
  @spec get_group_assignments(Client.t(), role_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def get_group_assignments(client, role_name) do
    Client.request(client, :get, "/v1/authz/roles/#{role_name}/group-assignments", nil, [])
  end
end
```

---

### 2. RBAC - Permission Types

#### Python Permission System

The Python client has a comprehensive permission system with these action types:

| Permission Type | Actions Available | Elixir Status |
|-----------------|-------------------|---------------|
| **Data** | create, read, update, delete, manage | **MISSING** |
| **Collections** | create, read, update, delete, manage | **MISSING** |
| **Tenants** | create, read, update, delete | **MISSING** |
| **Roles** | create, read, update, delete, manage | **MISSING** |
| **Users** | create, read, update, delete, assign_and_revoke | **MISSING** |
| **Groups** | read, assign_and_revoke | **MISSING** |
| **Nodes** | read (verbose/minimal) | **MISSING** |
| **Backups** | manage | **MISSING** |
| **Cluster** | read | **MISSING** |
| **Alias** | create, read, update, delete | **MISSING** |
| **Replicate** | create, read, update, delete | **MISSING** |

#### Python Code Example - Permissions

```python
from weaviate.classes.rbac import Permissions, Actions, RoleScope

# Data permissions with tenant scope
data_perms = Permissions.data(
    collection=["Article", "Author"],
    tenant=["tenant1", "tenant2"],
    create=True,
    read=True,
    update=True,
    delete=False
)

# Collection permissions
collection_perms = Permissions.collections(
    collection="Article",
    create_collection=True,
    read_config=True,
    update_config=True,
    delete_collection=False
)

# Tenant permissions
tenant_perms = Permissions.tenants(
    collection="Article",
    tenant="*",  # All tenants
    create=True,
    read=True,
    update=True,
    delete=True
)

# Role permissions with scope
role_perms = Permissions.roles(
    role="*",
    read=True,
    scope=RoleScope.ALL
)

# User permissions
user_perms = Permissions.users(
    user="*",
    create=True,
    read=True,
    assign_and_revoke=True
)

# Node permissions
node_perms_verbose = Permissions.Nodes.verbose(
    collection="Article",
    read=True
)
node_perms_minimal = Permissions.Nodes.minimal(read=True)

# Backup permissions
backup_perms = Permissions.backup(
    collection="Article",
    manage=True
)

# Cluster permissions
cluster_perms = Permissions.cluster(read=True)

# Alias permissions
alias_perms = Permissions.alias(
    alias="ArticleAlias",
    collection="Article",
    create=True,
    read=True,
    update=True,
    delete=True
)
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.RBAC.Permissions do
  @moduledoc """
  Permission builders for RBAC.

  Provides functions to create permission objects compatible with
  Weaviate's RBAC API.
  """

  @type collection :: String.t() | [String.t()]
  @type tenant :: String.t() | [String.t()] | nil
  @type opts :: keyword()
  @type permission :: map()

  # Permission Action Atoms
  @data_actions [:create, :read, :update, :delete, :manage]
  @collection_actions [:create_collection, :read_config, :update_config, :delete_collection]
  @tenant_actions [:create, :read, :update, :delete]
  @role_actions [:create, :read, :update, :delete]
  @user_actions [:create, :read, :update, :delete, :assign_and_revoke]
  @group_actions [:read, :assign_and_revoke]

  @doc """
  Create data permissions.

  ## Options
    * `:create` - Allow creating data
    * `:read` - Allow reading data
    * `:update` - Allow updating data
    * `:delete` - Allow deleting data
    * `:manage` - Full data management

  ## Examples

      perm = Permissions.data("Article", tenant: "tenant1", create: true, read: true)
  """
  @spec data(collection(), opts()) :: [permission()]
  def data(collection, opts \\ []) do
    collections = List.wrap(collection)
    tenants = opts |> Keyword.get(:tenant) |> List.wrap() |> default_if_empty(["*"])
    actions = build_actions(opts, @data_actions, "data")

    for c <- collections, t <- tenants, action <- actions do
      %{
        "action" => action,
        "data" => %{
          "collection" => capitalize_first(c),
          "tenant" => t
        }
      }
    end
  end

  @doc """
  Create collection permissions.

  ## Options
    * `:create_collection` - Allow creating collections
    * `:read_config` - Allow reading collection config
    * `:update_config` - Allow updating collection config
    * `:delete_collection` - Allow deleting collections
  """
  @spec collections(collection(), opts()) :: [permission()]
  def collections(collection, opts \\ []) do
    collections = List.wrap(collection)
    action_map = %{
      create_collection: "create_collections",
      read_config: "read_collections",
      update_config: "update_collections",
      delete_collection: "delete_collections"
    }
    actions = build_actions_with_map(opts, action_map)

    for c <- collections, action <- actions do
      %{
        "action" => action,
        "collections" => %{"collection" => capitalize_first(c)}
      }
    end
  end

  @doc """
  Create tenant permissions.

  ## Options
    * `:create` - Allow creating tenants
    * `:read` - Allow reading tenants
    * `:update` - Allow updating tenants
    * `:delete` - Allow deleting tenants
  """
  @spec tenants(collection(), opts()) :: [permission()]
  def tenants(collection, opts \\ []) do
    collections = List.wrap(collection)
    tenants = opts |> Keyword.get(:tenant) |> List.wrap() |> default_if_empty(["*"])
    actions = build_actions(opts, @tenant_actions, "tenants")

    for c <- collections, t <- tenants, action <- actions do
      %{
        "action" => action,
        "tenants" => %{
          "collection" => capitalize_first(c),
          "tenant" => t
        }
      }
    end
  end

  @doc """
  Create role permissions.

  ## Options
    * `:create` - Allow creating roles
    * `:read` - Allow reading roles
    * `:update` - Allow updating roles
    * `:delete` - Allow deleting roles
    * `:scope` - Scope for the permission (:match | :all)
  """
  @spec roles(String.t() | [String.t()], opts()) :: [permission()]
  def roles(role, opts \\ []) do
    roles_list = List.wrap(role)
    actions = build_actions(opts, @role_actions, "roles")
    scope = Keyword.get(opts, :scope)

    for r <- roles_list, action <- actions do
      base = %{
        "action" => action,
        "roles" => %{"role" => r}
      }
      if scope, do: put_in(base, ["roles", "scope"], to_string(scope)), else: base
    end
  end

  @doc """
  Create user permissions.

  ## Options
    * `:create` - Allow creating users
    * `:read` - Allow reading users
    * `:update` - Allow updating users
    * `:delete` - Allow deleting users
    * `:assign_and_revoke` - Allow assigning/revoking roles
  """
  @spec users(String.t() | [String.t()], opts()) :: [permission()]
  def users(user, opts \\ []) do
    users_list = List.wrap(user)
    action_map = %{
      create: "create_users",
      read: "read_users",
      update: "update_users",
      delete: "delete_users",
      assign_and_revoke: "assign_and_revoke_users"
    }
    actions = build_actions_with_map(opts, action_map)

    for u <- users_list, action <- actions do
      %{"action" => action, "users" => %{"users" => u}}
    end
  end

  @doc """
  Create backup permissions.
  """
  @spec backup(collection(), opts()) :: [permission()]
  def backup(collection, opts \\ []) do
    collections = List.wrap(collection)
    actions = if Keyword.get(opts, :manage, false), do: ["manage_backups"], else: []

    for c <- collections, action <- actions do
      %{
        "action" => action,
        "backups" => %{"collection" => capitalize_first(c)}
      }
    end
  end

  @doc """
  Create cluster permissions.
  """
  @spec cluster(opts()) :: [permission()]
  def cluster(opts \\ []) do
    if Keyword.get(opts, :read, false) do
      [%{"action" => "read_cluster"}]
    else
      []
    end
  end

  @doc """
  Create node permissions with verbose output.
  """
  @spec nodes_verbose(collection(), opts()) :: [permission()]
  def nodes_verbose(collection, opts \\ []) do
    collections = List.wrap(collection)
    if Keyword.get(opts, :read, false) do
      for c <- collections do
        %{
          "action" => "read_nodes",
          "nodes" => %{
            "collection" => capitalize_first(c),
            "verbosity" => "verbose"
          }
        }
      end
    else
      []
    end
  end

  @doc """
  Create node permissions with minimal output.
  """
  @spec nodes_minimal(opts()) :: [permission()]
  def nodes_minimal(opts \\ []) do
    if Keyword.get(opts, :read, false) do
      [%{
        "action" => "read_nodes",
        "nodes" => %{
          "collection" => "*",
          "verbosity" => "minimal"
        }
      }]
    else
      []
    end
  end

  @doc """
  Convert permission struct to Weaviate API format.
  """
  @spec to_weaviate([permission()] | permission()) :: [map()]
  def to_weaviate(permissions) when is_list(permissions), do: List.flatten(permissions)
  def to_weaviate(permission) when is_map(permission), do: [permission]

  # Private helpers
  defp build_actions(opts, allowed, prefix) do
    allowed
    |> Enum.filter(&Keyword.get(opts, &1, false))
    |> Enum.map(&"#{&1}_#{prefix}")
  end

  defp build_actions_with_map(opts, action_map) do
    action_map
    |> Enum.filter(fn {key, _} -> Keyword.get(opts, key, false) end)
    |> Enum.map(fn {_, action} -> action end)
  end

  defp capitalize_first(<<first::utf8, rest::binary>>), do: <<String.upcase(<<first>>)::binary, rest::binary>>
  defp capitalize_first(str), do: str

  defp default_if_empty([], default), do: default
  defp default_if_empty(list, _), do: list
end
```

---

### 3. RBAC - User Management

#### Python Client Features

| Feature | Python Method | Elixir Status |
|---------|--------------|---------------|
| Get current user | `client.users.get_my_user()` | **MISSING** |
| **DB Users** | | |
| Create DB user | `client.users.db.create(user_id)` | **MISSING** |
| Delete DB user | `client.users.db.delete(user_id)` | **MISSING** |
| Get DB user | `client.users.db.get(user_id)` | **MISSING** |
| List all DB users | `client.users.db.list_all()` | **MISSING** |
| Activate DB user | `client.users.db.activate(user_id)` | **MISSING** |
| Deactivate DB user | `client.users.db.deactivate(user_id)` | **MISSING** |
| Rotate DB user key | `client.users.db.rotate_key(user_id)` | **MISSING** |
| Assign roles to DB user | `client.users.db.assign_roles(user_id, roles)` | **MISSING** |
| Revoke roles from DB user | `client.users.db.revoke_roles(user_id, roles)` | **MISSING** |
| Get DB user roles | `client.users.db.get_assigned_roles(user_id)` | **MISSING** |
| **OIDC Users** | | |
| Assign roles to OIDC user | `client.users.oidc.assign_roles(user_id, roles)` | **MISSING** |
| Revoke roles from OIDC user | `client.users.oidc.revoke_roles(user_id, roles)` | **MISSING** |
| Get OIDC user roles | `client.users.oidc.get_assigned_roles(user_id)` | **MISSING** |

#### Python Code Example - User Management

```python
# Get current authenticated user
my_user = client.users.get_my_user()
print(f"User: {my_user.user_id}, Roles: {my_user.roles}")

# DB User Management
# Create a new DB user (returns API key)
api_key = client.users.db.create(user_id="new_user")
print(f"New user API key: {api_key}")

# List all DB users
all_users = client.users.db.list_all()
for user in all_users:
    print(f"User: {user.user_id}, Active: {user.active}, Roles: {user.role_names}")

# Get specific user
user = client.users.db.get(user_id="new_user")

# Assign roles to user
client.users.db.assign_roles(user_id="new_user", role_names=["article_editor", "viewer"])

# Get assigned roles
roles = client.users.db.get_assigned_roles(user_id="new_user", include_permissions=True)

# Revoke roles
client.users.db.revoke_roles(user_id="new_user", role_names=["viewer"])

# Deactivate user (optionally revoke key)
client.users.db.deactivate(user_id="new_user", revoke_key=True)

# Activate user
client.users.db.activate(user_id="new_user")

# Rotate API key
new_key = client.users.db.rotate_key(user_id="new_user")

# Delete user
client.users.db.delete(user_id="new_user")

# OIDC User Management
client.users.oidc.assign_roles(user_id="oidc_user@domain.com", role_names=["viewer"])
client.users.oidc.revoke_roles(user_id="oidc_user@domain.com", role_names=["viewer"])
roles = client.users.oidc.get_assigned_roles(user_id="oidc_user@domain.com")
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.API.Users do
  @moduledoc """
  User management for RBAC.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type user_id :: String.t()
  @type role_names :: String.t() | [String.t()]

  @doc """
  Get the currently authenticated user.

  ## Examples

      {:ok, user} = Users.get_my_user(client)
      # => %{user_id: "admin", roles: %{...}, groups: [...]}
  """
  @spec get_my_user(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_my_user(client) do
    case Client.request(client, :get, "/v1/users/own-info", nil, []) do
      {:ok, data} ->
        user = %{
          user_id: data["username"] || data["user_id"],
          roles: parse_roles(data["roles"]),
          groups: data["groups"] || []
        }
        {:ok, user}
      error -> error
    end
  end

  defp parse_roles(nil), do: %{}
  defp parse_roles(roles) when is_list(roles) do
    Map.new(roles, fn role -> {role["name"], role} end)
  end
end

defmodule WeaviateEx.API.Users.DB do
  @moduledoc """
  Database user management.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type user_id :: String.t()
  @type role_names :: String.t() | [String.t()]
  @type opts :: keyword()

  @doc """
  Create a new DB user. Returns the API key.

  ## Examples

      {:ok, api_key} = Users.DB.create(client, "new_user")
  """
  @spec create(Client.t(), user_id()) :: {:ok, String.t()} | {:error, Error.t()}
  def create(client, user_id) do
    case Client.request(client, :post, "/v1/users/db/#{URI.encode(user_id)}", %{}, []) do
      {:ok, %{"apikey" => key}} -> {:ok, key}
      error -> error
    end
  end

  @doc """
  Delete a DB user.
  """
  @spec delete(Client.t(), user_id()) :: {:ok, boolean()} | {:error, Error.t()}
  def delete(client, user_id) do
    case Client.request(client, :delete, "/v1/users/db/#{URI.encode(user_id)}", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      error -> error
    end
  end

  @doc """
  Get a specific DB user.
  """
  @spec get(Client.t(), user_id()) :: {:ok, map() | nil} | {:error, Error.t()}
  def get(client, user_id) do
    case Client.request(client, :get, "/v1/users/db/#{URI.encode(user_id)}", nil, []) do
      {:ok, data} ->
        user = %{
          user_id: data["userId"],
          role_names: data["roles"],
          active: data["active"],
          user_type: data["dbUserType"]
        }
        {:ok, user}
      {:error, %Error{type: :not_found}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  List all DB users.
  """
  @spec list_all(Client.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_all(client) do
    case Client.request(client, :get, "/v1/users/db", nil, []) do
      {:ok, users} when is_list(users) ->
        parsed = Enum.map(users, fn u ->
          %{
            user_id: u["userId"],
            role_names: u["roles"],
            active: u["active"],
            user_type: u["dbUserType"]
          }
        end)
        {:ok, parsed}
      error -> error
    end
  end

  @doc """
  Activate a deactivated DB user.
  """
  @spec activate(Client.t(), user_id()) :: {:ok, boolean()} | {:error, Error.t()}
  def activate(client, user_id) do
    case Client.request(client, :post, "/v1/users/db/#{URI.encode(user_id)}/activate", %{}, []) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{status: 409}} -> {:ok, false}  # Already active
      error -> error
    end
  end

  @doc """
  Deactivate a DB user.

  ## Options
    * `:revoke_key` - If true, revokes the API key (default: false)
  """
  @spec deactivate(Client.t(), user_id(), opts()) :: {:ok, boolean()} | {:error, Error.t()}
  def deactivate(client, user_id, opts \\ []) do
    body = %{"revoke_key" => Keyword.get(opts, :revoke_key, false)}
    case Client.request(client, :post, "/v1/users/db/#{URI.encode(user_id)}/deactivate", body, []) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{status: 409}} -> {:ok, false}  # Already inactive
      error -> error
    end
  end

  @doc """
  Rotate the API key for a DB user. Returns the new key.
  """
  @spec rotate_key(Client.t(), user_id()) :: {:ok, String.t()} | {:error, Error.t()}
  def rotate_key(client, user_id) do
    case Client.request(client, :post, "/v1/users/db/#{URI.encode(user_id)}/rotate-key", %{}, []) do
      {:ok, %{"apikey" => key}} -> {:ok, key}
      error -> error
    end
  end

  @doc """
  Assign roles to a DB user.
  """
  @spec assign_roles(Client.t(), user_id(), role_names()) :: {:ok, any()} | {:error, Error.t()}
  def assign_roles(client, user_id, role_names) do
    roles = List.wrap(role_names)
    body = %{"roles" => roles, "userType" => "db"}
    Client.request(client, :post, "/v1/authz/users/#{URI.encode(user_id)}/assign", body, [])
  end

  @doc """
  Revoke roles from a DB user.
  """
  @spec revoke_roles(Client.t(), user_id(), role_names()) :: {:ok, any()} | {:error, Error.t()}
  def revoke_roles(client, user_id, role_names) do
    roles = List.wrap(role_names)
    body = %{"roles" => roles, "userType" => "db"}
    Client.request(client, :post, "/v1/authz/users/#{URI.encode(user_id)}/revoke", body, [])
  end

  @doc """
  Get roles assigned to a DB user.

  ## Options
    * `:include_permissions` - Include full permission details (default: false)
  """
  @spec get_assigned_roles(Client.t(), user_id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get_assigned_roles(client, user_id, opts \\ []) do
    include = Keyword.get(opts, :include_permissions, false)
    path = "/v1/authz/users/#{URI.encode(user_id)}/roles/db?includeFullRoles=#{include}"
    Client.request(client, :get, path, nil, [])
  end
end

defmodule WeaviateEx.API.Users.OIDC do
  @moduledoc """
  OIDC user management.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type user_id :: String.t()
  @type role_names :: String.t() | [String.t()]
  @type opts :: keyword()

  @doc """
  Assign roles to an OIDC user.
  """
  @spec assign_roles(Client.t(), user_id(), role_names()) :: {:ok, any()} | {:error, Error.t()}
  def assign_roles(client, user_id, role_names) do
    roles = List.wrap(role_names)
    body = %{"roles" => roles, "userType" => "oidc"}
    Client.request(client, :post, "/v1/authz/users/#{URI.encode(user_id)}/assign", body, [])
  end

  @doc """
  Revoke roles from an OIDC user.
  """
  @spec revoke_roles(Client.t(), user_id(), role_names()) :: {:ok, any()} | {:error, Error.t()}
  def revoke_roles(client, user_id, role_names) do
    roles = List.wrap(role_names)
    body = %{"roles" => roles, "userType" => "oidc"}
    Client.request(client, :post, "/v1/authz/users/#{URI.encode(user_id)}/revoke", body, [])
  end

  @doc """
  Get roles assigned to an OIDC user.

  ## Options
    * `:include_permissions` - Include full permission details (default: false)
  """
  @spec get_assigned_roles(Client.t(), user_id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get_assigned_roles(client, user_id, opts \\ []) do
    include = Keyword.get(opts, :include_permissions, false)
    path = "/v1/authz/users/#{URI.encode(user_id)}/roles/oidc?includeFullRoles=#{include}"
    Client.request(client, :get, path, nil, [])
  end
end
```

---

### 4. Multi-Tenancy - Current State

#### Existing Elixir Implementation

The Elixir client already has basic multi-tenancy support in `WeaviateEx.API.Tenants`:

| Feature | Python Method | Elixir Method | Status |
|---------|--------------|---------------|--------|
| List tenants | `collection.tenants.get()` | `Tenants.list/2` | **Complete** |
| Get specific tenant | `collection.tenants.get_by_name(name)` | `Tenants.get/3` | **Complete** |
| Create tenants | `collection.tenants.create(tenants)` | `Tenants.create/4` | **Complete** |
| Update tenants | `collection.tenants.update(tenants)` | `Tenants.update/4` | **Complete** |
| Delete tenants | `collection.tenants.remove(names)` | `Tenants.delete/3` | **Complete** |
| Check exists | `collection.tenants.exists(name)` | `Tenants.exists?/3` | **Complete** |
| Activate | `collection.tenants.activate(name)` | `Tenants.activate/3` | **Complete** |
| Deactivate | `collection.tenants.deactivate(name)` | `Tenants.deactivate/3` | **Complete** |
| Offload | `collection.tenants.offload(name)` | **MISSING** | **Gap** |
| Get by names | `collection.tenants.get_by_names([])` | **MISSING** | **Gap** |
| Count | - | `Tenants.count/2` | **Extra** |
| List active | - | `Tenants.list_active/2` | **Extra** |
| List inactive | - | `Tenants.list_inactive/2` | **Extra** |

#### Missing Tenant Features

##### 1. Offload Operation

**Python:**
```python
# Offload tenant to cloud storage (FROZEN/OFFLOADED state)
collection.tenants.offload("tenant_name")

# Or batch offload
collection.tenants.offload(["tenant1", "tenant2", "tenant3"])
```

**Proposed Elixir:**
```elixir
@doc """
Offload tenant to cloud storage (set to OFFLOADED status).

## Examples

    {:ok, _} = Tenants.offload(client, "Article", "TenantA")
    {:ok, _} = Tenants.offload(client, "Article", ["TenantA", "TenantB"])

## Returns
  * `{:ok, [map()]}` - Updated tenants
  * `{:error, Error.t()}` - Error if update fails
"""
@spec offload(Client.t(), collection_name(), tenant_names()) ::
        {:ok, [map()]} | {:error, Error.t()}
def offload(client, collection_name, tenant_names) do
  update(client, collection_name, tenant_names, activity_status: :offloaded)
end
```

##### 2. Get Tenants by Names (Batch)

**Python:**
```python
# Get specific tenants by name
tenants = collection.tenants.get_by_names(["tenant1", "tenant2"])
```

**Proposed Elixir:**
```elixir
@doc """
Get specific tenants by their names.

More efficient than listing all tenants when you only need a few.

## Examples

    {:ok, tenants} = Tenants.get_by_names(client, "Article", ["TenantA", "TenantB"])

## Returns
  * `{:ok, map()}` - Map of tenant_name => tenant_info
  * `{:error, Error.t()}` - Error if request fails
"""
@spec get_by_names(Client.t(), collection_name(), [tenant_name()]) ::
        {:ok, map()} | {:error, Error.t()}
def get_by_names(client, collection_name, tenant_names) when is_list(tenant_names) do
  # Uses gRPC endpoint when available, falls back to REST
  # For REST fallback, can fetch all and filter
  case list(client, collection_name) do
    {:ok, all_tenants} ->
      filtered = Enum.filter(all_tenants, &(&1["name"] in tenant_names))
      result = Map.new(filtered, &{&1["name"], &1})
      {:ok, result}
    error -> error
  end
end
```

##### 3. Activity Status Naming Update

The Python client has updated the activity status naming:

| Old (Current Elixir) | New (Python) | Description |
|---------------------|--------------|-------------|
| `HOT` | `ACTIVE` | Tenant is fully active |
| `COLD` | `INACTIVE` | Tenant is not active, files stored locally |
| `FROZEN` | `OFFLOADED` | Tenant is not active, files stored on cloud |
| - | `OFFLOADING` | Transition state: being offloaded |
| - | `ONLOADING` | Transition state: being activated |

**Proposed Elixir Enhancement:**

```elixir
@type activity_status ::
  :active | :inactive | :offloaded |   # New naming
  :offloading | :onloading |            # Transition states (read-only)
  :hot | :cold | :frozen                # Legacy (deprecated)

# In activity_to_string/1:
defp activity_to_string(:active), do: "ACTIVE"
defp activity_to_string(:inactive), do: "INACTIVE"
defp activity_to_string(:offloaded), do: "OFFLOADED"
# Legacy support
defp activity_to_string(:hot), do: "HOT"
defp activity_to_string(:cold), do: "COLD"
defp activity_to_string(:frozen), do: "FROZEN"
```

---

### 5. Multi-Tenancy Configuration in Collections

#### Python Multi-Tenancy Config

```python
from weaviate.classes.config import Configure

# Create collection with multi-tenancy enabled
client.collections.create(
    name="Article",
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=True,    # Auto-create nonexistent tenants on insert
        auto_tenant_activation=True   # Auto-activate (HOT) tenants on access
    )
)

# Update multi-tenancy config
collection.config.update(
    multi_tenancy_config=Reconfigure.multi_tenancy(
        auto_tenant_creation=False,
        auto_tenant_activation=False
    )
)
```

#### Current Elixir Implementation

Basic multi-tenancy config support exists but needs the auto-tenant features:

```elixir
# Current - basic enable/disable
WeaviateEx.Collections.create("Article", %{
  multiTenancyConfig: %{enabled: true}
})
```

#### Proposed Enhancement

```elixir
defmodule WeaviateEx.Config.MultiTenancy do
  @moduledoc """
  Multi-tenancy configuration builders.
  """

  @type t :: %{
    enabled: boolean(),
    auto_tenant_creation: boolean() | nil,
    auto_tenant_activation: boolean() | nil
  }

  @doc """
  Create multi-tenancy configuration.

  ## Options
    * `:enabled` - Enable multi-tenancy (default: true)
    * `:auto_tenant_creation` - Auto-create tenants on insert (default: nil, uses server default)
    * `:auto_tenant_activation` - Auto-activate tenants on access (default: nil, uses server default)

  ## Examples

      config = MultiTenancy.configure(
        enabled: true,
        auto_tenant_creation: true,
        auto_tenant_activation: true
      )
  """
  @spec configure(keyword()) :: map()
  def configure(opts \\ []) do
    %{
      "enabled" => Keyword.get(opts, :enabled, true)
    }
    |> maybe_put("autoTenantCreation", Keyword.get(opts, :auto_tenant_creation))
    |> maybe_put("autoTenantActivation", Keyword.get(opts, :auto_tenant_activation))
  end

  @doc """
  Create update configuration for multi-tenancy.
  Only includes fields that can be updated after creation.
  """
  @spec update(keyword()) :: map()
  def update(opts \\ []) do
    %{}
    |> maybe_put("autoTenantCreation", Keyword.get(opts, :auto_tenant_creation))
    |> maybe_put("autoTenantActivation", Keyword.get(opts, :auto_tenant_activation))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

---

## Priority Recommendations

### Critical Priority (Implement First)

1. **`WeaviateEx.API.Roles`** - Full role management
   - `list/1`, `get/2`, `exists?/2`, `create/3`, `delete/2`
   - `add_permissions/3`, `remove_permissions/3`, `has_permissions?/3`
   - `get_user_assignments/2`, `get_group_assignments/2`

2. **`WeaviateEx.RBAC.Permissions`** - Permission builders
   - `data/2`, `collections/2`, `tenants/2`, `roles/2`, `users/2`
   - `backup/2`, `cluster/1`, `nodes_verbose/2`, `nodes_minimal/1`
   - `to_weaviate/1` for API conversion

3. **`WeaviateEx.API.Users`** - Current user info
   - `get_my_user/1`

4. **`WeaviateEx.API.Users.DB`** - DB user management
   - `create/2`, `delete/2`, `get/2`, `list_all/1`
   - `activate/2`, `deactivate/3`, `rotate_key/2`
   - `assign_roles/3`, `revoke_roles/3`, `get_assigned_roles/3`

5. **`WeaviateEx.API.Users.OIDC`** - OIDC user management
   - `assign_roles/3`, `revoke_roles/3`, `get_assigned_roles/3`

### High Priority

1. **Tenant Offload** - Add `offload/3` to `WeaviateEx.API.Tenants`
2. **Role-User Assignment Integration** - Ensure seamless workflow
3. **Permission Validation** - Add `has_permissions?/3` for role checks

### Medium Priority

1. **Get Tenants by Names** - Add `get_by_names/3` to Tenants API
2. **Multi-Tenancy Config** - Add `WeaviateEx.Config.MultiTenancy` module
3. **Activity Status Transitions** - Support OFFLOADING/ONLOADING read states
4. **Alias Permissions** - Add `alias/2` permission builder

### Low Priority

1. **Naming Convention Update** - Deprecate HOT/COLD/FROZEN in favor of ACTIVE/INACTIVE/OFFLOADED
2. **Group Management** - Add groups support for OIDC
3. **Replicate Permissions** - Add replication permission builders

---

## Implementation Roadmap

### Phase 1: Core RBAC (Week 1-2)
- [ ] Create `WeaviateEx.API.Roles` module
- [ ] Create `WeaviateEx.RBAC.Permissions` module
- [ ] Create `WeaviateEx.API.Users` module
- [ ] Create `WeaviateEx.API.Users.DB` module
- [ ] Create `WeaviateEx.API.Users.OIDC` module
- [ ] Unit tests for all new modules
- [ ] Integration tests against RBAC-enabled Weaviate

### Phase 2: Multi-Tenancy Enhancements (Week 2-3)
- [ ] Add `offload/3` to Tenants
- [ ] Add `get_by_names/3` to Tenants
- [ ] Create `WeaviateEx.Config.MultiTenancy` module
- [ ] Update activity status naming (with deprecation warnings)
- [ ] Update existing tests

### Phase 3: Integration & Documentation (Week 3-4)
- [ ] Integration between RBAC and Tenants
- [ ] End-to-end examples
- [ ] Documentation updates
- [ ] Migration guide from legacy naming

---

## Files to Create

```
lib/weaviate_ex/
├── api/
│   ├── roles.ex           # Role management
│   └── users/
│       ├── users.ex       # Main users module
│       ├── db.ex          # DB user management
│       └── oidc.ex        # OIDC user management
├── rbac/
│   └── permissions.ex     # Permission builders
└── config/
    └── multi_tenancy.ex   # Multi-tenancy config builders
```

## Test Files to Create

```
test/weaviate_ex/
├── api/
│   ├── roles_test.exs
│   └── users_test.exs
├── rbac/
│   └── permissions_test.exs
├── config/
│   └── multi_tenancy_test.exs
└── integration/
    ├── rbac_integration_test.exs
    └── tenants_integration_test.exs
```
