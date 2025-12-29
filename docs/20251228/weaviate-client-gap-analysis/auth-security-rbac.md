# Authentication, Security & RBAC Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client Authentication, Security, and RBAC coverage.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/auth.py`, `weaviate/rbac/`, `weaviate/users/`, `weaviate/groups/`
**Elixir Files Analyzed:** `lib/weaviate_ex/auth.ex`

---

## Executive Summary

The Elixir client has **basic authentication** implemented but is **missing the entire RBAC, User Management, and Group Management modules** present in the Python client. This represents approximately **30+ missing features**.

---

## Authentication Methods

| Method | Python | Elixir | Status |
|--------|--------|--------|--------|
| API Key | `Auth.api_key()` | `Auth.api_key/1` | ✅ Full |
| Bearer Token | `Auth.bearer_token()` | `Auth.bearer_token/2` | ✅ Full |
| Client Credentials (OIDC) | `Auth.client_credentials()` | `Auth.client_credentials/3` | ✅ Full |
| Password Flow (OIDC) | `Auth.client_password()` | `Auth.client_password/3` | ✅ Full |
| OIDC Config Discovery | `connect/v4.py:374-476` | ❌ Not implemented | Gap |
| Token Endpoint Management | `connect/authentication.py` | ❌ Not implemented | Gap |
| Token Refresh | Automatic | ❌ Not implemented | Gap |
| Scope Management | Auto-injection + merge | ⚠️ Basic list only | Partial |

### Python Auth Implementation
```python
Auth.api_key(api_key: str)
Auth.bearer_token(access_token, expires_in=60, refresh_token=None)
Auth.client_credentials(client_secret, scope=None)
Auth.client_password(username, password, scope=None)
```

### Elixir Auth Implementation
```elixir
Auth.api_key(key)
Auth.bearer_token(token, opts \\ [])
Auth.client_credentials(client_id, client_secret, opts \\ [])
Auth.client_password(username, password, opts \\ [])
```

---

## User Management (ENTIRELY MISSING IN ELIXIR)

### Python User Operations (`weaviate/users/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| Create user | `users.db.create(user_id)` → returns API key | ❌ Missing |
| Get user info | `users.db.get(user_id)` → `UserDB` | ❌ Missing |
| Get current user | `users.get_my_user()` → `OwnUser` | ❌ Missing |
| List all users | `users.db.list_all()` → `List[UserDB]` | ❌ Missing |
| Delete user | `users.db.delete(user_id)` → bool | ❌ Missing |
| Activate user | `users.db.activate(user_id)` → bool | ❌ Missing |
| Deactivate user | `users.db.deactivate(user_id)` → bool | ❌ Missing |
| Rotate API key | `users.db.rotate_key(user_id)` → str | ❌ Missing |
| Assign roles | `users.db.assign_roles(user_id, role_names)` | ❌ Missing |
| Revoke roles | `users.db.revoke_roles(user_id, role_names)` | ❌ Missing |
| Get assigned roles | `users.db.get_assigned_roles(user_id)` | ❌ Missing |

### User Types
```python
class UserTypes(str, Enum):
    DB_DYNAMIC = "db_user"
    DB_STATIC = "db_env_user"
    OIDC = "oidc"
```
**Elixir Status**: ❌ Not implemented

---

## Group Management (ENTIRELY MISSING IN ELIXIR)

### Python Group Operations (`weaviate/groups/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| Get group roles | `groups.oidc.get_assigned_roles(group_id)` | ❌ Missing |
| Assign roles to group | `groups.oidc.assign_roles(group_id, role_names)` | ❌ Missing |
| Revoke roles from group | `groups.oidc.revoke_roles(group_id, role_names)` | ❌ Missing |
| Get known group names | `groups.oidc.get_known_group_names()` | ❌ Missing |

### Group Types
```python
class GroupTypes(str, Enum):
    OIDC = "oidc"
```
**Elixir Status**: ❌ Not implemented

---

## Role-Based Access Control (ENTIRELY MISSING IN ELIXIR)

### Python RBAC Operations (`weaviate/rbac/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| List all roles | `rbac.list_all()` | ❌ Missing |
| Check role exists | `rbac.exists(role_name)` | ❌ Missing |
| Get role details | `rbac.get(role_name)` | ❌ Missing |
| Create role | `rbac.create(role_name, permissions)` | ❌ Missing |
| Delete role | `rbac.delete(role_name)` | ❌ Missing |
| Add permissions | `rbac.add_permissions(role_name, permissions)` | ❌ Missing |
| Remove permissions | `rbac.remove_permissions(role_name, permissions)` | ❌ Missing |
| Check permissions | `rbac.has_permissions(role_name, permissions)` | ❌ Missing |
| Get user assignments | `rbac.get_user_assignments(role_name)` | ❌ Missing |
| Get group assignments | `rbac.get_group_assignments(role_name)` | ❌ Missing |

### Permission Action Types

| Action Type | Actions | Elixir Status |
|-------------|---------|---------------|
| `AliasAction` | CREATE, READ, UPDATE, DELETE | ❌ Missing |
| `CollectionsAction` | CREATE, READ, UPDATE, DELETE, MANAGE | ❌ Missing |
| `TenantsAction` | CREATE, READ, UPDATE, DELETE | ❌ Missing |
| `DataAction` | CREATE, READ, UPDATE, DELETE, MANAGE | ❌ Missing |
| `RolesAction` | CREATE, READ, UPDATE, DELETE | ❌ Missing |
| `UsersAction` | CREATE, READ, UPDATE, DELETE, ASSIGN_AND_REVOKE | ❌ Missing |
| `GroupAction` | READ, ASSIGN_AND_REVOKE | ❌ Missing |
| `ClusterAction` | READ | ❌ Missing |
| `NodesAction` | READ | ❌ Missing |
| `BackupsAction` | MANAGE | ❌ Missing |
| `ReplicateAction` | CREATE, READ, UPDATE, DELETE | ❌ Missing |

### Permissions Builder API
```python
Permissions.alias(...)
Permissions.data(collection, tenant=..., ...)
Permissions.collections(...)
Permissions.tenants(...)
Permissions.replicate(...)
Permissions.roles(...)
Permissions.users(...)
Permissions.backup(...)
Permissions.cluster(...)
Permissions.Nodes.verbose() / Permissions.Nodes.minimal()
Permissions.Groups.oidc(...)
```
**Elixir Status**: ❌ Entirely missing

---

## Summary Table

| Category | Python Features | Elixir Features | Gap |
|----------|-----------------|-----------------|-----|
| **Authentication** | | | |
| API Key | ✅ | ✅ | Full |
| Bearer Token | ✅ | ✅ | Full |
| Client Credentials | ✅ | ✅ | Full |
| Password Flow | ✅ | ✅ | Full |
| OIDC Discovery | ✅ | ❌ | Missing |
| Token Refresh | ✅ | ❌ | Missing |
| **User Management** | | | |
| Create/Delete User | ✅ | ❌ | Missing |
| Activate/Deactivate | ✅ | ❌ | Missing |
| List/Get Users | ✅ | ❌ | Missing |
| Rotate API Key | ✅ | ❌ | Missing |
| User Role Assignment | ✅ | ❌ | Missing |
| **Group Management** | | | |
| Get/Assign/Revoke Roles | ✅ | ❌ | Missing |
| Known Group Names | ✅ | ❌ | Missing |
| **RBAC** | | | |
| Role CRUD | ✅ | ❌ | Missing |
| Permission Management | ✅ | ❌ | Missing |
| Permission Checking | ✅ | ❌ | Missing |
| 11 Permission Types | ✅ | ❌ | Missing |
| Permissions Builder | ✅ | ❌ | Missing |

---

## Recommended Elixir Modules to Create

```
lib/weaviate_ex/
├── rbac/
│   ├── models.ex         # Role, Permission, Action definitions
│   ├── permissions.ex    # Permission builder API
│   └── manager.ex        # RBAC operations
├── users/
│   ├── models.ex         # User, UserDB, UserOIDC definitions
│   └── manager.ex        # User management operations
├── groups/
│   ├── models.ex         # Group definitions
│   └── manager.ex        # Group management operations
└── auth/
    ├── oidc_config.ex    # OIDC discovery & config
    └── token_manager.ex  # Token refresh & management
```

---

## Recommendations

### High Priority (Critical for Production)
1. **OIDC Configuration Discovery** - Fetch and cache OIDC config from server
2. **Token Refresh Handling** - Automatic token refresh for OAuth flows
3. **User Management API** - User CRUD, lifecycle, API key operations

### Medium Priority
4. **RBAC Core** - Role CRUD, permission management
5. **Group Management** - Group role assignments
6. **Permissions Builder** - Type-safe permission construction

### Low Priority
7. **Enhanced Scope Management** - Auto-injection and merging
8. **Provider-Specific Auth** - Azure-specific scope handling
