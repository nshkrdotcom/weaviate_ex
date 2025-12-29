# RBAC, Users & Groups Gap Analysis

## Executive Summary

This analysis compares RBAC, Users, and Groups management between the Python client and the Elixir port.

**Overall Feature Parity: ~80%**

The Elixir port covers most essential RBAC functionality but lacks a few important features for complete parity, particularly around fetching permissions with role details.

## Feature Comparison Matrix

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List all roles | Yes | Yes | PARITY |
| Check role exists | Yes | Yes | PARITY |
| Get role by name | Yes | Yes | PARITY |
| Create/Delete role | Yes | Yes | PARITY |
| Add/Remove permissions | Yes | Yes | PARITY |
| Check permissions | Yes | Yes | PARITY |
| Get user assignments (detailed) | Yes | No | **GAP** |
| Get group assignments (detailed) | Yes | No | **GAP** |
| User CRUD | Yes | Yes | PARITY |
| Group role management | Yes | Yes | PARITY |
| Roles with full permissions | Yes | No | **GAP** |
| Role scope (MATCH/ALL) | Yes | No | **GAP** |

---

## 1. Role Management

### Python Implementation
```python
# All methods available
list_all()
exists(role_name)
get(role_name)
create(role_name, permissions)
delete(role_name)
add_permissions(role_name, permissions)  # Idempotent
remove_permissions(role_name, permissions)  # Idempotent
has_permissions(role_name, permissions)
get_user_assignments(role_name)  # Returns UserAssignment with user_type
get_group_assignments(role_name)  # Returns GroupAssignment with group_type
```

### Elixir Implementation
```elixir
list_roles(client)
exists?(client, role_name)
get_role(client, role_name)
create_role(client, role_name, permissions)
delete_role(client, role_name)
add_permissions(client, role_name, permissions)
remove_permissions(client, role_name, permissions)
has_permissions?(client, role_name, permissions)
get_users_for_role(client, role_name)    # Only returns IDs
get_groups_for_role(client, role_name)   # Only returns IDs
```

### Gap
- Python returns typed `UserAssignment`/`GroupAssignment` objects with user_type/group_type
- Elixir only returns string ID lists

---

## 2. Permission Definitions and Scopes

### Python Permission Types (11 types)
```python
AliasAction     - CREATE, READ, UPDATE, DELETE
CollectionsAction - CREATE, READ, UPDATE, DELETE, MANAGE
TenantsAction   - CREATE, READ, UPDATE, DELETE
DataAction      - CREATE, READ, UPDATE, DELETE, MANAGE
RolesAction     - CREATE, READ, UPDATE, DELETE
GroupAction     - READ, ASSIGN_AND_REVOKE
UsersAction     - CREATE, READ, UPDATE, DELETE, ASSIGN_AND_REVOKE
ClusterAction   - READ
NodesAction     - READ
BackupsAction   - MANAGE
ReplicateAction - CREATE, READ, UPDATE, DELETE
```

### Elixir Permission Types (11 types)
```elixir
collections: [:create, :read, :update, :delete, :manage]
data:        [:create, :read, :update, :delete, :manage]
tenants:     [:create, :read, :update, :delete]
roles:       [:create, :read, :update, :delete]
users:       [:create, :read, :update, :delete, :assign_and_revoke]
groups:      [:read, :assign_and_revoke]
cluster:     [:read]
nodes:       [:read]
backups:     [:manage]
replicate:   [:create, :read, :update, :delete]
alias:       [:create, :read, :update, :delete]
```

### Permission Filters
| Filter | Python | Elixir | Status |
|--------|--------|--------|--------|
| collection | Yes | Yes | PARITY |
| tenant | Yes | Yes | PARITY |
| role | Yes | Yes | PARITY |
| user | Yes | Yes | PARITY |
| group | Yes | Yes | PARITY |
| verbosity | Yes | Yes | PARITY |
| RoleScope (MATCH/ALL) | Yes | No | **GAP** |
| Group type | Yes | No | **GAP** |

---

## 3. User Management

### Python Features
```python
# DB Users
users.db.create(user_id)  # Returns API key
users.db.delete(user_id)
users.db.get(user_id)     # Returns UserDB with role_names, active, user_type
users.db.list_all()
users.db.rotate_key(user_id)
users.db.activate(user_id)
users.db.deactivate(user_id, revoke_key=False)
users.db.get_assigned_roles(user_id, include_permissions=False)  # Can get full Role objects
users.db.assign_roles(user_id, role_names)
users.db.revoke_roles(user_id, role_names)

# OIDC Users
users.oidc.get_assigned_roles(user_id, include_permissions=False)
users.oidc.assign_roles(user_id, role_names)
users.oidc.revoke_roles(user_id, role_names)

# Current user
get_my_user()  # Returns OwnUser with roles dict and groups list
```

### Elixir Features
```elixir
Users.create(client, user_id)       # Returns User.DB with api_key
Users.delete(client, user_id)
Users.get(client, user_id)          # Returns DB or OIDC user
Users.list_all(client)
Users.rotate_key(client, user_id)
Users.activate(client, user_id)
Users.deactivate(client, user_id)
Users.get_assigned_roles(client, user_id)  # Only returns role names
Users.assign_roles(client, user_id, role_names)
Users.revoke_roles(client, user_id, role_names)
Users.get_my_user(client)           # Returns User.Own
```

### Gap
- **Missing `include_permissions` parameter** - Cannot fetch full Role objects with permissions
- **No type-specific user managers** - Python has separate `users.db` and `users.oidc` executors

---

## 4. Group Management

### Python Features
```python
groups.oidc.get_assigned_roles(group_id, include_permissions=False)
groups.oidc.assign_roles(group_id, role_names)
groups.oidc.revoke_roles(group_id, role_names)
groups.oidc.get_known_group_names()
```

### Elixir Features
```elixir
Groups.list_known(client)
Groups.get_assigned_roles(client, group_id)  # Only returns role names
Groups.assign_roles(client, group_id, role_names)
Groups.revoke_roles(client, group_id, role_names)
```

### Gap
- **Missing `include_permissions` parameter**
- **No type-specific group managers**

---

## 5. Permission Checking

### Python
```python
roles.has_permissions(role_name, [permission1, permission2])
# Returns boolean
# Supports async/sync variants
```

### Elixir
```elixir
RBAC.has_permissions?(client, role_name, [permission1, permission2])
# Returns {:ok, boolean()}
```

### Status: PARITY (different return types by language convention)

---

## 6. Role Scope Support

### Python
```python
Permissions.roles("admin", read=True, scope=RoleScope.MATCH)
# RoleScope enum: MATCH, ALL
```

### Elixir
**NOT IMPLEMENTED**

### Gap: Cannot create role permissions with scope restrictions

---

## Summary of Critical Gaps

1. **Missing Role Details in Assignments (CRITICAL)**
   - Python: `get_user_assignments()` / `get_group_assignments()` return typed objects
   - Elixir: Only returns string IDs, no type information

2. **Missing Roles with Full Permissions (HIGH)**
   - Python: `include_permissions=True` returns full Role objects
   - Elixir: Only returns role names, must make additional API calls

3. **Missing Role Scope Support (MEDIUM)**
   - Python: `scope=RoleScope.MATCH` or `ALL`
   - Elixir: No scope parameter support

4. **Missing Group Type in Permissions (MEDIUM)**
   - Python: `Permissions.Groups.oidc()` with explicit group_type
   - Elixir: No group type distinction

---

## Implementation Recommendations

### High Priority

1. **Add `include_permissions` parameter**
   ```elixir
   Users.get_assigned_roles(client, user_id, include_permissions: true)
   Groups.get_assigned_roles(client, group_id, include_permissions: true)
   ```

2. **Enhance assignment methods to return typed objects**
   ```elixir
   RBAC.get_users_for_role(client, role_name)
   # Returns [%UserAssignment{user_id: String.t(), user_type: :db | :oidc}]
   ```

3. **Add RoleScope support**
   ```elixir
   Permissions.roles("admin", read: true, scope: :match)
   ```

### Medium Priority

4. **Add group type distinction in permission builder**
5. **Consider type-specific user/group manager modules**

---

## Conclusion

The Elixir RBAC implementation covers most essential functionality with good parity on core operations. The main gaps are around fetching roles with full permission details and type information in assignments. These are primarily convenience features that require additional API calls in Elixir but are provided directly in Python.
