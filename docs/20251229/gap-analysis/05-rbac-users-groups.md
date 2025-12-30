# Gap Analysis: RBAC, Users, and Groups

## Executive Summary

This document provides a comprehensive gap analysis between the Python Weaviate client's RBAC (Role-Based Access Control), Users, and Groups functionality and the Elixir port (WeaviateEx). The analysis identifies significant architectural differences, missing features, and implementation gaps that need to be addressed for feature parity.

### Overall Assessment

| Module | Python Coverage | Elixir Coverage | Gap Level |
|--------|----------------|-----------------|-----------|
| RBAC Roles | Full | Partial | **Medium** |
| Permissions | Full | Partial | **Medium** |
| Users (General) | Full | Partial | **High** |
| Users (DB) | Full | Partial | **Medium** |
| Users (OIDC) | Full | Partial | **Medium** |
| Groups (OIDC) | Full | Partial | **High** |

**Key Findings:**
1. The Elixir port is missing the **hierarchical client structure** (`.db`, `.oidc` sub-namespaces)
2. Missing **user type parameters** on API endpoints
3. Missing **user assignment endpoints** on roles
4. Missing **`include_permissions` parameter** for role queries
5. Missing **role scope** functionality (match vs all)
6. Incomplete **permission model** (missing structured output types)

---

## 1. Role Management

### 1.1 Feature Comparison Table

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| List all roles | `roles.list_all()` | `RBAC.list_roles/2` | None |
| Get role by name | `roles.get(name)` | `RBAC.get_role/3` | None |
| Check role exists | `roles.exists(name)` | `RBAC.exists?/3` | None |
| Create role | `roles.create(name, permissions)` | `RBAC.create_role/4` | None |
| Delete role | `roles.delete(name)` | `RBAC.delete_role/3` | None |
| Add permissions | `roles.add_permissions(permissions, role_name)` | `RBAC.add_permissions/4` | None |
| Remove permissions | `roles.remove_permissions(permissions, role_name)` | `RBAC.remove_permissions/4` | None |
| Check has permissions | `roles.has_permissions(permissions, role)` | `RBAC.has_permissions?/4` | **Different API** |
| Get current user roles | `roles.get_current_roles()` | Missing | **Gap** |
| Get user assignments | `roles.get_user_assignments(role_name)` | Missing | **Critical Gap** |
| Get group assignments | `roles.get_group_assignments(role_name)` | Missing | **Critical Gap** |
| Get assigned user IDs (deprecated) | `roles.get_assigned_user_ids(role_name)` | `RBAC.get_users_for_role/3` | Partial (deprecated) |
| Get groups for role | N/A (use group_assignments) | `RBAC.get_groups_for_role/3` | Partial |

### 1.2 Detailed Gaps

#### Missing: User Assignments with Type Information

**Python:**
```python
# Returns List[UserAssignment] with user_id and user_type
assignments = client.roles.get_user_assignments("editor")
for assignment in assignments:
    print(f"User: {assignment.user_id}, Type: {assignment.user_type}")
    # user_type is UserTypes enum: DB_DYNAMIC, DB_STATIC, OIDC
```

**Elixir (Missing):**
```elixir
# Only returns list of user IDs (deprecated endpoint)
{:ok, user_ids} = RBAC.get_users_for_role(client, "editor")
# No type information available
```

**Required Implementation:**
```elixir
# New endpoint needed
@spec get_user_assignments(Client.t(), String.t(), opts()) ::
        {:ok, [UserAssignment.t()]} | {:error, Error.t()}
def get_user_assignments(client, role_name, opts \\ []) do
  path = "/v1/authz/roles/#{URI.encode_www_form(role_name)}/user-assignments"
  # Returns: [%{user_id: "...", user_type: :db_dynamic | :db_static | :oidc}]
end
```

#### Missing: Group Assignments with Type Information

**Python:**
```python
# Returns List[GroupAssignment] with group_id and group_type
assignments = client.roles.get_group_assignments("viewer")
for assignment in assignments:
    print(f"Group: {assignment.group_id}, Type: {assignment.group_type}")
    # group_type is GroupTypes enum: OIDC
```

**Elixir (Missing):**
```elixir
# Only returns list of group names
{:ok, groups} = RBAC.get_groups_for_role(client, "viewer")
# No type information available
```

---

## 2. Permission Structures and Scopes

### 2.1 Feature Comparison Table

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Collections permissions | `Permissions.collections(...)` | `Permissions.collections/2` | Partial |
| Data permissions | `Permissions.data(...)` | `Permissions.data/3` | Partial |
| Tenants permissions | `Permissions.tenants(...)` | `Permissions.tenants/3` | Partial |
| Roles permissions | `Permissions.roles(...)` | `Permissions.roles/3` | Partial |
| Users permissions | `Permissions.users(...)` | `Permissions.users/2` | Partial |
| Groups permissions | `Permissions.Groups.oidc(...)` | `Permissions.groups/2` | **Different API** |
| Nodes permissions (verbose) | `Permissions.Nodes.verbose(...)` | `Permissions.nodes(:verbose)` | **Different API** |
| Nodes permissions (minimal) | `Permissions.Nodes.minimal(...)` | `Permissions.nodes(:minimal)` | **Different API** |
| Backups permissions | `Permissions.backup(...)` | `Permissions.backups/1` | Partial |
| Cluster permissions | `Permissions.cluster(...)` | `Permissions.cluster/1` | None |
| Replicate permissions | `Permissions.replicate(...)` | `Permissions.replicate/2` | Partial |
| Alias permissions | `Permissions.alias(...)` | `Permissions.alias_permission/2` | Partial |
| Role scope (match/all) | `RoleScope.MATCH, RoleScope.ALL` | `:match, :all` (in opts) | **Different representation** |

### 2.2 Permission Action Enums

**Python Actions:**
```python
class AliasAction(str, Enum):
    CREATE = "create_aliases"
    READ = "read_aliases"
    UPDATE = "update_aliases"
    DELETE = "delete_aliases"

class CollectionsAction(str, Enum):
    CREATE = "create_collections"
    READ = "read_collections"
    UPDATE = "update_collections"
    DELETE = "delete_collections"
    MANAGE = "manage_collections"

class DataAction(str, Enum):
    CREATE = "create_data"
    READ = "read_data"
    UPDATE = "update_data"
    DELETE = "delete_data"
    MANAGE = "manage_data"

class RolesAction(str, Enum):
    MANAGE = "manage_roles"  # deprecated
    CREATE = "create_roles"
    READ = "read_roles"
    UPDATE = "update_roles"
    DELETE = "delete_roles"

class GroupAction(str, Enum):
    READ = "read_groups"
    ASSIGN_AND_REVOKE = "assign_and_revoke_groups"

class UsersAction(str, Enum):
    CREATE = "create_users"
    READ = "read_users"
    UPDATE = "update_users"
    DELETE = "delete_users"
    ASSIGN_AND_REVOKE = "assign_and_revoke_users"

# etc...
```

**Elixir Actions:**
```elixir
# Defined in WeaviateEx.RBAC.Actions
@actions_by_type %{
  collections: [:create, :read, :update, :delete, :manage],
  data: [:create, :read, :update, :delete, :manage],
  tenants: [:create, :read, :update, :delete],
  roles: [:create, :read, :update, :delete],  # Missing :manage (deprecated)
  users: [:create, :read, :update, :delete, :assign_and_revoke],
  groups: [:read, :assign_and_revoke],
  cluster: [:read],
  nodes: [:read],
  backups: [:manage],
  replicate: [:create, :read, :update, :delete],
  alias: [:create, :read, :update, :delete]
}
```

### 2.3 Detailed Gaps

#### Groups Permissions API Difference

**Python (uses nested namespace):**
```python
# Groups permissions use a special Permissions.Groups.oidc() method
permissions = Permissions.Groups.oidc(
    group="MyGroup",
    read=True,
    assign_and_revoke=True
)
```

**Elixir (flat API):**
```elixir
# Elixir uses a flat structure
permissions = Permissions.groups("MyGroup", [:read, :assign_and_revoke])
```

**Gap:** The Elixir implementation lacks the OIDC-specific group type specification that Python provides through `Permissions.Groups.oidc()`.

#### Nodes Permissions API Difference

**Python:**
```python
# Verbose nodes - requires collection
Permissions.Nodes.verbose(collection="Test", read=True)

# Minimal nodes - no collection needed
Permissions.Nodes.minimal(read=True)
```

**Elixir:**
```elixir
# Single function with verbosity atom
Permissions.nodes(:verbose)  # No collection support
Permissions.nodes(:minimal)
```

**Gap:** Elixir nodes permissions lack collection filtering capability.

#### Missing: Structured Permission Output Types

**Python has separate output types for each permission category:**
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

**Elixir has flat structure:**
```elixir
defstruct [:name, permissions: []]
# All permissions are just Permission structs
```

**Gap:** Elixir doesn't categorize permissions by type in the Role structure, making it harder to query specific permission types.

---

## 3. User Management

### 3.1 Feature Comparison Table

| Feature | Python Location | Elixir Location | Gap |
|---------|-----------------|-----------------|-----|
| Get current user | `users.get_my_user()` | `Users.get_my_user/2` | **Path difference** |
| Assign roles (deprecated) | `users.assign_roles(user_id, roles)` | `Users.assign_roles/4` | None |
| Revoke roles (deprecated) | `users.revoke_roles(user_id, roles)` | `Users.revoke_roles/4` | None |
| Get assigned roles (deprecated) | `users.get_assigned_roles(user_id)` | `Users.get_assigned_roles/3` | None |

### 3.2 DB Users Feature Comparison

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Create user | `users.db.create(user_id)` | `Users.DB.create/3` | Partial |
| Get user | `users.db.get(user_id)` | `Users.DB.get/3` | **Path difference** |
| List all DB users | `users.db.list_all()` | `Users.DB.list/2` | **Path difference** |
| Delete user | `users.db.delete(user_id)` | `Users.DB.delete/3` | **Path difference** |
| Rotate API key | `users.db.rotate_key(user_id)` | `Users.DB.rotate_api_key/3` | **Path difference** |
| Activate user | `users.db.activate(user_id)` | `Users.DB.activate/3` | **Path difference** |
| Deactivate user | `users.db.deactivate(user_id, revoke_key)` | `Users.DB.deactivate/3` | **Missing revoke_key** |
| Assign roles | `users.db.assign_roles(user_id, roles)` | `Users.DB.assign_roles/4` | **Path difference** |
| Revoke roles | `users.db.revoke_roles(user_id, roles)` | `Users.DB.revoke_roles/4` | **Path difference** |
| Get assigned roles | `users.db.get_assigned_roles(user_id, include_permissions)` | `Users.DB.get_roles/3` | **Missing include_permissions** |

### 3.3 OIDC Users Feature Comparison

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Get user | `users.oidc.get_assigned_roles(user_id)` | `Users.OIDC.get/3` | **Different semantics** |
| Assign roles | `users.oidc.assign_roles(user_id, roles)` | `Users.OIDC.assign_roles/4` | **Path difference** |
| Revoke roles | `users.oidc.revoke_roles(user_id, roles)` | `Users.OIDC.revoke_roles/4` | **Path difference** |
| Get assigned roles | `users.oidc.get_assigned_roles(user_id, include_permissions)` | `Users.OIDC.get_roles/3` | **Missing include_permissions** |
| List OIDC users | N/A (not in Python) | `Users.OIDC.list/2` | Extra in Elixir |

### 3.4 Detailed Gaps

#### API Path Differences

**Python uses user_type query parameter:**
```python
# Python endpoints use userType in body or query
path = f"/users/db/{user_id}"  # For DB users
path = f"/authz/users/{user_id}/roles/db"  # For DB user roles
path = f"/authz/users/{user_id}/roles/oidc"  # For OIDC user roles
```

**Elixir uses different path patterns:**
```elixir
# Elixir endpoints
"/v1/users/#{user_id}?user_type=db"
"/v1/users/#{user_id}/roles?user_type=db"
```

**Gap:** The API paths in Elixir don't match the Python client's expected Weaviate API structure. This may cause compatibility issues.

#### Missing: include_permissions Parameter

**Python:**
```python
# Can optionally include full role permissions
roles_base = client.users.db.get_assigned_roles(user_id="admin")
# Returns Dict[str, RoleBase] - just names

roles_full = client.users.db.get_assigned_roles(
    user_id="admin",
    include_permissions=True
)
# Returns Dict[str, Role] - with full permissions
```

**Elixir:**
```elixir
# Only returns role names
{:ok, role_names} = Users.DB.get_roles(client, "admin")
# No option to include full permissions
```

#### Missing: Deactivate with revoke_key Option

**Python:**
```python
# Can optionally revoke the API key during deactivation
client.users.db.deactivate(user_id="john", revoke_key=True)
```

**Elixir:**
```elixir
# No revoke_key option
:ok = Users.DB.deactivate(client, "john")
```

#### Missing: User Types Enum

**Python has explicit UserTypes enum:**
```python
class UserTypes(str, Enum):
    DB_DYNAMIC = "db_user"
    DB_STATIC = "db_env_user"
    OIDC = "oidc"
```

**Elixir:**
```elixir
# Uses atoms but not formally defined as a type
@type user_type :: :db_user | :db_env_user | :oidc
```

---

## 4. Group Management

### 4.1 Feature Comparison Table

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Get known group names | `groups.oidc.get_known_group_names()` | `Groups.list_known/2` | **Path difference** |
| Assign roles to group | `groups.oidc.assign_roles(group_id, roles)` | `Groups.assign_roles/4` | **Path difference** |
| Revoke roles from group | `groups.oidc.revoke_roles(group_id, roles)` | `Groups.revoke_roles/4` | **Path difference** |
| Get assigned roles | `groups.oidc.get_assigned_roles(group_id, include_permissions)` | `Groups.get_assigned_roles/3` | **Missing include_permissions** |

### 4.2 Detailed Gaps

#### API Structure Difference

**Python has nested OIDC namespace:**
```python
# Access via groups.oidc.*
client.groups.oidc.assign_roles(group_id="engineers", role_names=["dev"])
client.groups.oidc.get_known_group_names()
```

**Elixir has flat structure:**
```elixir
# Direct access
Groups.assign_roles(client, "engineers", ["dev"])
Groups.list_known(client)
```

**Gap:** The Elixir implementation doesn't have the `.oidc` sub-namespace, which means it can't easily support other group types if they're added in the future.

#### Missing: include_permissions Parameter

**Python:**
```python
# Can optionally include full role permissions
roles_base = client.groups.oidc.get_assigned_roles(group_id="engineers")
# Returns Dict[str, RoleBase]

roles_full = client.groups.oidc.get_assigned_roles(
    group_id="engineers",
    include_permissions=True
)
# Returns Dict[str, Role] - with full permissions
```

**Elixir:**
```elixir
# Only returns role names
{:ok, role_names} = Groups.get_assigned_roles(client, "engineers")
# No option to include full permissions
```

#### Missing: Group Types Enum

**Python has explicit GroupTypes enum:**
```python
class GroupTypes(str, Enum):
    OIDC = "oidc"
```

**Elixir:** No equivalent type defined.

---

## 5. Role Assignments to Users/Groups

### 5.1 Assignment Flow Comparison

**Python Flow:**
```python
# Assign to DB user
client.users.db.assign_roles(user_id="john", role_names=["editor"])

# Assign to OIDC user
client.users.oidc.assign_roles(user_id="oauth@company.com", role_names=["viewer"])

# Assign to OIDC group
client.groups.oidc.assign_roles(group_id="engineers", role_names=["developer"])

# Query assignments from role perspective
user_assignments = client.roles.get_user_assignments("editor")
group_assignments = client.roles.get_group_assignments("developer")
```

**Elixir Flow:**
```elixir
# Assign to DB user
:ok = Users.DB.assign_roles(client, "john", ["editor"])

# Assign to OIDC user
:ok = Users.OIDC.assign_roles(client, "oauth@company.com", ["viewer"])

# Assign to group
:ok = Groups.assign_roles(client, "engineers", ["developer"])

# Query assignments from role perspective (MISSING)
# {:ok, user_assignments} = RBAC.get_user_assignments(client, "editor")  # Not implemented
# {:ok, group_assignments} = RBAC.get_group_assignments(client, "developer")  # Not implemented
```

---

## 6. Permission Checking

### 6.1 Comparison

**Python:**
```python
# Check if role has specific permissions
has = client.roles.has_permissions(
    permissions=Permissions.data("Article", read=True),
    role="editor"
)
# Returns bool

# Works with single permission, list, or output types
has = client.roles.has_permissions(
    permissions=[
        Permissions.data("Article", read=True),
        Permissions.collections("Article", read_config=True)
    ],
    role="editor"
)
```

**Elixir:**
```elixir
# Check if role has permissions
{:ok, has} = RBAC.has_permissions?(client, "editor", [
  Permissions.data("Article", :read),
  Permissions.collections("Article", :read)
])
```

**Gap:** The Python implementation makes individual API calls for each permission and combines results. Elixir sends all permissions in one request. The API behavior may differ.

---

## 7. API Completeness Summary

### 7.1 Missing Endpoints in Elixir

| Endpoint | Python | Elixir | Priority |
|----------|--------|--------|----------|
| `/authz/roles/{name}/user-assignments` | Yes | No | **High** |
| `/authz/roles/{name}/group-assignments` | Yes | No | **High** |
| `/users/own-info` | Yes | Different path | Medium |
| `/users/db/{id}` | Yes | Query param style | Medium |
| `/authz/groups/{type}` | Yes | Different path | Medium |

### 7.2 Missing Parameters in Elixir

| Endpoint | Parameter | Python | Elixir | Priority |
|----------|-----------|--------|--------|----------|
| Get user roles | `include_permissions` | Yes | No | **High** |
| Get group roles | `include_permissions` | Yes | No | **High** |
| Deactivate user | `revoke_key` | Yes | No | Medium |
| Nodes permission | `collection` | Yes | No | Medium |

---

## 8. Priority Recommendations

### Critical (P0) - Must Have for Feature Parity

1. **Implement `get_user_assignments/3`** - Add endpoint to get user assignments with type information
2. **Implement `get_group_assignments/3`** - Add endpoint to get group assignments with type information
3. **Add `include_permissions` parameter** - For both user and group role queries
4. **Fix API paths** - Ensure paths match Weaviate API specification

### High (P1) - Important for Complete Functionality

5. **Add `revoke_key` option to deactivate** - For DB users
6. **Add collection filter to nodes permissions** - For verbose mode
7. **Add structured permission output types** - Categorize permissions in Role struct
8. **Add OIDC sub-namespace for Groups** - For future extensibility

### Medium (P2) - Nice to Have

9. **Add UserTypes enum module** - Formal type definitions
10. **Add GroupTypes enum module** - Formal type definitions
11. **Add RoleScope type** - With proper validation
12. **Add RoleBase struct** - For when full permissions aren't needed

### Low (P3) - Future Consideration

13. **Async support** - Python has full async versions of all endpoints
14. **Permission joining** - Python automatically combines duplicate permissions
15. **Deprecation warnings** - Match Python's deprecation pattern

---

## Appendix A: File Locations

### Python Client

| Module | Files |
|--------|-------|
| RBAC | `weaviate/rbac/models.py`, `weaviate/rbac/executor.py`, `weaviate/rbac/sync.py`, `weaviate/rbac/async_.py` |
| Users | `weaviate/users/users.py`, `weaviate/users/base.py`, `weaviate/users/sync.py`, `weaviate/users/async_.py` |
| Groups | `weaviate/groups/base.py`, `weaviate/groups/sync.py`, `weaviate/groups/async_.py` |

### Elixir Port

| Module | Files |
|--------|-------|
| RBAC | `lib/weaviate_ex/api/rbac.ex`, `lib/weaviate_ex/rbac/role.ex`, `lib/weaviate_ex/rbac/permission.ex`, `lib/weaviate_ex/rbac/permissions.ex`, `lib/weaviate_ex/rbac/actions.ex` |
| Users | `lib/weaviate_ex/api/users.ex`, `lib/weaviate_ex/api/users/db.ex`, `lib/weaviate_ex/api/users/oidc.ex`, `lib/weaviate_ex/users/user.ex` |
| Groups | `lib/weaviate_ex/api/groups.ex`, `lib/weaviate_ex/groups/group.ex` |

---

## Appendix B: Code Examples

### Creating a Role with Permissions

**Python:**
```python
from weaviate.classes.rbac import Permissions, RoleScope

permissions = [
    Permissions.collections(collection="Article", read_config=True, update_config=True),
    Permissions.data(collection="Article", create=True, read=True, update=True),
    Permissions.tenants(collection="Article", create=True, read=True),
    Permissions.roles(role="*", read=True, scope=RoleScope.MATCH),
    Permissions.users(user="*", read=True),
    Permissions.Groups.oidc(group="*", read=True),
    Permissions.Nodes.verbose(collection="Article", read=True),
    Permissions.cluster(read=True),
    Permissions.backup(collection="*", manage=True),
]

client.roles.create(role_name="full-editor", permissions=permissions)
```

**Elixir:**
```elixir
alias WeaviateEx.RBAC.Permissions

permissions = [
  Permissions.collections("Article", [:read, :update]),
  Permissions.data("Article", [:create, :read, :update]),
  Permissions.tenants("Article", [:create, :read]),
  Permissions.roles(:all, :read, scope: :match),
  Permissions.users(:all, :read),
  Permissions.groups(:all, :read),
  Permissions.nodes(:verbose),  # No collection support
  Permissions.cluster(:read),
  Permissions.backups(:manage),
]

RBAC.create_role(client, "full-editor", permissions)
```

### Managing Users

**Python:**
```python
# Create DB user and get API key
api_key = client.users.db.create(user_id="john")

# Assign roles
client.users.db.assign_roles(user_id="john", role_names=["editor", "viewer"])

# Get roles with permissions
roles = client.users.db.get_assigned_roles(user_id="john", include_permissions=True)
for role_name, role in roles.items():
    print(f"Role: {role_name}")
    for perm in role.data_permissions:
        print(f"  Data: {perm.collection} - {perm.actions}")

# Deactivate with key revocation
client.users.db.deactivate(user_id="john", revoke_key=True)

# Rotate key and reactivate
client.users.db.activate(user_id="john")
new_key = client.users.db.rotate_key(user_id="john")
```

**Elixir:**
```elixir
# Create DB user and get API key
{:ok, %User.DB{api_key: api_key}} = Users.DB.create(client, "john")

# Assign roles
:ok = Users.DB.assign_roles(client, "john", ["editor", "viewer"])

# Get roles (names only - no include_permissions option)
{:ok, role_names} = Users.DB.get_roles(client, "john")

# Deactivate (no revoke_key option)
:ok = Users.DB.deactivate(client, "john")

# Rotate key and reactivate
:ok = Users.DB.activate(client, "john")
{:ok, new_key} = Users.DB.rotate_api_key(client, "john")
```

### Querying Role Assignments

**Python:**
```python
# Get all users assigned to a role
user_assignments = client.roles.get_user_assignments("editor")
for ua in user_assignments:
    print(f"User: {ua.user_id}, Type: {ua.user_type.value}")
    # Output: User: john, Type: db_user
    # Output: User: oauth@company.com, Type: oidc

# Get all groups assigned to a role
group_assignments = client.roles.get_group_assignments("developer")
for ga in group_assignments:
    print(f"Group: {ga.group_id}, Type: {ga.group_type.value}")
    # Output: Group: engineers, Type: oidc
```

**Elixir (Current - Limited):**
```elixir
# Only get user IDs (deprecated endpoint)
{:ok, user_ids} = RBAC.get_users_for_role(client, "editor")
# Returns: ["john", "oauth@company.com"]
# No type information!

# Only get group names
{:ok, group_names} = RBAC.get_groups_for_role(client, "developer")
# Returns: ["engineers"]
# No type information!
```

**Elixir (Needed Implementation):**
```elixir
# Should return structured assignments
{:ok, user_assignments} = RBAC.get_user_assignments(client, "editor")
# Returns: [%UserAssignment{user_id: "john", user_type: :db_user}, ...]

{:ok, group_assignments} = RBAC.get_group_assignments(client, "developer")
# Returns: [%GroupAssignment{group_id: "engineers", group_type: :oidc}]
```

---

*Document generated: 2025-12-29*
*Analysis based on: Python client v4.x, Elixir port WeaviateEx v0.7.x*
