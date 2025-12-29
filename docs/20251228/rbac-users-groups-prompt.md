# WeaviateEx: RBAC, Users & Groups Implementation Prompt

**Date:** 2025-12-28
**Objective:** Implement complete RBAC, User Management, and Group Management modules. Full TDD approach.
**Version Bump:** 0.x.0 → 0.(x+1).0

---

## Pre-Implementation Required Reading

### 1. Python Client Reference (Implementation Guide)

```
# RBAC Module
weaviate-python-client/weaviate/rbac/
├── __init__.py              # Module exports
├── models.py                # Role, Permission, Action enums/classes
├── permissions.py           # Permissions builder API
└── rbac.py                  # RBAC operations executor

# User Management Module
weaviate-python-client/weaviate/users/
├── __init__.py              # Module exports
├── models.py                # UserDB, UserOIDC, UserTypes enum
├── db_users.py              # DB user operations
├── oidc.py                  # OIDC user operations
└── users.py                 # User management coordinator

# Group Management Module
weaviate-python-client/weaviate/groups/
├── __init__.py              # Module exports
├── models.py                # Group models
├── oidc.py                  # OIDC group operations
└── groups.py                # Group management coordinator

# Authentication (Reference for token management)
weaviate-python-client/weaviate/auth.py
weaviate-python-client/weaviate/connect/authentication.py
```

### 2. Elixir Client Current State

```
# Existing auth (to extend)
lib/weaviate_ex/auth.ex                 # Basic auth methods

# API structure (pattern to follow)
lib/weaviate_ex/api/schema.ex           # Example CRUD pattern
lib/weaviate_ex/api/objects.ex          # Example operations
lib/weaviate_ex/api/tenants.ex          # Example management API

# Types (pattern for models)
lib/weaviate_ex/types/*.ex              # Existing type definitions

# Error handling (extend for RBAC errors)
lib/weaviate_ex/error.ex
```

### 3. Gap Analysis Documentation

```
docs/20251228/weaviate-client-gap-analysis/
├── auth-security-rbac.md    # PRIMARY - Full RBAC gap analysis
└── gap-analysis-summary.md  # Overall priorities
```

### 4. Weaviate RBAC REST API Documentation

```
# Endpoints to implement
POST   /v1/authz/roles                    # Create role
GET    /v1/authz/roles                    # List all roles
GET    /v1/authz/roles/{role_name}        # Get role
DELETE /v1/authz/roles/{role_name}        # Delete role
POST   /v1/authz/roles/{role_name}/add-permissions
POST   /v1/authz/roles/{role_name}/remove-permissions
GET    /v1/authz/roles/{role_name}/has-permissions
GET    /v1/authz/roles/{role_name}/users
GET    /v1/authz/roles/{role_name}/groups

POST   /v1/users                          # Create user
GET    /v1/users                          # List users
GET    /v1/users/{user_id}                # Get user
DELETE /v1/users/{user_id}                # Delete user
POST   /v1/users/{user_id}/activate
POST   /v1/users/{user_id}/deactivate
POST   /v1/users/{user_id}/rotate-key
POST   /v1/users/{user_id}/assign-roles
POST   /v1/users/{user_id}/revoke-roles
GET    /v1/users/{user_id}/roles
GET    /v1/users/own                      # Get current user

GET    /v1/authz/groups                   # List groups (known names)
GET    /v1/authz/groups/{group_id}/roles
POST   /v1/authz/groups/{group_id}/assign-roles
POST   /v1/authz/groups/{group_id}/revoke-roles
```

---

## Context

### Features to Implement (~35 operations)

| Module | Operations | Priority |
|--------|------------|----------|
| RBAC Roles | 10 operations | Critical |
| Permissions Builder | 11 permission types | Critical |
| User Management | 11 operations | Critical |
| Group Management | 4 operations | High |
| OIDC Token Management | 3 operations | Medium |

### Module Structure

```
lib/weaviate_ex/
├── rbac/
│   ├── role.ex              # Role struct and operations
│   ├── permission.ex        # Permission struct
│   ├── permissions.ex       # Builder API (Permissions.data(...), etc.)
│   └── actions.ex           # Action enums (11 types)
├── users/
│   ├── user.ex              # User structs (DB, OIDC, Own)
│   └── manager.ex           # User CRUD operations
├── groups/
│   ├── group.ex             # Group struct
│   └── manager.ex           # Group role operations
└── auth/
    └── token_manager.ex     # Token refresh (optional enhancement)
```

---

## Implementation Instructions

### Phase 1: Action & Permission Types (TDD)

#### 1.1 Create Action Enums

Create `lib/weaviate_ex/rbac/actions.ex`:

```elixir
defmodule WeaviateEx.RBAC.Actions do
  @moduledoc """
  Permission action types for Weaviate RBAC.
  """

  # Collections actions
  @type collections_action :: :create | :read | :update | :delete | :manage

  # Data actions
  @type data_action :: :create | :read | :update | :delete | :manage

  # Tenants actions
  @type tenants_action :: :create | :read | :update | :delete

  # Roles actions
  @type roles_action :: :create | :read | :update | :delete

  # Users actions
  @type users_action :: :create | :read | :update | :delete | :assign_and_revoke

  # Groups actions
  @type groups_action :: :read | :assign_and_revoke

  # Cluster actions
  @type cluster_action :: :read

  # Nodes actions
  @type nodes_action :: :read

  # Backups actions
  @type backups_action :: :manage

  # Replicate actions
  @type replicate_action :: :create | :read | :update | :delete

  # Alias actions
  @type alias_action :: :create | :read | :update | :delete

  @doc "Convert action atom to API string"
  def to_api_string(action)

  @doc "Parse API string to action atom"
  def from_api_string(string)
end
```

**Tests first** in `test/weaviate_ex/rbac/actions_test.exs`:
- `test "converts all action atoms to API strings"`
- `test "parses all API strings to action atoms"`
- `test "round-trips all actions correctly"`

#### 1.2 Create Permission Struct

Create `lib/weaviate_ex/rbac/permission.ex`:

```elixir
defmodule WeaviateEx.RBAC.Permission do
  @moduledoc """
  Represents a single permission in Weaviate RBAC.
  """

  @type t :: %__MODULE__{
    type: permission_type(),
    action: atom(),
    collection: String.t() | nil,
    tenant: String.t() | nil,
    object: String.t() | nil,
    role: String.t() | nil,
    user: String.t() | nil,
    group: String.t() | nil,
    verbosity: :minimal | :verbose | nil
  }

  @type permission_type ::
    :collections | :data | :tenants | :roles | :users |
    :groups | :cluster | :nodes | :backups | :replicate | :alias

  defstruct [
    :type,
    :action,
    :collection,
    :tenant,
    :object,
    :role,
    :user,
    :group,
    :verbosity
  ]

  @doc "Encode permission to API format"
  def to_api(permission)

  @doc "Decode permission from API response"
  def from_api(map)
end
```

**Tests first** in `test/weaviate_ex/rbac/permission_test.exs`:
- `test "encodes collections permission to API format"`
- `test "encodes data permission with tenant to API format"`
- `test "decodes permission from API response"`
- `test "handles wildcard collections (*)"`
- `test "handles wildcard tenants (*)"`

#### 1.3 Create Permissions Builder

Create `lib/weaviate_ex/rbac/permissions.ex`:

```elixir
defmodule WeaviateEx.RBAC.Permissions do
  @moduledoc """
  Builder API for constructing permissions.

  ## Examples

      # Full access to a collection
      Permissions.collections("Article", [:create, :read, :update, :delete])

      # Read data from specific tenant
      Permissions.data("Article", :read, tenant: "tenant-a")

      # Manage all backups
      Permissions.backups(:manage)

      # Verbose node info
      Permissions.nodes(:verbose)
  """

  alias WeaviateEx.RBAC.Permission

  @doc "Create collections permission"
  @spec collections(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def collections(collection \\ "*", actions)

  @doc "Create data permission"
  @spec data(String.t() | :all, [atom()] | atom(), keyword()) :: Permission.t() | [Permission.t()]
  def data(collection \\ "*", actions, opts \\ [])

  @doc "Create tenants permission"
  @spec tenants(String.t() | :all, [atom()] | atom(), keyword()) :: Permission.t() | [Permission.t()]
  def tenants(collection \\ "*", actions, opts \\ [])

  @doc "Create roles permission"
  @spec roles(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def roles(role \\ "*", actions)

  @doc "Create users permission"
  @spec users(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def users(user \\ "*", actions)

  @doc "Create groups permission (OIDC)"
  @spec groups(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def groups(group \\ "*", actions)

  @doc "Create cluster permission"
  @spec cluster(atom()) :: Permission.t()
  def cluster(action \\ :read)

  @doc "Create nodes permission"
  @spec nodes(:verbose | :minimal) :: Permission.t()
  def nodes(verbosity \\ :minimal)

  @doc "Create backups permission"
  @spec backups(atom()) :: Permission.t()
  def backups(action \\ :manage)

  @doc "Create replicate permission"
  @spec replicate(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def replicate(collection \\ "*", actions)

  @doc "Create alias permission"
  @spec alias_permission(String.t() | :all, [atom()] | atom()) :: Permission.t() | [Permission.t()]
  def alias_permission(alias_name \\ "*", actions)
end
```

**Tests first** in `test/weaviate_ex/rbac/permissions_test.exs`:
- `test "Permissions.collections/2 creates single action permission"`
- `test "Permissions.collections/2 creates multiple action permissions"`
- `test "Permissions.data/3 with tenant option"`
- `test "Permissions.data/3 with object option"`
- `test "Permissions.nodes/1 with :verbose"`
- `test "Permissions.nodes/1 with :minimal"`
- `test "all permission builders return valid Permission structs"`

### Phase 2: Role Management (TDD)

#### 2.1 Create Role Struct

Create `lib/weaviate_ex/rbac/role.ex`:

```elixir
defmodule WeaviateEx.RBAC.Role do
  @moduledoc """
  Represents a role in Weaviate RBAC.
  """

  alias WeaviateEx.RBAC.Permission

  @type t :: %__MODULE__{
    name: String.t(),
    permissions: [Permission.t()]
  }

  defstruct [:name, permissions: []]

  @doc "Create new role with permissions"
  def new(name, permissions \\ [])

  @doc "Encode role to API format"
  def to_api(role)

  @doc "Decode role from API response"
  def from_api(map)

  @doc "Add permissions to role"
  def add_permissions(role, permissions)

  @doc "Remove permissions from role"
  def remove_permissions(role, permissions)
end
```

**Tests first** in `test/weaviate_ex/rbac/role_test.exs`:
- `test "creates role with name and permissions"`
- `test "encodes role to API format"`
- `test "decodes role from API response"`
- `test "adds permissions to existing role"`
- `test "removes permissions from role"`

#### 2.2 Create RBAC API Module

Create `lib/weaviate_ex/api/rbac.ex`:

```elixir
defmodule WeaviateEx.API.RBAC do
  @moduledoc """
  Role-Based Access Control operations.

  ## Examples

      # Create a role with permissions
      permissions = [
        Permissions.collections("Article", [:read]),
        Permissions.data("Article", [:read, :create])
      ]
      {:ok, role} = RBAC.create_role(client, "article-reader", permissions)

      # List all roles
      {:ok, roles} = RBAC.list_roles(client)

      # Check if role has permission
      {:ok, true} = RBAC.has_permission?(client, "article-reader", permission)

      # Delete role
      :ok = RBAC.delete_role(client, "article-reader")
  """

  alias WeaviateEx.RBAC.{Role, Permission, Permissions}

  @doc "List all roles"
  @spec list_roles(client :: term()) :: {:ok, [Role.t()]} | {:error, term()}
  def list_roles(client)

  @doc "Check if role exists"
  @spec exists?(client :: term(), role_name :: String.t()) :: {:ok, boolean()} | {:error, term()}
  def exists?(client, role_name)

  @doc "Get role by name"
  @spec get_role(client :: term(), role_name :: String.t()) :: {:ok, Role.t()} | {:error, term()}
  def get_role(client, role_name)

  @doc "Create role with permissions"
  @spec create_role(client :: term(), role_name :: String.t(), permissions :: [Permission.t()]) ::
    {:ok, Role.t()} | {:error, term()}
  def create_role(client, role_name, permissions)

  @doc "Delete role"
  @spec delete_role(client :: term(), role_name :: String.t()) :: :ok | {:error, term()}
  def delete_role(client, role_name)

  @doc "Add permissions to existing role"
  @spec add_permissions(client :: term(), role_name :: String.t(), permissions :: [Permission.t()]) ::
    :ok | {:error, term()}
  def add_permissions(client, role_name, permissions)

  @doc "Remove permissions from role"
  @spec remove_permissions(client :: term(), role_name :: String.t(), permissions :: [Permission.t()]) ::
    :ok | {:error, term()}
  def remove_permissions(client, role_name, permissions)

  @doc "Check if role has specific permissions"
  @spec has_permissions?(client :: term(), role_name :: String.t(), permissions :: [Permission.t()]) ::
    {:ok, boolean()} | {:error, term()}
  def has_permissions?(client, role_name, permissions)

  @doc "Get users assigned to role"
  @spec get_users_for_role(client :: term(), role_name :: String.t()) ::
    {:ok, [String.t()]} | {:error, term()}
  def get_users_for_role(client, role_name)

  @doc "Get groups assigned to role"
  @spec get_groups_for_role(client :: term(), role_name :: String.t()) ::
    {:ok, [String.t()]} | {:error, term()}
  def get_groups_for_role(client, role_name)
end
```

**Tests first** in `test/weaviate_ex/api/rbac_test.exs`:

```elixir
describe "list_roles/1" do
  test "returns empty list when no roles exist"
  test "returns list of Role structs"
end

describe "create_role/3" do
  test "creates role with single permission"
  test "creates role with multiple permissions"
  test "returns error for duplicate role name"
  test "returns error for invalid permission"
end

describe "get_role/2" do
  test "returns role with permissions"
  test "returns error for non-existent role"
end

describe "delete_role/2" do
  test "deletes existing role"
  test "returns error for non-existent role"
  test "returns error for built-in role"
end

describe "add_permissions/3" do
  test "adds permissions to existing role"
  test "is idempotent for duplicate permissions"
end

describe "remove_permissions/3" do
  test "removes permissions from role"
  test "handles non-existent permissions gracefully"
end

describe "has_permissions?/3" do
  test "returns true when role has all permissions"
  test "returns false when role missing permission"
end

describe "get_users_for_role/2" do
  test "returns list of user IDs assigned to role"
end

describe "get_groups_for_role/2" do
  test "returns list of group IDs assigned to role"
end
```

### Phase 3: User Management (TDD)

#### 3.1 Create User Structs

Create `lib/weaviate_ex/users/user.ex`:

```elixir
defmodule WeaviateEx.Users.User do
  @moduledoc """
  User structs for Weaviate user management.
  """

  @type user_type :: :db_user | :db_env_user | :oidc

  defmodule DB do
    @moduledoc "Database-managed user"
    @type t :: %__MODULE__{
      user_id: String.t(),
      api_key: String.t() | nil,
      active: boolean(),
      roles: [String.t()]
    }
    defstruct [:user_id, :api_key, :active, roles: []]
  end

  defmodule OIDC do
    @moduledoc "OIDC-managed user"
    @type t :: %__MODULE__{
      user_id: String.t(),
      groups: [String.t()],
      roles: [String.t()]
    }
    defstruct [:user_id, groups: [], roles: []]
  end

  defmodule Own do
    @moduledoc "Current authenticated user info"
    @type t :: %__MODULE__{
      user_id: String.t(),
      user_type: user_type(),
      roles: [String.t()],
      groups: [String.t()]
    }
    defstruct [:user_id, :user_type, roles: [], groups: []]
  end

  @doc "Decode user from API response"
  def from_api(map)
end
```

**Tests first** in `test/weaviate_ex/users/user_test.exs`:
- `test "decodes DB user from API response"`
- `test "decodes OIDC user from API response"`
- `test "decodes Own user from API response"`
- `test "handles missing optional fields"`

#### 3.2 Create Users API Module

Create `lib/weaviate_ex/api/users.ex`:

```elixir
defmodule WeaviateEx.API.Users do
  @moduledoc """
  User management operations.

  ## Examples

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

  alias WeaviateEx.Users.User

  @doc "Create new DB user (returns user with API key)"
  @spec create(client :: term(), user_id :: String.t()) ::
    {:ok, User.DB.t()} | {:error, term()}
  def create(client, user_id)

  @doc "Get user by ID"
  @spec get(client :: term(), user_id :: String.t()) ::
    {:ok, User.DB.t() | User.OIDC.t()} | {:error, term()}
  def get(client, user_id)

  @doc "Get current authenticated user"
  @spec get_my_user(client :: term()) :: {:ok, User.Own.t()} | {:error, term()}
  def get_my_user(client)

  @doc "List all users"
  @spec list_all(client :: term()) ::
    {:ok, [User.DB.t() | User.OIDC.t()]} | {:error, term()}
  def list_all(client)

  @doc "Delete user"
  @spec delete(client :: term(), user_id :: String.t()) :: :ok | {:error, term()}
  def delete(client, user_id)

  @doc "Activate user"
  @spec activate(client :: term(), user_id :: String.t()) :: :ok | {:error, term()}
  def activate(client, user_id)

  @doc "Deactivate user"
  @spec deactivate(client :: term(), user_id :: String.t()) :: :ok | {:error, term()}
  def deactivate(client, user_id)

  @doc "Rotate user's API key (returns new key)"
  @spec rotate_key(client :: term(), user_id :: String.t()) ::
    {:ok, String.t()} | {:error, term()}
  def rotate_key(client, user_id)

  @doc "Assign roles to user"
  @spec assign_roles(client :: term(), user_id :: String.t(), role_names :: [String.t()]) ::
    :ok | {:error, term()}
  def assign_roles(client, user_id, role_names)

  @doc "Revoke roles from user"
  @spec revoke_roles(client :: term(), user_id :: String.t(), role_names :: [String.t()]) ::
    :ok | {:error, term()}
  def revoke_roles(client, user_id, role_names)

  @doc "Get roles assigned to user"
  @spec get_assigned_roles(client :: term(), user_id :: String.t()) ::
    {:ok, [String.t()]} | {:error, term()}
  def get_assigned_roles(client, user_id)
end
```

**Tests first** in `test/weaviate_ex/api/users_test.exs`:

```elixir
describe "create/2" do
  test "creates user and returns API key"
  test "returns error for duplicate user_id"
  test "returns error for invalid user_id format"
end

describe "get/2" do
  test "returns DB user details"
  test "returns OIDC user details"
  test "returns error for non-existent user"
end

describe "get_my_user/1" do
  test "returns current user info"
  test "includes roles and groups"
end

describe "list_all/1" do
  test "returns all users"
  test "includes both DB and OIDC users"
end

describe "delete/2" do
  test "deletes existing user"
  test "returns error for non-existent user"
end

describe "activate/2" do
  test "activates deactivated user"
  test "is idempotent for already active user"
end

describe "deactivate/2" do
  test "deactivates active user"
  test "is idempotent for already inactive user"
end

describe "rotate_key/2" do
  test "returns new API key"
  test "invalidates old API key"
  test "returns error for OIDC user"
end

describe "assign_roles/3" do
  test "assigns single role"
  test "assigns multiple roles"
  test "returns error for non-existent role"
end

describe "revoke_roles/3" do
  test "revokes roles from user"
  test "handles non-assigned roles gracefully"
end

describe "get_assigned_roles/2" do
  test "returns list of role names"
end
```

### Phase 4: Group Management (TDD)

#### 4.1 Create Group Struct

Create `lib/weaviate_ex/groups/group.ex`:

```elixir
defmodule WeaviateEx.Groups.Group do
  @moduledoc """
  OIDC Group representation.
  """

  @type t :: %__MODULE__{
    name: String.t(),
    roles: [String.t()]
  }

  defstruct [:name, roles: []]

  @doc "Decode group from API response"
  def from_api(map)
end
```

#### 4.2 Create Groups API Module

Create `lib/weaviate_ex/api/groups.ex`:

```elixir
defmodule WeaviateEx.API.Groups do
  @moduledoc """
  OIDC Group management operations.

  ## Examples

      # Get known group names
      {:ok, groups} = Groups.list_known(client)

      # Get roles assigned to group
      {:ok, roles} = Groups.get_assigned_roles(client, "engineering-team")

      # Assign roles to group
      :ok = Groups.assign_roles(client, "engineering-team", ["developer"])

      # Revoke roles from group
      :ok = Groups.revoke_roles(client, "engineering-team", ["admin"])
  """

  alias WeaviateEx.Groups.Group

  @doc "List known OIDC group names"
  @spec list_known(client :: term()) :: {:ok, [String.t()]} | {:error, term()}
  def list_known(client)

  @doc "Get roles assigned to group"
  @spec get_assigned_roles(client :: term(), group_id :: String.t()) ::
    {:ok, [String.t()]} | {:error, term()}
  def get_assigned_roles(client, group_id)

  @doc "Assign roles to group"
  @spec assign_roles(client :: term(), group_id :: String.t(), role_names :: [String.t()]) ::
    :ok | {:error, term()}
  def assign_roles(client, group_id, role_names)

  @doc "Revoke roles from group"
  @spec revoke_roles(client :: term(), group_id :: String.t(), role_names :: [String.t()]) ::
    :ok | {:error, term()}
  def revoke_roles(client, group_id, role_names)
end
```

**Tests first** in `test/weaviate_ex/api/groups_test.exs`:

```elixir
describe "list_known/1" do
  test "returns list of known group names"
  test "returns empty list when no groups known"
end

describe "get_assigned_roles/2" do
  test "returns roles for group"
  test "returns empty list for group with no roles"
end

describe "assign_roles/3" do
  test "assigns roles to OIDC group"
  test "creates group-role mapping if not exists"
end

describe "revoke_roles/3" do
  test "revokes roles from group"
  test "handles non-assigned roles gracefully"
end
```

### Phase 5: Main Module Integration

#### 5.1 Update Main WeaviateEx Module

Add to `lib/weaviate_ex.ex`:

```elixir
defmodule WeaviateEx do
  # ... existing code ...

  # RBAC convenience functions
  defdelegate list_roles(client), to: WeaviateEx.API.RBAC
  defdelegate get_role(client, name), to: WeaviateEx.API.RBAC
  defdelegate create_role(client, name, permissions), to: WeaviateEx.API.RBAC
  defdelegate delete_role(client, name), to: WeaviateEx.API.RBAC

  # User management convenience functions
  defdelegate create_user(client, user_id), to: WeaviateEx.API.Users, as: :create
  defdelegate get_user(client, user_id), to: WeaviateEx.API.Users, as: :get
  defdelegate list_users(client), to: WeaviateEx.API.Users, as: :list_all
  defdelegate delete_user(client, user_id), to: WeaviateEx.API.Users, as: :delete
  defdelegate get_my_user(client), to: WeaviateEx.API.Users

  # Group management convenience functions
  defdelegate list_groups(client), to: WeaviateEx.API.Groups, as: :list_known
  defdelegate assign_group_roles(client, group, roles), to: WeaviateEx.API.Groups, as: :assign_roles
  defdelegate revoke_group_roles(client, group, roles), to: WeaviateEx.API.Groups, as: :revoke_roles
end
```

### Phase 6: Error Handling Updates

#### 6.1 Add RBAC-Specific Error Types

Update `lib/weaviate_ex/error.ex`:

```elixir
# Add to status_to_type/1
defp status_to_type(403), do: :forbidden  # Already exists, ensure RBAC context

# Add RBAC-specific error context
def rbac_error(type, message, details \\ %{}) do
  %__MODULE__{
    type: type,
    message: message,
    details: Map.put(details, :category, :rbac)
  }
end

# Specific RBAC errors
def role_not_found(role_name) do
  rbac_error(:not_found, "Role '#{role_name}' not found", %{role: role_name})
end

def permission_denied(action, resource) do
  rbac_error(:forbidden, "Permission denied for #{action} on #{resource}", %{
    action: action,
    resource: resource
  })
end

def user_not_found(user_id) do
  rbac_error(:not_found, "User '#{user_id}' not found", %{user_id: user_id})
end

def invalid_permission(reason) do
  rbac_error(:bad_request, "Invalid permission: #{reason}", %{})
end
```

**Tests first** in `test/weaviate_ex/error_test.exs`:
- `test "rbac_error/3 creates error with rbac category"`
- `test "role_not_found/1 creates proper error struct"`
- `test "permission_denied/2 includes action and resource"`

### Phase 7: Documentation Updates

#### 7.1 Update README.md

Add RBAC section:

```markdown
## Role-Based Access Control (RBAC)

WeaviateEx provides full RBAC support for managing roles, users, and groups.

### Creating Roles with Permissions

```elixir
alias WeaviateEx.RBAC.Permissions

# Define permissions
permissions = [
  Permissions.collections("Article", [:read, :create]),
  Permissions.data("Article", [:read, :create, :update]),
  Permissions.tenants("Article", [:read])
]

# Create role
{:ok, role} = WeaviateEx.create_role(client, "article-editor", permissions)
```

### Managing Users

```elixir
# Create a new user
{:ok, user} = WeaviateEx.create_user(client, "john.doe")
IO.puts("API Key: #{user.api_key}")

# Assign roles
:ok = WeaviateEx.API.Users.assign_roles(client, "john.doe", ["article-editor"])

# Get current user info
{:ok, me} = WeaviateEx.get_my_user(client)
```

### OIDC Group Management

```elixir
# Assign roles to OIDC group
:ok = WeaviateEx.assign_group_roles(client, "engineering", ["developer", "reader"])
```
```

#### 7.2 Create RBAC Guide

Create `guides/rbac.md` (if guides directory exists) or add to docs:

```markdown
# RBAC Guide

## Permission Types

WeaviateEx supports 11 permission types:

| Type | Actions | Description |
|------|---------|-------------|
| collections | create, read, update, delete, manage | Collection schema operations |
| data | create, read, update, delete, manage | Object CRUD operations |
| tenants | create, read, update, delete | Multi-tenancy management |
| roles | create, read, update, delete | Role management |
| users | create, read, update, delete, assign_and_revoke | User management |
| groups | read, assign_and_revoke | OIDC group management |
| cluster | read | Cluster information |
| nodes | read (minimal/verbose) | Node information |
| backups | manage | Backup operations |
| replicate | create, read, update, delete | Replication management |
| alias | create, read, update, delete | Collection aliases |

## Building Permissions

### Collections Permissions
```elixir
# Single action
Permissions.collections("MyCollection", :read)

# Multiple actions
Permissions.collections("MyCollection", [:read, :update])

# All collections
Permissions.collections(:all, [:read])
```

### Data Permissions with Filters
```elixir
# Specific tenant
Permissions.data("MyCollection", :read, tenant: "tenant-a")

# All tenants
Permissions.data("MyCollection", :read, tenant: :all)
```

### Nodes Permissions
```elixir
# Minimal info
Permissions.nodes(:minimal)

# Full verbose info
Permissions.nodes(:verbose)
```
```

#### 7.3 Update CHANGELOG.md

```markdown
## [0.x.0] - 2025-12-28

### Added
- **RBAC Module**: Complete role-based access control support
  - Role CRUD operations (create, list, get, delete)
  - Permission management (add, remove, check)
  - 11 permission types (collections, data, tenants, roles, users, groups, cluster, nodes, backups, replicate, alias)
  - Type-safe permissions builder API (`WeaviateEx.RBAC.Permissions`)

- **User Management Module**: Full user lifecycle management
  - User CRUD (create, list, get, delete)
  - User activation/deactivation
  - API key rotation
  - Role assignment/revocation
  - Current user info (`get_my_user/1`)

- **Group Management Module**: OIDC group support
  - List known groups
  - Group role assignment/revocation

### Changed
- Extended `WeaviateEx.Error` with RBAC-specific error types

### Documentation
- Added RBAC guide with permission types reference
- Updated README with RBAC examples
```

### Phase 8: Version Bump

#### 8.1 Update mix.exs

```elixir
def project do
  [
    app: :weaviate_ex,
    version: "0.x.0",  # Increment minor version
    # ...
  ]
end
```

---

## Quality Gates

### All Must Pass Before Completion

```bash
# 1. All tests pass
mix test

# 2. No compiler warnings
mix compile --warnings-as-errors

# 3. Dialyzer passes
mix dialyzer

# 4. Credo passes (strict mode)
mix credo --strict

# 5. Documentation generates without warnings
mix docs

# 6. Formatter check
mix format --check-formatted
```

### Test Coverage Requirements

- All 35+ RBAC/Users/Groups operations have tests
- All permission types tested
- All error paths tested
- Integration tests with real Weaviate instance (requires RBAC-enabled server)

---

## Files to Create

```
lib/weaviate_ex/rbac/
├── actions.ex               # Action type definitions
├── permission.ex            # Permission struct
├── permissions.ex           # Builder API
└── role.ex                  # Role struct

lib/weaviate_ex/users/
└── user.ex                  # User structs (DB, OIDC, Own)

lib/weaviate_ex/groups/
└── group.ex                 # Group struct

lib/weaviate_ex/api/
├── rbac.ex                  # RBAC operations
├── users.ex                 # User operations
└── groups.ex                # Group operations

test/weaviate_ex/rbac/
├── actions_test.exs
├── permission_test.exs
├── permissions_test.exs
└── role_test.exs

test/weaviate_ex/users/
└── user_test.exs

test/weaviate_ex/groups/
└── group_test.exs

test/weaviate_ex/api/
├── rbac_test.exs
├── users_test.exs
└── groups_test.exs
```

## Files to Modify

```
lib/weaviate_ex.ex           # Add convenience delegations
lib/weaviate_ex/error.ex     # Add RBAC error types
mix.exs                      # Version bump
README.md                    # Add RBAC documentation
CHANGELOG.md                 # Document new features
```

---

## Success Criteria

1. `mix test` - All tests pass (0 failures)
2. `mix compile --warnings-as-errors` - No warnings
3. `mix dialyzer` - No errors
4. `mix credo --strict` - No issues
5. `mix docs` - Generates without warnings
6. All 11 permission types implemented and tested
7. All 10 RBAC operations implemented and tested
8. All 11 user operations implemented and tested
9. All 4 group operations implemented and tested
10. README documents RBAC usage with examples
11. CHANGELOG documents all new features
12. Version incremented in mix.exs

---

## Integration Test Requirements

RBAC tests require a Weaviate instance with authentication enabled:

```yaml
# docker-compose.yml for testing
services:
  weaviate:
    image: semitechnologies/weaviate:latest
    environment:
      AUTHENTICATION_APIKEY_ENABLED: 'true'
      AUTHENTICATION_APIKEY_ALLOWED_KEYS: 'admin-key,test-key'
      AUTHENTICATION_APIKEY_USERS: 'admin,tester'
      AUTHORIZATION_ADMINLIST_ENABLED: 'true'
      AUTHORIZATION_ADMINLIST_USERS: 'admin'
```

---

## Estimated Scope

| Component | Files | Estimated Effort |
|-----------|-------|------------------|
| Actions & Permission types | 3 | 4-6 hours |
| Permissions builder | 1 | 4-6 hours |
| Role struct & RBAC API | 2 | 8-12 hours |
| User structs & Users API | 2 | 8-12 hours |
| Group struct & Groups API | 2 | 4-6 hours |
| Error handling updates | 1 | 2-4 hours |
| Tests (unit + integration) | 10 | 16-24 hours |
| Documentation | 3 | 4-6 hours |
| **Total** | ~24 files | ~50-76 hours |

---

*This prompt provides complete instructions for implementing RBAC, User Management, and Group Management in WeaviateEx with full test coverage and documentation.*
