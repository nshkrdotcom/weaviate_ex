# Authentication, Authorization, and RBAC Gap Analysis

**Date:** December 29, 2025
**Reference Client:** Python Weaviate Client
**Target Port:** Elixir WeaviateEx

## Executive Summary

This document provides a comprehensive gap analysis between the Python Weaviate client's authentication and RBAC implementation and the Elixir port. The analysis covers authentication methods, RBAC roles, permissions, user management, group management, and token handling.

**Overall Status:** The Elixir implementation covers approximately 70% of the Python client's auth/RBAC functionality. Critical gaps exist in token management, user type separation (DB vs OIDC), and some advanced RBAC features.

---

## 1. Authentication Methods

### Python Implementation

| Method | File | Description |
|--------|------|-------------|
| `_APIKey` | `weaviate/auth.py` | Simple API key authentication |
| `_BearerToken` | `weaviate/auth.py` | Pre-existing access token with expiry and refresh token support |
| `_ClientCredentials` | `weaviate/auth.py` | OAuth2 client credentials flow with scopes |
| `_ClientPassword` | `weaviate/auth.py` | Resource Owner Password Credentials flow |

**Python Auth Factory:**
```python
class Auth:
    @staticmethod
    def api_key(api_key: str) -> _APIKey
    @staticmethod
    def client_credentials(client_secret: str, scope: Optional[SCOPES] = None) -> _ClientCredentials
    @staticmethod
    def client_password(username: str, password: str, scope: Optional[SCOPES] = None) -> _ClientPassword
    @staticmethod
    def bearer_token(access_token: str, expires_in: int = 60, refresh_token: Optional[str] = None) -> _BearerToken
```

### Elixir Implementation

| Method | File | Description |
|--------|------|-------------|
| `api_key/1` | `lib/weaviate_ex/auth.ex` | API key authentication |
| `bearer_token/2` | `lib/weaviate_ex/auth.ex` | Bearer token with opts (expires_in, refresh_token) |
| `client_credentials/3` | `lib/weaviate_ex/auth.ex` | OIDC client credentials with client_id, client_secret, scopes |
| `client_password/3` | `lib/weaviate_ex/auth.ex` | OIDC password flow with username, password, opts |

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| API Key | Yes | Yes | None | - |
| Bearer Token | Yes | Yes | None | - |
| Client Credentials | Yes | Yes | Minor - Python uses only `client_secret`, Elixir requires `client_id` + `client_secret` | **Low** |
| Client Password | Yes | Yes | None | - |
| Scope as space-separated string | Yes | No - Elixir only accepts list | **Low** |
| Negative expiry warning | Yes | No | **Medium** |
| `to_headers/1` conversion | Implicit | Yes | Elixir has explicit header conversion | - |

**Recommendation:** Add scope parsing for space-separated strings and negative expiry validation.

---

## 2. Auth Credentials Types

### Python Type Definitions

```python
OidcAuth = Union[_BearerToken, _ClientPassword, _ClientCredentials]
AuthCredentials = Union[OidcAuth, _APIKey]
```

### Elixir Type Definitions

```elixir
@type t :: api_key_auth() | bearer_token_auth() | client_credentials_auth() | password_auth()
```

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Union types for credentials | Yes | Yes | None | - |
| Deprecated type aliases (v3->v4) | Yes | No | N/A for Elixir | - |

---

## 3. Token Management

### Python Implementation (`weaviate/connect/authentication.py`)

The Python client has sophisticated token management:

1. **OAuth2 Client Integration:** Uses `authlib` for OAuth2 session management
2. **Token Endpoint Discovery:** Automatic discovery via OIDC configuration URL
3. **Token Refresh:** Automatic refresh handling via OAuth2Client
4. **Session Types:**
   - `OAuth2Client` (sync)
   - `AsyncOAuth2Client` (async)

**Key Features:**
- Automatic token refresh when expired
- Warning if no refresh token provided
- Validation of grant types supported
- Special handling for Azure/Microsoft login
- Explicit token fetching for client credentials to avoid race conditions

### Elixir Implementation

Current token handling is **minimal**:
- `to_headers/1` converts auth config to HTTP headers
- For OIDC types, returns empty list (requires token manager first)
- No token refresh mechanism
- No OAuth2 session management

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| OAuth2 session management | Yes | No | **CRITICAL** |
| Token endpoint discovery | Yes | No | **CRITICAL** |
| Automatic token refresh | Yes | No | **CRITICAL** |
| Refresh token warning | Yes | No | **Medium** |
| Azure/Microsoft validation | Yes | No | **Low** |
| Grant type validation | Yes | No | **Medium** |
| Async token handling | Yes | No | **High** |

**Recommendation:** Implement a Token Manager using an Elixir OAuth2 library (e.g., `oauth2` hex package) for OIDC flows.

---

## 4. RBAC Actions

### Python Actions (`weaviate/rbac/models.py`)

```python
class AliasAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE

class CollectionsAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE, MANAGE

class TenantsAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE

class DataAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE, MANAGE

class RolesAction(str, _Action, Enum):
    MANAGE, CREATE, READ, UPDATE, DELETE

class GroupAction(str, _Action, Enum):
    READ, ASSIGN_AND_REVOKE

class UsersAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE, ASSIGN_AND_REVOKE

class ClusterAction(str, _Action, Enum):
    READ

class NodesAction(str, _Action, Enum):
    READ

class BackupsAction(str, _Action, Enum):
    MANAGE

class ReplicateAction(str, _Action, Enum):
    CREATE, READ, UPDATE, DELETE
```

### Elixir Actions (`lib/weaviate_ex/rbac/actions.ex`)

```elixir
@actions_by_type %{
  collections: [:create, :read, :update, :delete, :manage],
  data: [:create, :read, :update, :delete, :manage],
  tenants: [:create, :read, :update, :delete],
  roles: [:create, :read, :update, :delete],
  users: [:create, :read, :update, :delete, :assign_and_revoke],
  groups: [:read, :assign_and_revoke],
  cluster: [:read],
  nodes: [:read],
  backups: [:manage],
  replicate: [:create, :read, :update, :delete],
  alias: [:create, :read, :update, :delete]
}
```

### Gap Analysis

| Action Type | Python | Elixir | Gap | Criticality |
|-------------|--------|--------|-----|-------------|
| Alias Actions | create, read, update, delete | create, read, update, delete | None | - |
| Collections Actions | create, read, update, delete, manage | create, read, update, delete, manage | None | - |
| Tenants Actions | create, read, update, delete | create, read, update, delete | None | - |
| Data Actions | create, read, update, delete, manage | create, read, update, delete, manage | None | - |
| Roles Actions | manage, create, read, update, delete | create, read, update, delete | **Missing: manage (deprecated)** | **Low** |
| Groups Actions | read, assign_and_revoke | read, assign_and_revoke | None | - |
| Users Actions | create, read, update, delete, assign_and_revoke | create, read, update, delete, assign_and_revoke | None | - |
| Cluster Actions | read | read | None | - |
| Nodes Actions | read | read | None | - |
| Backups Actions | manage | manage | None | - |
| Replicate Actions | create, read, update, delete | create, read, update, delete | None | - |

**Status:** Actions are fully aligned. The `manage_roles` in Python is marked for deprecation.

---

## 5. RBAC Resources / Permission Types

### Python Permission Structures (`weaviate/rbac/models.py`)

| Permission Type | Fields |
|-----------------|--------|
| `PermissionData` | collection, tenant |
| `PermissionCollections` | collection |
| `PermissionsTenants` | collection, tenant |
| `PermissionNodes` | collection, verbosity |
| `PermissionBackup` | collection |
| `PermissionReplicate` | collection, shard |
| `PermissionRoles` | role, scope (optional) |
| `PermissionsUsers` | users |
| `PermissionsGroups` | group, groupType |
| `PermissionsAlias` | alias, collection |

### Elixir Permission Structure (`lib/weaviate_ex/rbac/permission.ex`)

```elixir
@type t :: %__MODULE__{
  type: permission_type(),
  action: action(),
  collection: String.t() | nil,
  tenant: String.t() | nil,
  object: String.t() | nil,
  role: String.t() | nil,
  user: String.t() | nil,
  group: String.t() | nil,
  verbosity: verbosity() | nil
}
```

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Data permission (collection, tenant) | Yes | Yes | None | - |
| Data permission (object) | No explicit type | Yes | Elixir has more | - |
| Collections permission | Yes | Yes | None | - |
| Tenants permission | Yes | Yes | None | - |
| Nodes permission (verbosity) | Yes | Yes | None | - |
| Backups permission (collection) | Yes | Partial - no collection filter in builder | **Medium** |
| Replicate permission (shard) | Yes | Partial - no shard filter | **Medium** |
| Roles permission (scope) | Yes | No scope field | **High** |
| Users permission | Yes | Yes | None | - |
| Groups permission (groupType) | Yes | No groupType field | **Medium** |
| Alias permission (collection) | Yes | No - builder ignores alias_name | **Medium** |

**Recommendations:**
1. Add `scope` field to roles permissions
2. Add `shard` field for replicate permissions
3. Add `group_type` field for groups permissions
4. Fix alias permission to include alias name and collection filters
5. Add collection filter for backups permission

---

## 6. Role Management

### Python Implementation (`weaviate/rbac/executor.py`)

| Method | Description |
|--------|-------------|
| `list_all()` | Get all roles as Dict[str, Role] |
| `get(role_name)` | Get single role or None |
| `exists(role_name)` | Check if role exists |
| `create(role_name, permissions)` | Create new role |
| `delete(role_name)` | Delete role |
| `add_permissions(permissions, role_name)` | Add permissions (upsert) |
| `remove_permissions(permissions, role_name)` | Remove permissions |
| `has_permissions(permissions, role)` | Check if role has permissions |
| `get_current_roles()` | Get current user's roles (deprecated) |
| `get_user_assignments(role_name)` | Get users with UserAssignment details |
| `get_group_assignments(role_name)` | Get groups with GroupAssignment details |
| `get_assigned_user_ids(role_name)` | Get user IDs (deprecated) |

### Elixir Implementation (`lib/weaviate_ex/api/rbac.ex`)

| Method | Description |
|--------|-------------|
| `list_roles(client)` | Get all roles as list |
| `get_role(client, role_name)` | Get single role |
| `exists?(client, role_name)` | Check if role exists |
| `create_role(client, role_name, permissions)` | Create new role |
| `delete_role(client, role_name)` | Delete role |
| `add_permissions(client, role_name, permissions)` | Add permissions |
| `remove_permissions(client, role_name, permissions)` | Remove permissions |
| `has_permissions?(client, role_name, permissions)` | Check permissions |
| `get_users_for_role(client, role_name)` | Get user IDs for role |
| `get_groups_for_role(client, role_name)` | Get group IDs for role |

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| List all roles | Dict[str, Role] | [Role] | Minor format difference | **Low** |
| Get role | Yes | Yes | None | - |
| Role exists check | Yes | Yes | None | - |
| Create role | Yes | Yes | None | - |
| Delete role | Yes | Yes | None | - |
| Add permissions | Yes | Yes | None | - |
| Remove permissions | Yes | Yes | None | - |
| Has permissions | Yes | Yes | None | - |
| Get user assignments (with types) | Yes (UserAssignment) | Partial (IDs only) | **Missing user_type in response** | **Medium** |
| Get group assignments (with types) | Yes (GroupAssignment) | Partial (IDs only) | **Missing group_type in response** | **Medium** |
| Get current roles | Yes (deprecated) | No | N/A - deprecated | **Low** |

**Recommendations:**
1. Update `get_users_for_role` to return full assignment info including `user_id` and `user_type`
2. Update `get_groups_for_role` to return full assignment info including `group_id` and `group_type`

---

## 7. User Management

### Python Implementation

**Separated by User Type:**

```python
# Main entry point
class _Users:
    db: _UsersDB      # DB user operations
    oidc: _UsersOIDC  # OIDC user operations
    get_my_user()     # Current user info
```

**DB Users (`_UsersDBExecutor`):**

| Method | Description |
|--------|-------------|
| `create(user_id)` | Create DB user, returns API key |
| `delete(user_id)` | Delete DB user |
| `get(user_id)` | Get user info (UserDB) |
| `list_all()` | List all DB users |
| `get_assigned_roles(user_id, include_permissions)` | Get roles with optional permissions |
| `assign_roles(user_id, role_names)` | Assign roles |
| `revoke_roles(user_id, role_names)` | Revoke roles |
| `rotate_key(user_id)` | Rotate API key |
| `activate(user_id)` | Activate user |
| `deactivate(user_id, revoke_key)` | Deactivate user (optionally revoke key) |

**OIDC Users (`_UsersOIDCExecutor`):**

| Method | Description |
|--------|-------------|
| `get_assigned_roles(user_id, include_permissions)` | Get roles |
| `assign_roles(user_id, role_names)` | Assign roles |
| `revoke_roles(user_id, role_names)` | Revoke roles |

**User Types:**
```python
class UserTypes(str, Enum):
    DB_DYNAMIC = "db_user"
    DB_STATIC = "db_env_user"
    OIDC = "oidc"
```

### Elixir Implementation (`lib/weaviate_ex/api/users.ex`)

**Single Module (not separated):**

| Method | Description |
|--------|-------------|
| `create(client, user_id)` | Create user |
| `get(client, user_id)` | Get user |
| `get_my_user(client)` | Get current user |
| `list_all(client)` | List all users |
| `delete(client, user_id)` | Delete user |
| `activate(client, user_id)` | Activate user |
| `deactivate(client, user_id)` | Deactivate user |
| `rotate_key(client, user_id)` | Rotate API key |
| `assign_roles(client, user_id, role_names)` | Assign roles |
| `revoke_roles(client, user_id, role_names)` | Revoke roles |
| `get_assigned_roles(client, user_id)` | Get assigned roles |

**User Types:**
```elixir
@type user_type :: :db_user | :db_env_user | :oidc
```

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Separate DB/OIDC namespaces | Yes (`users.db`, `users.oidc`) | No (single module) | **HIGH** |
| Create user | Yes (DB only) | Yes | Different API path structure | **Medium** |
| Delete user | Yes | Yes | None | - |
| Get user | Yes | Yes | None | - |
| Get my user | Yes | Yes | None | - |
| List all users | Yes (DB only) | Yes | None | - |
| Activate user | Yes | Yes | None | - |
| Deactivate with revoke_key | Yes (`revoke_key: bool`) | No (no revoke_key option) | **Medium** |
| Rotate key | Yes | Yes | None | - |
| Assign roles (with user_type) | Yes | No (no user_type) | **High** |
| Revoke roles (with user_type) | Yes | No (no user_type) | **High** |
| Get assigned roles (include_permissions) | Yes | No (no option) | **Medium** |
| User types support | Full | Partial (parsing only) | **Medium** |

**API Path Differences:**

| Operation | Python Path | Elixir Path |
|-----------|-------------|-------------|
| Create DB user | `/users/db/{user_id}` | `/v1/users` |
| Delete DB user | `/users/db/{user_id}` | `/v1/users/{user_id}` |
| List DB users | `/users/db` | `/v1/users` |
| Assign roles (DB) | `/authz/users/{user_id}/assign` with `userType: db` | `/v1/users/{user_id}/assign-roles` |
| Assign roles (OIDC) | `/authz/users/{user_id}/assign` with `userType: oidc` | Same path, no type |

**Recommendations:**
1. Create separate `Users.DB` and `Users.OIDC` submodules
2. Update API paths to match Python client's REST paths
3. Add `user_type` parameter to assign/revoke operations
4. Add `include_permissions` option to `get_assigned_roles`
5. Add `revoke_key` option to deactivate

---

## 8. Group Management

### Python Implementation (`weaviate/groups/base.py`)

**Structure:**
```python
class _Groups:
    oidc: _GroupsOIDC  # Only OIDC groups are supported
```

**OIDC Groups (`_GroupsOIDCExecutor`):**

| Method | Description |
|--------|-------------|
| `get_assigned_roles(group_id, include_permissions)` | Get roles for group |
| `assign_roles(group_id, role_names)` | Assign roles to group |
| `revoke_roles(group_id, role_names)` | Revoke roles from group |
| `get_known_group_names()` | Get list of known group names |

**Group Types:**
```python
class GroupTypes(str, Enum):
    OIDC = "oidc"
```

### Elixir Implementation (`lib/weaviate_ex/api/groups.ex`)

| Method | Description |
|--------|-------------|
| `list_known(client)` | Get known group names |
| `get_assigned_roles(client, group_id)` | Get roles for group |
| `assign_roles(client, group_id, role_names)` | Assign roles |
| `revoke_roles(client, group_id, role_names)` | Revoke roles |

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| OIDC namespace (`groups.oidc`) | Yes | No (single module) | **Medium** |
| Get known groups | Yes | Yes | None | - |
| Get assigned roles | Yes | Yes | None | - |
| Assign roles | Yes | Yes | None | - |
| Revoke roles | Yes | Yes | None | - |
| include_permissions option | Yes | No | **Medium** |
| group_type in requests | Yes | No | **High** |
| GroupTypes enum | Yes | No | **Low** |

**API Path Differences:**

| Operation | Python Path | Elixir Path |
|-----------|-------------|-------------|
| Get known groups | `/authz/groups/oidc` | `/v1/authz/groups` |
| Get roles | `/authz/groups/{id}/roles/oidc` | `/v1/authz/groups/{id}/roles` |
| Assign roles | `/authz/groups/{id}/assign` with `groupType: oidc` | `/v1/authz/groups/{id}/assign-roles` |
| Revoke roles | `/authz/groups/{id}/revoke` with `groupType: oidc` | `/v1/authz/groups/{id}/revoke-roles` |

**Recommendations:**
1. Add `group_type` parameter to API requests
2. Update API paths to include group type
3. Add `include_permissions` option to `get_assigned_roles`
4. Consider creating `Groups.OIDC` submodule for consistency

---

## 9. Permission Structures / Builders

### Python Permissions Builder (`weaviate/rbac/models.py`)

```python
class Permissions:
    Nodes = NodesPermissions  # verbose/minimal
    Groups = GroupsPermissions  # oidc groups

    @staticmethod
    def alias(alias, collection, create, read, update, delete)
    @staticmethod
    def data(collection, tenant, create, read, update, delete)
    @staticmethod
    def collections(collection, create_collection, read_config, update_config, delete_collection)
    @staticmethod
    def tenants(collection, tenant, create, read, update, delete)
    @staticmethod
    def replicate(collection, shard, create, read, update, delete)
    @staticmethod
    def roles(role, create, read, update, delete, scope)
    @staticmethod
    def users(user, create, read, update, delete, assign_and_revoke)
    @staticmethod
    def backup(collection, manage)
    @staticmethod
    def cluster(read)
```

### Elixir Permissions Builder (`lib/weaviate_ex/rbac/permissions.ex`)

```elixir
def collections(collection, actions)
def data(collection, actions, opts \\ [])  # opts: tenant, object
def tenants(collection, actions, opts \\ [])  # opts: tenant
def roles(role, actions)
def users(user, actions)
def groups(group, actions)
def cluster(action \\ :read)
def nodes(verbosity \\ :minimal)
def backups(action \\ :manage)
def replicate(collection, actions)
def alias_permission(alias_name, actions)
```

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Boolean-style API (create=True) | Yes | No (list of actions) | Different design, not a gap | - |
| Alias with collection filter | Yes | No (collection filter ignored) | **Medium** |
| Backup with collection filter | Yes | No | **Medium** |
| Replicate with shard filter | Yes | No | **Medium** |
| Roles with scope filter | Yes | No | **High** |
| Groups with groupType | Yes | No | **Medium** |
| Nodes with collection filter | Yes | No | **Low** |
| Wildcard support (`:all` -> `"*"`) | Implicit | Yes | Elixir explicit | - |
| Flatten utility | No explicit | Yes | Elixir has utility | - |

**Recommendations:**
1. Add `scope` option to `roles/2`
2. Add `shard` option to `replicate/2,3`
3. Add `collection` filter to `backups/1,2`
4. Add `collection` filter to `alias_permission/2`
5. Add `group_type` option to `groups/2`

---

## 10. Role Data Structure

### Python Role (`weaviate/rbac/models.py`)

```python
@dataclass
class Role(RoleBase):
    name: str
    alias_permissions: List[AliasPermissionOutput]
    cluster_permissions: List[ClusterPermissionOutput]
    collections_permissions: List[CollectionsPermissionOutput]
    data_permissions: List[DataPermissionOutput]
    roles_permissions: List[RolesPermissionOutput]
    users_permissions: List[UsersPermissionOutput]
    backups_permissions: List[BackupsPermissionOutput]
    nodes_permissions: List[NodesPermissionOutput]
    tenants_permissions: List[TenantsPermissionOutput]
    replicate_permissions: List[ReplicatePermissionOutput]
    groups_permissions: List[GroupsPermissionOutput]

    @property
    def permissions(self) -> List[PermissionsOutputType]:
        # Combines all permission lists
```

### Elixir Role (`lib/weaviate_ex/rbac/role.ex`)

```elixir
@type t :: %__MODULE__{
  name: String.t(),
  permissions: [Permission.t()]
}
```

### Gap Analysis

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Separated permission lists by type | Yes | No (single list) | Different design | **Low** |
| Combined permissions property | Yes | Native (single list) | None | - |
| Permission joining/deduplication | Yes (`_join_permissions`) | No | **Low** |
| Local role manipulation | Yes (`add_permissions`, etc.) | Yes | None | - |

**Note:** The Elixir design with a single permissions list is simpler and achieves the same functionality. The Python design with separate lists per type provides type-safe access but adds complexity.

---

## Summary: Critical Gaps

### Critical Priority

1. **Token Management** - No OAuth2 session management, no token refresh, no OIDC token endpoint discovery

### High Priority

2. **User Type Separation** - No separate `users.db` and `users.oidc` namespaces
3. **Role Scope Permission** - Missing `scope` field for roles permissions
4. **User Type in Requests** - Missing `user_type` parameter in assign/revoke operations
5. **Group Type in Requests** - Missing `group_type` parameter in group operations

### Medium Priority

6. **User Assignment Details** - `get_users_for_role` returns only IDs, not full UserAssignment
7. **Group Assignment Details** - `get_groups_for_role` returns only IDs, not full GroupAssignment
8. **Include Permissions Option** - Missing `include_permissions` flag for role retrieval
9. **Deactivate with Revoke Key** - Missing `revoke_key` option
10. **Shard Filter for Replicate** - Missing shard filter in replicate permissions
11. **Collection Filters** - Missing collection filters for backups and alias permissions
12. **API Path Alignment** - Some API paths differ from Python client

### Low Priority

13. **Scope String Parsing** - Python accepts space-separated scope strings
14. **Permission Joining** - Python deduplicates permissions with same resource
15. **Roles Manage Action** - Deprecated action not present (by design)
16. **Nodes Collection Filter** - Missing collection filter for verbose nodes

---

## Appendix: File References

### Python Client Files

| File | Purpose |
|------|---------|
| `weaviate/auth.py` | Auth credential types and factory |
| `weaviate/connect/authentication.py` | OAuth2 session management and token handling |
| `weaviate/rbac/models.py` | Actions, Permissions, Role types |
| `weaviate/rbac/executor.py` | RBAC API operations |
| `weaviate/users/base.py` | User API operations |
| `weaviate/users/users.py` | User type definitions |
| `weaviate/groups/base.py` | Group API operations |

### Elixir Client Files

| File | Purpose |
|------|---------|
| `lib/weaviate_ex/auth.ex` | Auth credential types and factory |
| `lib/weaviate_ex/rbac/actions.ex` | Action type definitions |
| `lib/weaviate_ex/rbac/permission.ex` | Permission struct |
| `lib/weaviate_ex/rbac/permissions.ex` | Permission builder API |
| `lib/weaviate_ex/rbac/role.ex` | Role struct |
| `lib/weaviate_ex/api/rbac.ex` | RBAC API operations |
| `lib/weaviate_ex/api/users.ex` | User API operations |
| `lib/weaviate_ex/users/user.ex` | User type definitions |
| `lib/weaviate_ex/api/groups.ex` | Group API operations |
