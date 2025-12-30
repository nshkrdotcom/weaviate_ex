# Gap Analysis: Authentication and RBAC

## Executive Summary

This document provides a detailed comparison between the Weaviate Python client's authentication and RBAC (Role-Based Access Control) implementation and the WeaviateEx Elixir port. The Elixir implementation covers the core functionality but has some gaps in advanced features, particularly around role scope handling, user type differentiation, and some permission types.

**Overall Coverage: ~80%**

---

## 1. API Key Authentication

### Python Implementation

**File:** `/weaviate-python-client/weaviate/auth.py`

```python
@dataclass
class _APIKey:
    """Using the given API key to authenticate with weaviate."""
    api_key: str

class Auth:
    @staticmethod
    def api_key(api_key: str) -> _APIKey:
        return _APIKey(api_key)
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/auth.ex`

```elixir
@type api_key_auth :: %{
  type: :api_key,
  api_key: String.t()
}

@spec api_key(String.t()) :: api_key_auth()
def api_key(key) when is_binary(key) do
  %{
    type: :api_key,
    api_key: key
  }
end

def to_headers(%{type: :api_key, api_key: key}) do
  [{"Authorization", "Bearer #{key}"}]
end
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic API key auth | Yes | Yes | Complete |
| Header generation | Yes | Yes | Complete |
| Validation | Minimal | Minimal | Parity |

### Gap Analysis

**No gaps identified.** Both implementations provide equivalent API key authentication functionality.

---

## 2. OIDC Authentication

### Python Implementation

**Files:** `/weaviate-python-client/weaviate/auth.py`, `/weaviate-python-client/weaviate/connect/authentication.py`

```python
@dataclass
class _ClientCredentials:
    client_secret: str
    scope: Optional[SCOPES] = None

    def __post_init__(self) -> None:
        if self.scope is None:
            self.scope_list: List[str] = []
        elif isinstance(self.scope, str):
            self.scope_list = self.scope.split(" ")
        elif isinstance(self.scope, list):
            self.scope_list = self.scope

@dataclass
class _ClientPassword:
    username: str
    password: str
    scope: Optional[SCOPES] = None
```

The Python client uses `authlib` for OIDC handling:
- OAuth2Client for sync operations
- AsyncOAuth2Client for async operations
- Automatic token discovery via well-known endpoints
- Special handling for Azure/Microsoft endpoints

### Elixir Implementation

**Files:** `/lib/weaviate_ex/auth.ex`, `/lib/weaviate_ex/auth/oidc.ex`, `/lib/weaviate_ex/auth/azure.ex`

```elixir
@type client_credentials_auth :: %{
  type: :oidc_client_credentials,
  client_id: String.t(),
  client_secret: String.t(),
  scopes: [String.t()]
}

@type password_auth :: %{
  type: :oidc_password,
  username: String.t(),
  password: String.t(),
  client_id: String.t() | nil,
  client_secret: String.t() | nil,
  scopes: [String.t()]
}
```

The Elixir implementation includes:
- OIDC.discover/1 for well-known endpoint discovery
- OIDC.get_token/2 for token acquisition
- OIDC.refresh_token/2 for token refresh
- Azure-specific handling via `WeaviateEx.Auth.Azure` module

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Client Credentials grant | Yes | Yes | Complete |
| Password (ROPC) grant | Yes | Yes | Complete |
| OIDC Discovery | Yes | Yes | Complete |
| Token acquisition | Yes | Yes | Complete |
| Scope handling | Space/list | List | Complete |
| Azure special handling | Yes | Yes | Complete |
| Azure v1/v2 detection | Implicit | Explicit | Enhanced |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| Client ID extraction from OIDC config | Low | Python extracts client_id from OIDC config; Elixir requires explicit client_id |
| Default scopes from OIDC config | Low | Python reads default scopes from OIDC config response |

---

## 3. Bearer Token Authentication

### Python Implementation

```python
@dataclass
class _BearerToken:
    access_token: str
    expires_in: int = 60
    refresh_token: Optional[str] = None

    def __post_init__(self) -> None:
        if self.expires_in and self.expires_in < 0:
            _Warnings.auth_negative_expiration_time(self.expires_in)
```

### Elixir Implementation

```elixir
@type bearer_token_auth :: %{
  type: :bearer_token,
  access_token: String.t(),
  expires_in: integer() | nil,
  refresh_token: String.t() | nil
}

def bearer_token(token, opts \\ []) when is_binary(token) do
  %{
    type: :bearer_token,
    access_token: token,
    expires_in: Keyword.get(opts, :expires_in),
    refresh_token: Keyword.get(opts, :refresh_token)
  }
end
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Access token | Yes | Yes | Complete |
| Expiration time | Default 60s | Optional | Different defaults |
| Refresh token | Optional | Optional | Complete |
| Negative expiry warning | Yes | No | Missing |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| Warning for negative expiration | Very Low | Python warns about negative expiration times |
| Default expiration | Low | Python defaults to 60s; Elixir has no default |

---

## 4. Token Refresh Mechanisms

### Python Implementation

Token refresh is handled automatically by authlib's OAuth2Client:
- Tracks token expiration
- Automatically refreshes before expiry
- Falls back to re-authentication if refresh fails

### Elixir Implementation

**File:** `/lib/weaviate_ex/auth/token_manager.ex`

```elixir
defmodule WeaviateEx.Auth.TokenManager do
  use GenServer

  # Features:
  # - GenServer for token lifecycle management
  # - Automatic refresh before expiration
  # - Configurable refresh buffer (default 60s)
  # - Fallback to re-authentication
  # - Error recovery with retry logic

  def start_link(opts)
  def get_token(server)
  def get_access_token(server)
  def force_refresh(server)
end
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Automatic refresh | Yes (authlib) | Yes (GenServer) | Complete |
| Refresh buffer | Implicit | Configurable (60s default) | Enhanced |
| Force refresh | No | Yes | Enhanced |
| Thread/process safety | OAuth2Client | GenServer | Complete |
| Token state tracking | OAuth2Client | GenServer state | Complete |
| Expiration helpers | Basic | TokenResponse.expired?/1, expiring_soon?/2 | Enhanced |

### Gap Analysis

**No functional gaps.** The Elixir implementation is actually more feature-rich with explicit refresh control and configurable buffers.

---

## 5. RBAC - Role Management

### Python Implementation

**Files:** `/weaviate-python-client/weaviate/rbac/executor.py`, `/weaviate-python-client/weaviate/rbac/models.py`

```python
class _RolesExecutor:
    def list_all(self) -> Dict[str, Role]
    def get(self, role_name: str) -> Optional[Role]
    def exists(self, role_name: str) -> bool
    def create(self, *, role_name: str, permissions: PermissionsInputType) -> Role
    def delete(self, role_name: str) -> None
    def add_permissions(self, *, permissions: PermissionsInputType, role_name: str) -> None
    def remove_permissions(self, *, permissions: PermissionsInputType, role_name: str) -> None
    def has_permissions(self, *, permissions: ..., role: str) -> bool
    def get_user_assignments(self, role_name: str) -> List[UserAssignment]
    def get_group_assignments(self, role_name: str) -> List[GroupAssignment]
    def get_assigned_user_ids(self, role_name: str) -> List[str]  # deprecated
    def get_current_roles(self) -> List[Role]  # deprecated
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/api/rbac.ex`

```elixir
def list_roles(client, opts \\ [])
def get_role(client, role_name, opts \\ [])
def exists?(client, role_name, opts \\ [])
def create_role(client, role_name, permissions, opts \\ [])
def delete_role(client, role_name, opts \\ [])
def add_permissions(client, role_name, permissions, opts \\ [])
def remove_permissions(client, role_name, permissions, opts \\ [])
def has_permissions?(client, role_name, permissions, opts \\ [])
def get_users_for_role(client, role_name, opts \\ [])
def get_groups_for_role(client, role_name, opts \\ [])
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List all roles | Yes (returns Dict) | Yes (returns List) | Different structure |
| Get role by name | Yes | Yes | Complete |
| Check role exists | Yes | Yes | Complete |
| Create role | Yes | Yes | Complete |
| Delete role | Yes | Yes | Complete |
| Add permissions | Yes | Yes | Complete |
| Remove permissions | Yes | Yes | Complete |
| Has permissions | Yes | Yes | Complete |
| Get user assignments | Yes (with user_type) | Partial (IDs only) | Gap |
| Get group assignments | Yes (with group_type) | Partial (IDs only) | Gap |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| User assignments with type | Medium | Python returns `UserAssignment` with user_id and user_type; Elixir returns string list |
| Group assignments with type | Medium | Python returns `GroupAssignment` with group_id and group_type; Elixir returns string list |
| Role scope support | Medium | Python `RolesPermission` supports scope parameter (`RoleScope.MATCH`/`RoleScope.ALL`) |

---

## 6. RBAC - User Management

### Python Implementation

**Files:** `/weaviate-python-client/weaviate/users/base.py`, `/weaviate-python-client/weaviate/users/users.py`

The Python client has a sophisticated user management structure:

```python
class _Users:
    def __init__(self, connection):
        self.db = _UsersDB(connection)      # DB user operations
        self.oidc = _UsersOIDC(connection)  # OIDC user operations

    def get_my_user(self) -> OwnUser
    def get_assigned_roles(self, user_id: str) -> Dict[str, Role]  # deprecated
    def assign_roles(self, *, user_id: str, role_names: ...) -> None  # deprecated
    def revoke_roles(self, *, user_id: str, role_names: ...) -> None  # deprecated

class _UsersDBExecutor:
    def create(self, *, user_id: str) -> str  # returns API key
    def delete(self, *, user_id: str) -> bool
    def get(self, *, user_id: str) -> Optional[UserDB]
    def list_all(self) -> List[UserDB]
    def rotate_key(self, *, user_id: str) -> str
    def activate(self, *, user_id: str) -> bool
    def deactivate(self, *, user_id: str, revoke_key: bool = False) -> bool
    def get_assigned_roles(self, *, user_id: str, include_permissions: bool = False) -> Dict
    def assign_roles(self, *, user_id: str, role_names: ...) -> None
    def revoke_roles(self, *, user_id: str, role_names: ...) -> None

class _UsersOIDCExecutor:
    def get_assigned_roles(self, *, user_id: str, include_permissions: bool = False) -> Dict
    def assign_roles(self, *, user_id: str, role_names: ...) -> None
    def revoke_roles(self, *, user_id: str, role_names: ...) -> None
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/api/users.ex`

```elixir
def create(client, user_id, opts \\ [])
def get(client, user_id, opts \\ [])
def get_my_user(client, opts \\ [])
def list_all(client, opts \\ [])
def delete(client, user_id, opts \\ [])
def activate(client, user_id, opts \\ [])
def deactivate(client, user_id, opts \\ [])
def rotate_key(client, user_id, opts \\ [])
def assign_roles(client, user_id, role_names, opts \\ [])
def revoke_roles(client, user_id, role_names, opts \\ [])
def get_assigned_roles(client, user_id, opts \\ [])
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Get current user | Yes (OwnUser) | Yes (User.Own) | Complete |
| Create DB user | Yes | Yes | Complete |
| Delete user | Yes | Yes | Complete |
| Get user | Yes | Yes | Complete |
| List all users | Yes | Yes | Complete |
| Rotate API key | Yes | Yes | Complete |
| Activate user | Yes | Yes | Complete |
| Deactivate user | Yes (with revoke_key) | Partial (no revoke_key) | Gap |
| Assign roles | Yes | Yes | Complete |
| Revoke roles | Yes | Yes | Complete |
| Get assigned roles | Yes (include_permissions opt) | Partial (no opt) | Gap |
| User type separation | Yes (db/oidc namespaces) | No (single namespace) | Gap |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| DB/OIDC user type separation | High | Python separates `users.db.*` and `users.oidc.*` operations; Elixir has flat namespace |
| Deactivate with revoke_key | Low | Python supports `revoke_key: bool` parameter |
| Include permissions option | Low | Python's `get_assigned_roles` has `include_permissions` flag |
| User type in response | Medium | Python returns `user_type` field in user objects |

---

## 7. RBAC - Permission Management

### Python Implementation

**File:** `/weaviate-python-client/weaviate/rbac/models.py`

Python has extensive permission types:

```python
# Action Types
class AliasAction(Enum):
    CREATE, READ, UPDATE, DELETE

class CollectionsAction(Enum):
    CREATE, READ, UPDATE, DELETE, MANAGE

class DataAction(Enum):
    CREATE, READ, UPDATE, DELETE, MANAGE

class TenantsAction(Enum):
    CREATE, READ, UPDATE, DELETE

class RolesAction(Enum):
    MANAGE, CREATE, READ, UPDATE, DELETE

class UsersAction(Enum):
    CREATE, READ, UPDATE, DELETE, ASSIGN_AND_REVOKE

class GroupAction(Enum):
    READ, ASSIGN_AND_REVOKE

class ClusterAction(Enum):
    READ

class NodesAction(Enum):
    READ

class BackupsAction(Enum):
    MANAGE

class ReplicateAction(Enum):
    CREATE, READ, UPDATE, DELETE

# Permission Builders
class Permissions:
    @staticmethod def alias(*, alias, collection, create, read, update, delete)
    @staticmethod def data(*, collection, tenant, create, read, update, delete)
    @staticmethod def collections(*, collection, create_collection, read_config, update_config, delete_collection)
    @staticmethod def tenants(*, collection, tenant, create, read, update, delete)
    @staticmethod def roles(*, role, create, read, update, delete, scope)  # Note: scope parameter
    @staticmethod def users(*, user, create, read, update, delete, assign_and_revoke)
    @staticmethod def backup(*, collection, manage)
    @staticmethod def cluster(*, read)
    @staticmethod def replicate(*, collection, shard, create, read, update, delete)
    Nodes.verbose(*, collection, read)
    Nodes.minimal(*, read)
    Groups.oidc(*, group, read, assign_and_revoke)
```

### Elixir Implementation

**Files:** `/lib/weaviate_ex/rbac/permission.ex`, `/lib/weaviate_ex/rbac/permissions.ex`, `/lib/weaviate_ex/rbac/actions.ex`

```elixir
# Permission Types
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

# Permission Builders
def collections(collection, actions)
def data(collection, actions, opts \\ [])  # opts: tenant, object
def tenants(collection, actions, opts \\ [])  # opts: tenant
def roles(actions) / roles(role, actions)
def users(actions) / users(user, actions)
def groups(actions) / groups(group, actions)
def cluster(action \\ :read)
def nodes(verbosity \\ :minimal)
def backups(action \\ :manage)
def replicate(actions) / replicate(collection, actions)
def alias_permission(actions) / alias_permission(alias_name, actions)
```

### Comparison

| Permission Type | Python | Elixir | Status |
|-----------------|--------|--------|--------|
| Collections | Yes | Yes | Complete |
| Data | Yes (with tenant/object) | Yes (with tenant/object) | Complete |
| Tenants | Yes | Yes | Complete |
| Roles | Yes (with scope) | Partial (no scope) | Gap |
| Users | Yes | Yes | Complete |
| Groups | Yes (OIDC only) | Yes | Complete |
| Cluster | Yes | Yes | Complete |
| Nodes (minimal/verbose) | Yes | Yes | Complete |
| Backups | Yes | Yes | Complete |
| Replicate (with shard) | Yes | Partial (no shard) | Gap |
| Alias | Yes (with collection filter) | Partial (no filter) | Gap |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| Role scope parameter | Medium | Python supports `scope: RoleScope.MATCH/ALL` for role permissions |
| Replicate shard filter | Low | Python supports `shard` filter for replicate permissions |
| Alias collection filter | Low | Python supports `collection` filter for alias permissions |
| Permission output types | Low | Python has separate `*PermissionOutput` types for read permissions |

---

## 8. Groups Management

### Python Implementation

**File:** `/weaviate-python-client/weaviate/groups/base.py`

```python
class _Groups:
    def __init__(self, connection):
        self.oidc = _GroupsOIDC(connection)

class _GroupsOIDCExecutor:
    def get_assigned_roles(self, *, group_id: str, include_permissions: bool = False) -> Dict[str, Role|RoleBase]
    def assign_roles(self, *, group_id: str, role_names: Union[str, List[str]]) -> None
    def revoke_roles(self, *, group_id: str, role_names: Union[str, List[str]]) -> None
    def get_known_group_names(self) -> List[str]
```

### Elixir Implementation

**File:** `/lib/weaviate_ex/api/groups.ex`

```elixir
def list_known(client, opts \\ [])
def get_assigned_roles(client, group_id, opts \\ [])
def assign_roles(client, group_id, role_names, opts \\ [])
def revoke_roles(client, group_id, role_names, opts \\ [])
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List known groups | Yes | Yes | Complete |
| Get assigned roles | Yes (include_permissions opt) | Partial (no opt) | Gap |
| Assign roles | Yes | Yes | Complete |
| Revoke roles | Yes | Yes | Complete |
| OIDC namespace | Yes | No (flat) | Different structure |

### Gap Analysis

| Gap | Severity | Details |
|-----|----------|---------|
| Include permissions option | Low | Python allows requesting full role permissions |
| OIDC namespace | Low | Python uses `groups.oidc.*` namespace; Elixir is flat |

---

## Security Considerations

### Python Security Features

1. **Credential Validation**
   - Validates negative expiration times
   - Warns about missing refresh tokens
   - Validates Azure password flow requirements
   - Blocks unsupported grant types

2. **Token Management**
   - Uses authlib for secure OAuth handling
   - Automatic token refresh before expiry
   - Thread-safe session management

3. **API Key Handling**
   - Simple storage as dataclass field
   - No encryption at rest

### Elixir Security Features

1. **Credential Validation**
   - Azure password flow validation (WeaviateEx.Auth.Azure)
   - Input type guards

2. **Token Management**
   - GenServer for process-isolated token state
   - Configurable refresh buffer
   - Error recovery with retry logic
   - Explicit token expiration checking

3. **API Key Handling**
   - Simple map storage
   - No encryption at rest

### Security Gaps

| Area | Gap | Severity | Recommendation |
|------|-----|----------|----------------|
| Credential warnings | Missing refresh token warnings | Low | Add warning when bearer token has no refresh token |
| Negative expiry | No warning for negative expires_in | Very Low | Add validation/warning |
| Token storage | No encryption at rest | Low | Consider encrypted ETS or similar for sensitive tokens |
| Scope validation | No validation of requested scopes | Low | Validate scopes against OIDC provider capabilities |

---

## Code Examples: API Differences

### Creating a Role with Permissions

**Python:**
```python
from weaviate.auth import Auth
from weaviate.rbac import Actions, Permissions

# Create permissions
permissions = [
    Permissions.collections(collection="Article", read_config=True, update_config=True),
    Permissions.data(collection="Article", create=True, read=True, update=True),
    Permissions.roles(role="viewer", read=True, scope=RoleScope.MATCH)  # Note: scope
]

# Create role
client.roles.create(role_name="article-editor", permissions=permissions)
```

**Elixir:**
```elixir
alias WeaviateEx.API.RBAC
alias WeaviateEx.RBAC.Permissions

# Create permissions
permissions = [
  Permissions.collections("Article", [:read, :update]),
  Permissions.data("Article", [:create, :read, :update]),
  Permissions.roles("viewer", :read)  # Note: no scope support
]

# Create role
RBAC.create_role(client, "article-editor", permissions)
```

### User Management

**Python:**
```python
# Create DB user and get API key
api_key = client.users.db.create(user_id="new-user")

# Assign roles (type-specific)
client.users.db.assign_roles(user_id="new-user", role_names=["editor"])

# Get roles with permissions
roles = client.users.db.get_assigned_roles(user_id="new-user", include_permissions=True)

# Deactivate with key revocation
client.users.db.deactivate(user_id="new-user", revoke_key=True)
```

**Elixir:**
```elixir
# Create user
{:ok, user} = Users.create(client, "new-user")
api_key = user.api_key

# Assign roles (no type separation)
:ok = Users.assign_roles(client, "new-user", ["editor"])

# Get roles (no include_permissions option)
{:ok, roles} = Users.get_assigned_roles(client, "new-user")

# Deactivate (no revoke_key option)
:ok = Users.deactivate(client, "new-user")
```

### Authentication Setup

**Python:**
```python
from weaviate.auth import Auth

# API Key
auth = Auth.api_key("your-key")

# OIDC Client Credentials
auth = Auth.client_credentials(
    client_secret="secret",
    scope=["openid", "profile"]  # Can be list or space-separated string
)

# Bearer token with refresh
auth = Auth.bearer_token(
    access_token="token",
    expires_in=3600,
    refresh_token="refresh-token"
)
```

**Elixir:**
```elixir
alias WeaviateEx.Auth

# API Key
auth = Auth.api_key("your-key")

# OIDC Client Credentials
auth = Auth.client_credentials("client-id", "secret", scopes: ["openid", "profile"])

# Bearer token with refresh
auth = Auth.bearer_token("token", expires_in: 3600, refresh_token: "refresh-token")

# With TokenManager for automatic refresh
{:ok, _pid} = WeaviateEx.Auth.TokenManager.start_link(
  issuer_url: "https://auth.example.com",
  auth: auth,
  name: MyApp.WeaviateTokenManager
)
```

---

## Summary of Gaps

### High Priority

1. **User Type Separation** - Python separates `users.db.*` and `users.oidc.*` operations for type-specific behavior; Elixir uses a flat namespace without distinction.

### Medium Priority

2. **Role Scope Parameter** - Python supports `scope: RoleScope.MATCH/ALL` for fine-grained role permission control.

3. **User/Group Assignments with Types** - Python returns typed assignment objects; Elixir returns simple string lists.

4. **Include Permissions Option** - Python allows requesting full role permissions in various get operations.

### Low Priority

5. **Deactivate with revoke_key** - Minor parameter missing in user deactivation.

6. **Replicate shard filter** - Minor filter option missing.

7. **Alias collection filter** - Minor filter option missing.

8. **Refresh token warnings** - Missing warnings for auth configurations without refresh tokens.

9. **OIDC/Groups namespace** - Structural difference (flat vs. nested).

---

## Recommendations

### Immediate Actions

1. **Add User Type Support**
   - Create `WeaviateEx.API.Users.DB` module
   - Create `WeaviateEx.API.Users.OIDC` module
   - Add user_type parameter to role operations

2. **Add Role Scope Support**
   - Add `:scope` option to `Permissions.roles/2`
   - Define `RoleScope` type (`:match` | `:all`)

3. **Enhance Assignment Returns**
   - Return `UserAssignment` struct with user_id and user_type
   - Return `GroupAssignment` struct with group_id and group_type

### Future Enhancements

4. **Add include_permissions Option**
   - Add option to `get_assigned_roles` functions
   - Return full `Role` structs when requested

5. **Add Missing Filters**
   - Add `shard` filter to replicate permissions
   - Add `collection` filter to alias permissions

6. **Security Warnings**
   - Add warnings for missing refresh tokens
   - Add validation for negative expiration times
