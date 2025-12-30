# RBAC and Users Gap Analysis: Python vs Elixir

## Executive Summary

This document provides a comprehensive gap analysis comparing the Role-Based Access Control (RBAC), Users, and Groups functionality between the canonical Weaviate Python client and the Elixir port. The Elixir implementation covers most core functionality but has notable gaps in advanced permission handling, user assignment queries, and API endpoint naming conventions.

**Overall Coverage: ~75%**

---

## 1. Role Management

### 1.1 Python Implementation

**Location:** `/weaviate-python-client/weaviate/rbac/`

The Python client provides comprehensive role management through `_RolesExecutor`:

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List all roles | `list_all()` | `GET /authz/roles` |
| Check role exists | `exists(role_name)` | `GET /authz/roles/{name}` |
| Get single role | `get(role_name)` | `GET /authz/roles/{name}` |
| Create role | `create(role_name, permissions)` | `POST /authz/roles` |
| Delete role | `delete(role_name)` | `DELETE /authz/roles/{name}` |
| Get current user roles | `get_current_roles()` (deprecated) | `GET /authz/users/own-roles` |
| Get user assignments | `get_user_assignments(role_name)` | `GET /authz/roles/{name}/user-assignments` |
| Get group assignments | `get_group_assignments(role_name)` | `GET /authz/roles/{name}/group-assignments` |
| Get assigned user IDs | `get_assigned_user_ids(role_name)` (deprecated) | `GET /authz/roles/{name}/users` |
| Add permissions | `add_permissions(permissions, role_name)` | `POST /authz/roles/{name}/add-permissions` |
| Remove permissions | `remove_permissions(permissions, role_name)` | `POST /authz/roles/{name}/remove-permissions` |
| Check permissions | `has_permissions(permissions, role)` | `POST /authz/roles/{name}/has-permission` |

**Key Features:**
- Role struct contains categorized permissions (alias, cluster, collections, data, roles, users, backups, nodes, tenants, replicate, groups)
- `_join_permissions()` function to merge permissions with same resource
- Async support via `@executor.wrap("async")`

### 1.2 Elixir Implementation

**Location:** `/lib/weaviate_ex/api/rbac.ex`, `/lib/weaviate_ex/rbac/`

| Operation | Function | Endpoint |
|-----------|----------|----------|
| List all roles | `list_roles/2` | `GET /v1/authz/roles` |
| Check role exists | `exists?/3` | `GET /v1/authz/roles/{name}` |
| Get single role | `get_role/3` | `GET /v1/authz/roles/{name}` |
| Create role | `create_role/4` | `POST /v1/authz/roles` |
| Delete role | `delete_role/3` | `DELETE /v1/authz/roles/{name}` |
| Get users for role | `get_users_for_role/3` | `GET /v1/authz/roles/{name}/users` |
| Get groups for role | `get_groups_for_role/3` | `GET /v1/authz/roles/{name}/groups` |
| Add permissions | `add_permissions/4` | `POST /v1/authz/roles/{name}/add-permissions` |
| Remove permissions | `remove_permissions/4` | `POST /v1/authz/roles/{name}/remove-permissions` |
| Check permissions | `has_permissions?/4` | `POST /v1/authz/roles/{name}/has-permissions` |

### 1.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| User assignments endpoint | `get_user_assignments()` returns `UserAssignment{user_id, user_type}` | `get_users_for_role()` returns list of strings | **HIGH** - Missing user type information |
| Group assignments endpoint | `get_group_assignments()` returns `GroupAssignment{group_id, group_type}` | `get_groups_for_role()` returns list of strings | **HIGH** - Missing group type information |
| Batch permission checking | Parallel checks with `asyncio.gather()` | Single sequential check | **MEDIUM** - Performance difference |
| Permission flattening | `_flatten_permissions()` handles nested sequences | `Permissions.flatten/1` basic implementation | **LOW** - Functional but simpler |

### 1.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Deprecated method warnings | `@deprecated` decorator with migration message | Not applicable | **LOW** |
| Permission joining | `_join_permissions()` merges same-resource permissions | No equivalent | **LOW** - Optimization only |
| Endpoint path prefix | `/authz/roles` | `/v1/authz/roles` | **LOW** - API version difference |

---

## 2. Permission Types and Actions

### 2.1 Python Implementation

**Location:** `/weaviate-python-client/weaviate/rbac/models.py`

#### Permission Types:
- `AliasAction`: create, read, update, delete
- `CollectionsAction`: create, read, update, delete, manage
- `TenantsAction`: create, read, update, delete
- `DataAction`: create, read, update, delete, manage
- `RolesAction`: manage (deprecated), create, read, update, delete
- `GroupAction`: read, assign_and_revoke
- `UsersAction`: create, read, update, delete, assign_and_revoke
- `ClusterAction`: read
- `NodesAction`: read
- `BackupsAction`: manage
- `ReplicateAction`: create, read, update, delete

#### Permission Builders (`Permissions` class):
```python
Permissions.alias(alias, collection, create=False, read=False, ...)
Permissions.data(collection, tenant=None, create=False, read=False, ...)
Permissions.collections(collection, create_collection=False, read_config=False, ...)
Permissions.tenants(collection, tenant=None, create=False, read=False, ...)
Permissions.replicate(collection, shard=None, create=False, ...)
Permissions.roles(role, create=False, read=False, ..., scope=None)
Permissions.users(user, create=False, ..., assign_and_revoke=False)
Permissions.backup(collection, manage=False)
Permissions.cluster(read=False)
Permissions.Nodes.verbose(collection, read=False)
Permissions.Nodes.minimal(read=False)
Permissions.Groups.oidc(group, read=False, assign_and_revoke=False)
```

#### Role Output Structure:
```python
@dataclass
class Role:
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
```

### 2.2 Elixir Implementation

**Location:** `/lib/weaviate_ex/rbac/actions.ex`, `/lib/weaviate_ex/rbac/permissions.ex`

#### Permission Types (Actions module):
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

#### Permission Builders (Permissions module):
```elixir
Permissions.collections(collection, actions)
Permissions.data(collection, actions, opts \\ [])
Permissions.tenants(collection, actions, opts \\ [])
Permissions.roles(role, actions)
Permissions.users(user, actions)
Permissions.groups(group, actions)
Permissions.cluster(action \\ :read)
Permissions.nodes(verbosity \\ :minimal)
Permissions.backups(action \\ :manage)
Permissions.replicate(collection, actions)
Permissions.alias_permission(alias_name, actions)
```

#### Role Structure:
```elixir
defstruct [:name, permissions: []]
# Single flat list of Permission structs
```

### 2.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Permission categorization | Role contains 11 separate permission lists | Role contains single flat list | **HIGH** - Different data model |
| RoleScope support | `RoleScope.MATCH`, `RoleScope.ALL` for roles permissions | Not implemented | **HIGH** - Missing scope feature |
| Nodes verbosity with collection filter | `Permissions.Nodes.verbose(collection=...)` | `Permissions.nodes(verbosity)` - no collection | **MEDIUM** - Missing filter option |
| Groups with group_type | `_GroupsPermission` tracks `group_type: "oidc"` | No group type tracking | **MEDIUM** - Missing metadata |

### 2.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Boolean-based permission builder | `create=True, read=True, ...` style | Action list style `[:create, :read]` | **LOW** - Style difference |
| Multiple collection/tenant support | Accepts sequences for batch creation | Single value only | **LOW** - Convenience feature |
| Permission merging in Role | `_join_permissions()` consolidates | Not implemented | **LOW** - Optimization |
| Alias with collection filter | `Permissions.alias(alias, collection, ...)` | `alias_permission(alias_name, actions)` - no collection | **LOW** - Filter not used |

---

## 3. User Management

### 3.1 Python Implementation

**Location:** `/weaviate-python-client/weaviate/users/`

#### User Types:
```python
class UserTypes(str, Enum):
    DB_DYNAMIC = "db_user"
    DB_STATIC = "db_env_user"
    OIDC = "oidc"
```

#### User Structs:
- `OwnUser`: user_id, roles (Dict[str, Role]), groups
- `UserBase`: user_id, role_names, user_type
- `UserDB(UserBase)`: + active: bool
- `UserOIDC(UserBase)`: user_type defaults to OIDC

#### General Users API (`_UsersExecutor`):
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get current user | `get_my_user()` | `GET /users/own-info` |
| Get assigned roles (deprecated) | `get_assigned_roles(user_id)` | `GET /authz/users/{id}/roles` |
| Assign roles (deprecated) | `assign_roles(user_id, role_names)` | `POST /authz/users/{id}/assign` |
| Revoke roles (deprecated) | `revoke_roles(user_id, role_names)` | `POST /authz/users/{id}/revoke` |

#### DB Users API (`_UsersDBExecutor`):
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get assigned roles | `get_assigned_roles(user_id, include_permissions)` | `GET /authz/users/{id}/roles/db` |
| Assign roles | `assign_roles(user_id, role_names)` | `POST /authz/users/{id}/assign` |
| Revoke roles | `revoke_roles(user_id, role_names)` | `POST /authz/users/{id}/revoke` |
| Create user | `create(user_id)` | `POST /users/db/{id}` |
| Delete user | `delete(user_id)` | `DELETE /users/db/{id}` |
| Get user | `get(user_id)` | `GET /users/db/{id}` |
| List all | `list_all()` | `GET /users/db` |
| Rotate key | `rotate_key(user_id)` | `POST /users/db/{id}/rotate-key` |
| Activate | `activate(user_id)` | `POST /users/db/{id}/activate` |
| Deactivate | `deactivate(user_id, revoke_key)` | `POST /users/db/{id}/deactivate` |

#### OIDC Users API (`_UsersOIDCExecutor`):
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get assigned roles | `get_assigned_roles(user_id, include_permissions)` | `GET /authz/users/{id}/roles/oidc` |
| Assign roles | `assign_roles(user_id, role_names)` | `POST /authz/users/{id}/assign` |
| Revoke roles | `revoke_roles(user_id, role_names)` | `POST /authz/users/{id}/revoke` |

### 3.2 Elixir Implementation

**Location:** `/lib/weaviate_ex/api/users.ex`, `/lib/weaviate_ex/api/users/db.ex`, `/lib/weaviate_ex/api/users/oidc.ex`

#### User Types:
```elixir
@type user_type :: :db_user | :db_env_user | :oidc
```

#### User Structs:
- `User.DB`: user_id, api_key, active, roles
- `User.OIDC`: user_id, groups, roles
- `User.Own`: user_id, user_type, roles, groups

#### General Users API (`WeaviateEx.API.Users`):
| Operation | Function | Endpoint |
|-----------|----------|----------|
| Create user | `create/3` | `POST /v1/users` |
| Get user | `get/3` | `GET /v1/users/{id}` |
| Get current user | `get_my_user/2` | `GET /v1/users/own` |
| List all | `list_all/2` | `GET /v1/users` |
| Delete user | `delete/3` | `DELETE /v1/users/{id}` |
| Activate | `activate/3` | `POST /v1/users/{id}/activate` |
| Deactivate | `deactivate/3` | `POST /v1/users/{id}/deactivate` |
| Rotate key | `rotate_key/3` | `POST /v1/users/{id}/rotate-key` |
| Assign roles | `assign_roles/4` | `POST /v1/users/{id}/assign-roles` |
| Revoke roles | `revoke_roles/4` | `POST /v1/users/{id}/revoke-roles` |
| Get assigned roles | `get_assigned_roles/3` | `GET /v1/users/{id}/roles` |

#### DB Users API (`WeaviateEx.API.Users.DB`):
| Operation | Function | Endpoint |
|-----------|----------|----------|
| Create | `create/3` | `POST /v1/users` |
| Get | `get/3` | `GET /v1/users/{id}?user_type=db` |
| List | `list/2` | `GET /v1/users?user_type=db` |
| Delete | `delete/3` | `DELETE /v1/users/{id}?user_type=db` |
| Rotate API key | `rotate_api_key/3` | `POST /v1/users/{id}/rotate-key?user_type=db` |
| Assign roles | `assign_roles/4` | `POST /v1/users/{id}/assign-roles?user_type=db` |
| Revoke roles | `revoke_roles/4` | `POST /v1/users/{id}/revoke-roles?user_type=db` |
| Get roles | `get_roles/3` | `GET /v1/users/{id}/roles?user_type=db` |
| Activate | `activate/3` | `POST /v1/users/{id}/activate?user_type=db` |
| Deactivate | `deactivate/3` | `POST /v1/users/{id}/deactivate?user_type=db` |

#### OIDC Users API (`WeaviateEx.API.Users.OIDC`):
| Operation | Function | Endpoint |
|-----------|----------|----------|
| Get | `get/3` | `GET /v1/users/{id}?user_type=oidc` |
| List | `list/2` | `GET /v1/users?user_type=oidc` |
| Assign roles | `assign_roles/4` | `POST /v1/users/{id}/assign-roles?user_type=oidc` |
| Revoke roles | `revoke_roles/4` | `POST /v1/users/{id}/revoke-roles?user_type=oidc` |
| Get roles | `get_roles/3` | `GET /v1/users/{id}/roles?user_type=oidc` |

### 3.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| include_permissions option | `get_assigned_roles(include_permissions=True)` returns full Role objects | Only returns role names (strings) | **HIGH** - Missing permission details |
| Separate user type endpoints | Uses `/authz/users/{id}/roles/{user_type}` | Uses query param `?user_type=...` | **MEDIUM** - Different API pattern |
| revoke_key option on deactivate | `deactivate(user_id, revoke_key=True)` | No revoke_key option | **MEDIUM** - Missing feature |
| Roles as Dict[str, Role] | `get_my_user()` returns roles as dictionary with Role objects | Returns list of role name strings | **HIGH** - Less detail |

### 3.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| DB user path | `/users/db/{id}` | `/v1/users?user_type=db` | **LOW** - Different pattern |
| Deprecated methods | Marked with `@deprecated` | Not applicable | **LOW** |
| User.DB has dbUserType | Includes `dbUserType` field | Has `user_type` field | **LOW** - Naming difference |
| `username` vs `user_id` | Handles both in `get_my_user()` | Uses `userId` only | **LOW** - Compatibility |

---

## 4. Group Management

### 4.1 Python Implementation

**Location:** `/weaviate-python-client/weaviate/groups/`

#### Group Types:
```python
class GroupTypes(str, Enum):
    OIDC = "oidc"
```

#### Group Assignment:
```python
@dataclass
class GroupAssignment:
    group_id: str
    group_type: GroupTypes
```

#### Groups OIDC API (`_GroupsOIDCExecutor`):
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get assigned roles | `get_assigned_roles(group_id, include_permissions)` | `GET /authz/groups/{id}/roles/oidc` |
| Assign roles | `assign_roles(group_id, role_names)` | `POST /authz/groups/{id}/assign` |
| Revoke roles | `revoke_roles(group_id, role_names)` | `POST /authz/groups/{id}/revoke` |
| Get known group names | `get_known_group_names()` | `GET /authz/groups/oidc` |

### 4.2 Elixir Implementation

**Location:** `/lib/weaviate_ex/api/groups.ex`, `/lib/weaviate_ex/groups/group.ex`

#### Group Struct:
```elixir
defstruct [:name, roles: []]
```

#### Groups API (`WeaviateEx.API.Groups`):
| Operation | Function | Endpoint |
|-----------|----------|----------|
| List known groups | `list_known/2` | `GET /v1/authz/groups` |
| Get assigned roles | `get_assigned_roles/3` | `GET /v1/authz/groups/{id}/roles` |
| Assign roles | `assign_roles/4` | `POST /v1/authz/groups/{id}/assign-roles` |
| Revoke roles | `revoke_roles/4` | `POST /v1/authz/groups/{id}/revoke-roles` |

### 4.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| include_permissions option | `get_assigned_roles(include_permissions=True)` returns full Role objects | Only returns role names (strings) | **HIGH** - Missing permission details |
| Group type in API | Includes `groupType` in assign/revoke payloads | No group type tracking | **MEDIUM** - Missing metadata |
| Separate OIDC namespace | `client.groups.oidc` namespace | Single `API.Groups` module | **LOW** - Structural difference |

### 4.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Endpoint paths | `/authz/groups/oidc` for list | `/v1/authz/groups` | **LOW** - Different pattern |
| Assign endpoint | `/authz/groups/{id}/assign` | `/v1/authz/groups/{id}/assign-roles` | **LOW** - Naming difference |
| Revoke endpoint | `/authz/groups/{id}/revoke` | `/v1/authz/groups/{id}/revoke-roles` | **LOW** - Naming difference |

---

## 5. Role Assignment to Users/Groups

### 5.1 Python Implementation

Python provides hierarchical access:
- `client.users.db.assign_roles(user_id, roles)`
- `client.users.oidc.assign_roles(user_id, roles)`
- `client.groups.oidc.assign_roles(group_id, roles)`

Payload includes user type:
```python
payload = {"roles": roles, "userType": user_type}
```

### 5.2 Elixir Implementation

Elixir provides flat module access:
- `WeaviateEx.API.Users.DB.assign_roles(client, user_id, roles)`
- `WeaviateEx.API.Users.OIDC.assign_roles(client, user_id, roles)`
- `WeaviateEx.API.Groups.assign_roles(client, group_id, roles)`

Uses query parameters for type:
```elixir
path = "/v1/users/#{user_id}/assign-roles?user_type=db"
body = %{"roles" => role_names}
```

### 5.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| User type in payload | Sends `userType` in request body | Uses query parameter | **MEDIUM** - API compatibility |
| Role objects in response | Can return full Role objects with permissions | Returns role name strings only | **HIGH** - Less information |

### 5.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Client structure | `client.users.db`, `client.users.oidc` | Separate modules | **LOW** - Design choice |
| Single/list role support | Accepts `str | List[str]` for role_names | Accepts `[String.t()]` only | **LOW** - Convenience |

---

## 6. Permission Checking

### 6.1 Python Implementation

```python
# Check single permission (private method)
def __has_permission(self, permission: WeaviatePermission, role: str) -> bool:
    path = f"/authz/roles/{role}/has-permission"
    # POST permission, returns 200 if has, 404 if not

# Check multiple permissions (public method)
def has_permissions(self, permissions, role: str) -> bool:
    # For async: uses asyncio.gather for parallel checks
    # For sync: iterates sequentially
    return all(results)
```

**Key Features:**
- Individual permission checks per action
- Parallel execution in async mode
- Returns True only if ALL permissions are present

### 6.2 Elixir Implementation

```elixir
def has_permissions?(client, role_name, permissions, opts \\ []) do
  flat_permissions = Permissions.flatten(permissions)
  body = %{"permissions" => Enum.map(flat_permissions, &Permission.to_api/1)}
  path = "/v1/authz/roles/#{role_name}/has-permissions"

  case Client.request(client, :post, path, body, opts) do
    {:ok, %{"hasPermission" => has}} -> {:ok, has}
    {:ok, _} -> {:ok, false}
    {:error, error} -> {:error, error}
  end
end
```

**Key Features:**
- Single request with all permissions
- Parses `hasPermission` from response
- No parallel execution

### 6.3 Critical Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Endpoint name | `/authz/roles/{name}/has-permission` (singular) | `/v1/authz/roles/{name}/has-permissions` (plural) | **MEDIUM** - API compatibility |
| Request pattern | One request per permission | Single request with all permissions | **MEDIUM** - Different API usage |
| Response format | Status code based (200/404) | JSON body based (`hasPermission` field) | **LOW** - Different parsing |

### 6.4 Minor Gaps

| Gap | Python | Elixir | Impact |
|-----|--------|--------|--------|
| Parallel checks | `asyncio.gather()` in async mode | No parallel support | **LOW** - Performance |
| ALL vs ANY semantics | Explicitly returns `all(results)` | Server determines semantics | **LOW** - Server-side logic |

---

## 7. API Differences Summary

### 7.1 Endpoint Path Patterns

| Resource | Python Pattern | Elixir Pattern |
|----------|---------------|----------------|
| Role operations | `/authz/roles/...` | `/v1/authz/roles/...` |
| User operations | `/users/db/{id}`, `/authz/users/{id}/roles/{type}` | `/v1/users/{id}?user_type=...` |
| Group operations | `/authz/groups/{id}/assign`, `/authz/groups/oidc` | `/v1/authz/groups/{id}/assign-roles` |
| Permission check | `/authz/roles/{name}/has-permission` | `/v1/authz/roles/{name}/has-permissions` |

### 7.2 Request/Response Patterns

| Aspect | Python | Elixir |
|--------|--------|--------|
| User type in request | Body payload `userType` field | Query parameter `?user_type=` |
| Roles in response | Full `Role` objects with permissions | Role name strings or basic info |
| Permission input | Boolean flags (`create=True`) | Action lists (`[:create, :read]`) |
| API version prefix | Optional, often omitted | Always includes `/v1` |

### 7.3 Data Structure Differences

| Structure | Python | Elixir |
|-----------|--------|--------|
| Role permissions | 11 separate categorized lists | Single flat list |
| User assignment | `UserAssignment{user_id, user_type}` | String (user_id only) |
| Group assignment | `GroupAssignment{group_id, group_type}` | String (group_id only) |
| Permission output | Type-specific classes (e.g., `DataPermissionOutput`) | Generic `Permission` struct |

---

## 8. Implementation Recommendations

### 8.1 High Priority (Critical Gaps)

1. **User/Group Assignments with Type Information**
   - Add `get_user_assignments/3` returning `{user_id, user_type}` tuples
   - Add `get_group_assignments/3` returning `{group_id, group_type}` tuples
   - Use endpoint `/v1/authz/roles/{name}/user-assignments`

2. **Include Permissions Option**
   - Add `include_permissions: boolean()` option to:
     - `Users.DB.get_roles/4`
     - `Users.OIDC.get_roles/4`
     - `Groups.get_assigned_roles/4`
   - Return full `Role` structs when `include_permissions: true`

3. **Role Permission Categorization**
   - Consider adding categorized permission access to Role struct
   - Example: `role.data_permissions`, `role.collections_permissions`
   - Alternative: Add helper functions `Role.data_permissions(role)`

4. **RoleScope Support**
   - Add `RoleScope` module with `:match` and `:all` values
   - Include scope in roles permission builder
   - Example: `Permissions.roles("admin", [:read], scope: :match)`

### 8.2 Medium Priority (Functional Gaps)

1. **Deactivate with Key Revocation**
   - Add `revoke_key: boolean()` option to `Users.DB.deactivate/4`
   - Include in request body when true

2. **Nodes Permission with Collection Filter**
   - Update `Permissions.nodes/2` to accept collection filter
   - Example: `Permissions.nodes(:verbose, collection: "Article")`

3. **Group Type Tracking**
   - Add group_type to group permission and assignment payloads
   - Currently only OIDC is supported, but API uses the field

4. **Permission Check API Alignment**
   - Verify correct endpoint: singular vs plural
   - Consider supporting per-permission checks for compatibility

### 8.3 Low Priority (Style/Convenience)

1. **Boolean Permission Builders**
   - Add optional boolean-style builders for API parity
   - Example: `Permissions.data("Article", create: true, read: true)`

2. **Multiple Collection/Tenant Support**
   - Allow lists in permission builders
   - Example: `Permissions.data(["Article", "Author"], :read)`

3. **Permission Merging**
   - Add `Role.join_permissions/1` to consolidate same-resource permissions
   - Useful for cleaner role output

4. **Async/Parallel Support**
   - Consider Task-based parallel permission checking
   - Lower priority as single-request approach may be sufficient

---

## 9. File Reference

### Python Client Files
- `/weaviate-python-client/weaviate/rbac/models.py` - Permission types, actions, Role class
- `/weaviate-python-client/weaviate/rbac/executor.py` - Role CRUD operations
- `/weaviate-python-client/weaviate/rbac/sync.py` - Sync wrapper
- `/weaviate-python-client/weaviate/rbac/async_.py` - Async wrapper
- `/weaviate-python-client/weaviate/users/users.py` - User types and structs
- `/weaviate-python-client/weaviate/users/base.py` - User/OIDC/DB executors
- `/weaviate-python-client/weaviate/users/sync.py` - Sync wrappers
- `/weaviate-python-client/weaviate/groups/base.py` - Groups OIDC executor
- `/weaviate-python-client/weaviate/groups/sync.py` - Sync wrapper

### Elixir Port Files
- `/lib/weaviate_ex/api/rbac.ex` - Role CRUD operations
- `/lib/weaviate_ex/rbac/actions.ex` - Action type definitions
- `/lib/weaviate_ex/rbac/permission.ex` - Permission struct
- `/lib/weaviate_ex/rbac/permissions.ex` - Permission builders
- `/lib/weaviate_ex/rbac/role.ex` - Role struct
- `/lib/weaviate_ex/api/rbac/permission.ex` - Alternative permission module
- `/lib/weaviate_ex/api/rbac/scope.ex` - Permission scope
- `/lib/weaviate_ex/api/users.ex` - General user operations
- `/lib/weaviate_ex/api/users/db.ex` - DB user operations
- `/lib/weaviate_ex/api/users/oidc.ex` - OIDC user operations
- `/lib/weaviate_ex/users/user.ex` - User structs
- `/lib/weaviate_ex/api/groups.ex` - Group operations
- `/lib/weaviate_ex/groups/group.ex` - Group struct

---

## 10. Testing Recommendations

### Unit Tests Needed
1. Permission action string conversion (all action types)
2. Role serialization/deserialization with all permission categories
3. User type handling (db_user, db_env_user, oidc)
4. Group assignment with type information

### Integration Tests Needed
1. Full RBAC lifecycle (create role, assign to user, verify access, delete)
2. DB user lifecycle (create, activate, deactivate, rotate key, delete)
3. OIDC user role management
4. Group role assignment and verification
5. Permission checking with various permission combinations

### Edge Cases to Test
1. Empty permissions list in role
2. Wildcard permissions (`*`)
3. Multiple actions on same resource
4. Nested permission lists flattening
5. User type detection from API responses
