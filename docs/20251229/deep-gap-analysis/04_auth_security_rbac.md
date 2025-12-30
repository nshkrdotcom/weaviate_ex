# Auth, Security, and RBAC Gap Analysis

## Executive Summary

This document provides a comprehensive gap analysis comparing authentication, security, and RBAC features between the canonical Python Weaviate client and the WeaviateEx Elixir port.

**Overall Status**: The Elixir implementation has a **solid foundation** for authentication and RBAC but is **missing several advanced features** present in the Python client. The authentication layer is well-designed with proper OIDC support, while RBAC has most core features implemented. Key gaps exist in connection configuration (proxies, advanced SSL), user type separation (DB vs OIDC), and group management.

### Quick Summary

| Category | Python Features | Elixir Status | Priority |
|----------|----------------|---------------|----------|
| API Key Auth | Full | Implemented | - |
| Bearer Token Auth | Full | Implemented | - |
| OIDC Client Credentials | Full | Implemented | - |
| OIDC Password Flow | Full | Implemented | - |
| Token Refresh/Lifecycle | Full | Implemented | - |
| Connection Timeouts | Granular (query/insert/init) | Basic (single timeout) | Medium |
| Proxy Support | HTTP/HTTPS/gRPC + env vars | Missing | Medium |
| Custom Headers | Full support | Missing | High |
| RBAC Roles (CRUD) | Full | Implemented | - |
| RBAC Permissions | 11 types | 11 types (Implemented) | - |
| Users API (DB) | Full (create/delete/activate/deactivate/rotate) | Partial | High |
| Users API (OIDC) | Separate namespace | Not separated | Medium |
| Groups API | Full (OIDC groups) | Basic | Medium |
| User/Group Assignments | Full | Partial | Medium |

---

## 1. API Key Authentication

### Python Implementation

```python
# File: weaviate/auth.py

@dataclass
class _APIKey:
    """Using the given API key to authenticate with weaviate."""
    api_key: str

class Auth:
    @staticmethod
    def api_key(api_key: str) -> _APIKey:
        return _APIKey(api_key)

# Usage
import weaviate
client = weaviate.connect_to_weaviate_cloud(
    cluster_url="https://...",
    auth_credentials=weaviate.auth.Auth.api_key("your-key")
)
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth.ex

@spec api_key(String.t()) :: api_key_auth()
def api_key(key) when is_binary(key) do
  %{
    type: :api_key,
    api_key: key
  }
end

# Usage
auth = WeaviateEx.Auth.api_key("your-key")
{:ok, client} = WeaviateEx.Client.connect(
  base_url: "https://...",
  api_key: "your-key"
)
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic API key auth | Yes | Yes | **Implemented** |
| Header format (Bearer) | Yes | Yes | **Implemented** |
| Type safety | Dataclass | Map type | **Implemented** |

**Status: Fully Implemented**

---

## 2. OIDC Authentication

### 2.1 Client Credentials Flow

#### Python Implementation

```python
# File: weaviate/auth.py

@dataclass
class _ClientCredentials:
    """Authenticate for the Client Credential flow using client secrets."""
    client_secret: str
    scope: Optional[SCOPES] = None

    def __post_init__(self) -> None:
        if self.scope is None:
            self.scope_list: List[str] = []
        elif isinstance(self.scope, str):
            self.scope_list = self.scope.split(" ")
        elif isinstance(self.scope, list):
            self.scope_list = self.scope

# File: weaviate/connect/authentication.py
# Full OAuth2Client integration with authlib
class _Auth:
    def _get_session_client_credential(self, config: AuthClientCredentials) -> Result:
        session = OAuth2Client(
            client_id=self._client_id,
            client_secret=config.client_secret,
            token_endpoint_auth_method="client_secret_post",
            scope=scope,
            token_endpoint=self._token_endpoint,
            grant_type="client_credentials",
            token={"access_token": None, "expires_in": -100},
            default_timeout=AUTH_DEFAULT_TIMEOUT,
        )
        session.fetch_token()
        return session
```

#### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth.ex

@spec client_credentials(String.t(), String.t(), keyword()) :: client_credentials_auth()
def client_credentials(client_id, client_secret, opts \\ [])
    when is_binary(client_id) and is_binary(client_secret) do
  %{
    type: :oidc_client_credentials,
    client_id: client_id,
    client_secret: client_secret,
    scopes: Keyword.get(opts, :scopes, [])
  }
end

# File: lib/weaviate_ex/auth/oidc.ex
defp build_token_params(%{type: :oidc_client_credentials} = auth) do
  params = [
    {"grant_type", "client_credentials"},
    {"client_id", auth.client_id},
    {"client_secret", auth.client_secret}
  ]
  maybe_add_scope(params, auth.scopes)
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Client ID + Secret | Yes | Yes | **Implemented** |
| Scope configuration | String or List | List | **Implemented** |
| Token endpoint discovery | Yes | Yes | **Implemented** |
| Automatic scope detection for Azure | Yes | Yes | **Implemented** |

**Status: Fully Implemented**

### 2.2 Resource Owner Password Flow

#### Python Implementation

```python
# File: weaviate/auth.py

@dataclass
class _ClientPassword:
    """Using username and password for authentication with Resource Owner Password flow."""
    username: str
    password: str
    scope: Optional[SCOPES] = None

# File: weaviate/connect/authentication.py
def _get_session_user_pw(self, config: AuthClientPassword) -> Result:
    session = OAuth2Client(
        client_id=self._client_id,
        token_endpoint=self._token_endpoint,
        grant_type="password",
        scope=scope,
        default_timeout=AUTH_DEFAULT_TIMEOUT,
    )
    token = session.fetch_token(username=config.username, password=config.password)
    if "refresh_token" not in token:
        _Warnings.auth_no_refresh_token(token["expires_in"])
    return session
```

#### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth.ex

@spec client_password(String.t(), String.t(), keyword()) :: password_auth()
def client_password(username, password, opts \\ [])
    when is_binary(username) and is_binary(password) do
  %{
    type: :oidc_password,
    username: username,
    password: password,
    client_id: Keyword.get(opts, :client_id),
    client_secret: Keyword.get(opts, :client_secret),
    scopes: Keyword.get(opts, :scopes, [])
  }
end

# File: lib/weaviate_ex/auth/oidc.ex
defp build_token_params(%{type: :oidc_password} = auth) do
  params = [
    {"grant_type", "password"},
    {"username", auth.username},
    {"password", auth.password}
  ]
  # Optional client_id/client_secret
  params = if auth.client_id, do: params ++ [{"client_id", auth.client_id}], else: params
  params = if auth.client_secret, do: params ++ [{"client_secret", auth.client_secret}], else: params
  maybe_add_scope(params, auth.scopes)
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Username/Password auth | Yes | Yes | **Implemented** |
| Optional client_id | Implicit from OIDC config | Explicit parameter | **Implemented** |
| Optional client_secret | Not in password flow | Supported | **Implemented** |
| Scope configuration | Yes | Yes | **Implemented** |
| Azure password flow warning | Yes | No | **Missing** |
| Grant types validation | Yes | No | **Missing** |

**Status: Mostly Implemented** - Missing validation that Azure doesn't support password flow.

### 2.3 Bearer Token Authentication

#### Python Implementation

```python
# File: weaviate/auth.py

@dataclass
class _BearerToken:
    """Using a preexisting bearer/access token for authentication."""
    access_token: str
    expires_in: int = 60
    refresh_token: Optional[str] = None

    def __post_init__(self) -> None:
        if self.expires_in and self.expires_in < 0:
            _Warnings.auth_negative_expiration_time(self.expires_in)
```

#### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth.ex

@spec bearer_token(String.t(), keyword()) :: bearer_token_auth()
def bearer_token(token, opts \\ []) when is_binary(token) do
  %{
    type: :bearer_token,
    access_token: token,
    expires_in: Keyword.get(opts, :expires_in),
    refresh_token: Keyword.get(opts, :refresh_token)
  }
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Access token | Yes | Yes | **Implemented** |
| Expiration time | Yes (default 60s) | Yes (optional) | **Implemented** |
| Refresh token | Yes | Yes | **Implemented** |
| Negative expiration warning | Yes | No | **Missing** |

**Status: Fully Implemented** - Minor warning missing.

---

## 3. Token Refresh and Lifecycle Management

### Python Implementation

```python
# File: weaviate/connect/authentication.py
# Uses authlib's OAuth2Client which handles automatic token refresh

class _Auth:
    def _get_session_auth_bearer_token(self, config: AuthBearerToken) -> Result:
        token = {"access_token": config.access_token}
        if config.expires_in is not None:
            token["expires_in"] = config.expires_in
        if config.refresh_token is not None:
            token["refresh_token"] = config.refresh_token

        if "refresh_token" not in token:
            _Warnings.auth_no_refresh_token(config.expires_in)

        return OAuth2Client(
            token=token,
            token_endpoint=self._token_endpoint,
            client_id=self._client_id,
            default_timeout=AUTH_DEFAULT_TIMEOUT,
        )
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth/token_manager.ex

defmodule WeaviateEx.Auth.TokenManager do
  use GenServer

  # Automatic token refresh before expiration
  defp schedule_refresh(%{token: token, refresh_buffer_seconds: buffer} = state) do
    case token.expires_in do
      nil -> state
      expires_in ->
        refresh_in = max(1, (expires_in - buffer) * 1000)
        timer_ref = Process.send_after(self(), :refresh_token, refresh_in)
        %{state | refresh_timer: timer_ref}
    end
  end

  # Refresh using refresh_token if available, otherwise re-authenticate
  defp fetch_or_refresh_token(%{token: token, oidc_config: config, auth: auth}) do
    if token.refresh_token do
      case OIDC.refresh_token(config, token.refresh_token) do
        {:ok, new_token} -> {:ok, new_token}
        {:error, _} -> OIDC.get_token(config, auth)
      end
    else
      OIDC.get_token(config, auth)
    end
  end
end

# File: lib/weaviate_ex/auth/oidc.ex
defmodule WeaviateEx.Auth.OIDC.TokenResponse do
  @spec expires_at(t()) :: DateTime.t() | nil
  def expires_at(%__MODULE__{issued_at: issued_at, expires_in: expires_in}) do
    DateTime.add(issued_at, expires_in, :second)
  end

  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{} = token) do
    case expires_at(token) do
      nil -> false
      expires -> DateTime.compare(DateTime.utc_now(), expires) != :lt
    end
  end

  @spec expiring_soon?(t(), non_neg_integer()) :: boolean()
  def expiring_soon?(%__MODULE__{} = token, buffer_seconds \\ 60) do
    case expires_at(token) do
      nil -> false
      expires ->
        buffer_time = DateTime.add(DateTime.utc_now(), buffer_seconds, :second)
        DateTime.compare(buffer_time, expires) != :lt
    end
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Automatic token refresh | Via authlib | Via TokenManager GenServer | **Implemented** |
| Configurable refresh buffer | Implicit | Explicit (`:refresh_buffer_seconds`) | **Implemented** |
| Token expiration tracking | Yes | Yes | **Implemented** |
| Expiring soon check | Implicit | Explicit (`expiring_soon?/2`) | **Implemented** |
| Missing refresh token warning | Yes | No | **Missing** |
| Force refresh | Implicit | Explicit (`force_refresh/1`) | **Implemented** |
| Child spec for supervision | N/A | Yes | **Implemented** |

**Status: Fully Implemented** - Better Elixir idioms with GenServer supervision.

---

## 4. Connection Configuration

### 4.1 Timeouts

#### Python Implementation

```python
# File: weaviate/config.py

class Timeout(BaseModel):
    """Timeouts for the different operations in the client."""
    query: Union[int, float] = Field(default=30, ge=0)
    insert: Union[int, float] = Field(default=90, ge=0)
    init: Union[int, float] = Field(default=2, ge=0)

class AdditionalConfig(BaseModel):
    timeout_: Union[Tuple[int, int], Timeout] = Field(default_factory=Timeout, alias="timeout")

# Usage
from weaviate.classes.init import AdditionalConfig, Timeout
client = weaviate.connect_to_weaviate_cloud(
    additional_config=AdditionalConfig(
        timeout=Timeout(query=60, insert=120, init=5)
    )
)
```

#### Elixir Implementation

```elixir
# File: lib/weaviate_ex/client/config.ex

@type t :: %__MODULE__{
  # ...
  timeout: integer(),  # Single timeout value
  # ...
}

defstruct base_url: "http://localhost:8080",
          timeout: @default_timeout,  # 60_000ms
          # ...
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Query timeout | Yes (30s default) | Single timeout | **Partial** |
| Insert/batch timeout | Yes (90s default) | Single timeout | **Missing** |
| Init/connection timeout | Yes (2s default) | Connection timeout only | **Partial** |
| Tuple shorthand | Yes `(query, insert)` | N/A | **Missing** |

**Status: Partial** - Single timeout instead of granular timeouts.

**Recommendation:**
```elixir
# Proposed enhancement
@type timeouts :: %{
  query: integer(),
  insert: integer(),
  init: integer()
}

defstruct timeouts: %{query: 30_000, insert: 90_000, init: 2_000}
```

### 4.2 Proxy Support

#### Python Implementation

```python
# File: weaviate/config.py

class Proxies(BaseModel):
    """Proxy configurations for sending requests to Weaviate through a proxy."""
    http: Optional[str] = Field(default=None)
    https: Optional[str] = Field(default=None)
    grpc: Optional[str] = Field(default=None)

class AdditionalConfig(BaseModel):
    proxies: Union[str, Proxies, None] = Field(default=None)
    trust_env: bool = Field(default=False)

# File: weaviate/connect/base.py
def _get_proxies(proxies: Union[dict, str, Proxies, None], trust_env: bool) -> Dict[str, str]:
    """Get proxies as dict, compatible with 'requests' library."""
    if proxies is not None:
        if isinstance(proxies, str):
            return {"http": proxies, "https": proxies, "grpc": proxies}
        # ...

    if trust_env:
        http_proxy = os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy")
        https_proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
        grpc_proxy = os.environ.get("GRPC_PROXY") or os.environ.get("grpc_proxy")
        # ...
```

#### Elixir Implementation

**Not implemented.** No proxy support in the current Elixir client.

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HTTP proxy | Yes | No | **Missing** |
| HTTPS proxy | Yes | No | **Missing** |
| gRPC proxy | Yes | No | **Missing** |
| Single URL for all | Yes | No | **Missing** |
| Environment variables | Yes (trust_env) | No | **Missing** |

**Status: Not Implemented**

**Priority: Medium** - Required for enterprise deployments behind proxies.

**Recommendation:**
```elixir
# Proposed addition to config
@type proxy_config :: %{
  http: String.t() | nil,
  https: String.t() | nil,
  grpc: String.t() | nil
}

defstruct proxies: nil,
          trust_env: false
```

### 4.3 SSL/TLS Configuration

#### Python Implementation

```python
# File: weaviate/connect/base.py

class ProtocolParams(BaseModel):
    host: str
    port: int
    secure: bool

# gRPC SSL
if self.grpc.secure:
    return mod.secure_channel(
        target=self._grpc_target,
        credentials=ssl_channel_credentials(),
        options=options,
    )
else:
    return mod.insecure_channel(
        target=self._grpc_target,
        options=options,
    )
```

#### Elixir Implementation

```elixir
# File: lib/weaviate_ex/client/config.ex

@spec use_tls?(t()) :: boolean()
def use_tls?(%__MODULE__{base_url: base_url, grpc_port: port}) do
  String.starts_with?(base_url, "https://") or port == 443
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Auto TLS detection | Yes | Yes | **Implemented** |
| Custom CA certificates | Possible via mounts | Not exposed | **Missing** |
| Skip verification | Not recommended | Not implemented | **Missing** |
| Separate HTTP/gRPC TLS | Yes | Derived from URL | **Partial** |

**Status: Partial** - Basic TLS works, advanced options missing.

### 4.4 Connection Pool Configuration

#### Python Implementation

```python
# File: weaviate/config.py

@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20
    session_pool_maxsize: int = 100
    session_pool_max_retries: int = 3
    session_pool_timeout: int = 5
```

#### Elixir Implementation

**Not exposed.** Finch handles connection pooling internally.

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Pool connections | 20 default | Finch default | **Implicit** |
| Pool max size | 100 default | Finch default | **Implicit** |
| Max retries | 3 default | Not configurable | **Missing** |
| Pool timeout | 5s default | Finch default | **Implicit** |

**Status: Implicit** - Finch handles this but options not exposed.

---

## 5. Custom Headers

### Python Implementation

```python
# File: weaviate/connect/v4.py

def __init__(
    self,
    # ...
    additional_headers: Optional[Dict[str, Any]],
    # ...
):
    self.__additional_headers = {}
    if additional_headers is not None:
        _validate_input(_ValidateArgument([dict], "additional_headers", additional_headers))
        self.__additional_headers = additional_headers
        for key, value in additional_headers.items():
            if value is None:
                raise WeaviateInvalidInputError(f"Value for key '{key}' in headers cannot be None.")

# Applied to both HTTP and gRPC
def _prepare_grpc_headers(self) -> None:
    self.__metadata_list: List[Tuple[str, str]] = []
    if len(self.additional_headers):
        for key, val in self.additional_headers.items():
            if val is not None:
                self.__metadata_list.append((key.lower(), val))

# Usage
client = weaviate.connect_to_weaviate_cloud(
    additional_headers={
        "X-OpenAI-Api-Key": "your-openai-key",
        "X-Cohere-Api-Key": "your-cohere-key",
    }
)
```

### Elixir Implementation

**Not implemented.** No custom headers support in the current Elixir client.

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Custom HTTP headers | Yes | No | **Missing** |
| Custom gRPC metadata | Yes | No | **Missing** |
| OpenAI API key header | Yes | No | **Missing** |
| Cohere API key header | Yes | No | **Missing** |
| Header validation | Yes | N/A | **Missing** |

**Status: Not Implemented**

**Priority: High** - Required for using vectorizer/generative modules with external APIs.

**Recommendation:**
```elixir
# Proposed addition to config
defstruct additional_headers: %{},
          # ...

# Apply to HTTP requests
defp build_headers(config) do
  base_headers = [{"content-type", "application/json"}]
  auth_headers = build_auth_headers(config)
  custom_headers = Map.to_list(config.additional_headers)
  base_headers ++ auth_headers ++ custom_headers
end

# Apply to gRPC metadata
defp build_grpc_metadata(config) do
  config.additional_headers
  |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
end
```

---

## 6. RBAC Roles Management

### Python Implementation

```python
# File: weaviate/rbac/executor.py

class _RolesExecutor(Generic[ConnectionType]):
    def list_all(self) -> executor.Result[Dict[str, Role]]:
        """Get all roles."""
        path = "/authz/roles"
        # ...

    def exists(self, role_name: str) -> executor.Result[bool]:
        """Check if a role exists."""
        # ...

    def get(self, role_name: str) -> executor.Result[Optional[Role]]:
        """Get the permissions granted to this role."""
        # ...

    def create(self, *, role_name: str, permissions: PermissionsInputType) -> executor.Result[Role]:
        """Create a new role."""
        # ...

    def delete(self, role_name: str) -> executor.Result[None]:
        """Delete a role."""
        # ...

    def add_permissions(self, *, permissions: PermissionsInputType, role_name: str) -> executor.Result[None]:
        """Add permissions to a role (upsert)."""
        # ...

    def remove_permissions(self, *, permissions: PermissionsInputType, role_name: str) -> executor.Result[None]:
        """Remove permissions from a role (downsert)."""
        # ...

    def has_permissions(self, *, permissions: ..., role: str) -> executor.Result[bool]:
        """Check if a role has a specific set of permissions."""
        # ...

    def get_user_assignments(self, role_name: str) -> executor.Result[List[UserAssignment]]:
        """Get users assigned to this role with their types."""
        # ...

    def get_group_assignments(self, role_name: str) -> executor.Result[List[GroupAssignment]]:
        """Get groups assigned to this role with their types."""
        # ...

    @deprecated
    def get_assigned_user_ids(self, role_name: str) -> executor.Result[List[str]]:
        """Get user IDs (deprecated)."""
        # ...
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/api/rbac.ex

defmodule WeaviateEx.API.RBAC do
  def list_roles(client, opts \\ [])
  def exists?(client, role_name, opts \\ [])
  def get_role(client, role_name, opts \\ [])
  def create_role(client, role_name, permissions, opts \\ [])
  def delete_role(client, role_name, opts \\ [])
  def add_permissions(client, role_name, permissions, opts \\ [])
  def remove_permissions(client, role_name, permissions, opts \\ [])
  def has_permissions?(client, role_name, permissions, opts \\ [])
  def get_users_for_role(client, role_name, opts \\ [])
  def get_groups_for_role(client, role_name, opts \\ [])
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List all roles | Yes (returns Dict) | Yes (returns List) | **Implemented** |
| Check role exists | Yes | Yes | **Implemented** |
| Get role by name | Yes (returns Optional) | Yes | **Implemented** |
| Create role | Yes | Yes | **Implemented** |
| Delete role | Yes | Yes | **Implemented** |
| Add permissions | Yes (upsert) | Yes | **Implemented** |
| Remove permissions | Yes (downsert) | Yes | **Implemented** |
| Has permissions | Yes (batch check) | Yes | **Implemented** |
| Get user assignments | Yes (with UserType) | Partial (IDs only) | **Partial** |
| Get group assignments | Yes (with GroupType) | Partial (IDs only) | **Partial** |
| Async support | Yes (`_RolesAsync`) | No (sync only) | **Missing** |

**Status: Mostly Implemented** - Missing user/group type information in assignments.

**Recommendation:**
```elixir
# Enhanced assignment types
@type user_assignment :: %{
  user_id: String.t(),
  user_type: :db_user | :db_env_user | :oidc
}

@type group_assignment :: %{
  group_id: String.t(),
  group_type: :oidc
}

# Update get_user_assignments to return typed assignments
def get_user_assignments(client, role_name, opts \\ [])
def get_group_assignments(client, role_name, opts \\ [])
```

---

## 7. RBAC Permissions

### Python Permission Types

```python
# File: weaviate/rbac/models.py

# Permission Types (11 total)
class AliasAction(str, _Action, Enum):
    CREATE = "create_aliases"
    READ = "read_aliases"
    UPDATE = "update_aliases"
    DELETE = "delete_aliases"

class CollectionsAction(str, _Action, Enum):
    CREATE = "create_collections"
    READ = "read_collections"
    UPDATE = "update_collections"
    DELETE = "delete_collections"
    MANAGE = "manage_collections"

class TenantsAction(str, _Action, Enum):
    CREATE = "create_tenants"
    READ = "read_tenants"
    UPDATE = "update_tenants"
    DELETE = "delete_tenants"

class DataAction(str, _Action, Enum):
    CREATE = "create_data"
    READ = "read_data"
    UPDATE = "update_data"
    DELETE = "delete_data"
    MANAGE = "manage_data"

class RolesAction(str, _Action, Enum):
    MANAGE = "manage_roles"  # deprecated
    CREATE = "create_roles"
    READ = "read_roles"
    UPDATE = "update_roles"
    DELETE = "delete_roles"

class GroupAction(str, _Action, Enum):
    READ = "read_groups"
    ASSIGN_AND_REVOKE = "assign_and_revoke_groups"

class UsersAction(str, _Action, Enum):
    CREATE = "create_users"
    READ = "read_users"
    UPDATE = "update_users"
    DELETE = "delete_users"
    ASSIGN_AND_REVOKE = "assign_and_revoke_users"

class ClusterAction(str, _Action, Enum):
    READ = "read_cluster"

class NodesAction(str, _Action, Enum):
    READ = "read_nodes"

class BackupsAction(str, _Action, Enum):
    MANAGE = "manage_backups"

class ReplicateAction(str, _Action, Enum):
    CREATE = "create_replicate"
    READ = "read_replicate"
    UPDATE = "update_replicate"
    DELETE = "delete_replicate"
```

### Python Permission Builder

```python
# File: weaviate/rbac/models.py

class Permissions:
    Nodes = NodesPermissions
    Groups = GroupsPermissions

    @staticmethod
    def alias(*, alias, collection, create=False, read=False, update=False, delete=False)

    @staticmethod
    def data(*, collection, tenant=None, create=False, read=False, update=False, delete=False)

    @staticmethod
    def collections(*, collection, create_collection=False, read_config=False,
                   update_config=False, delete_collection=False)

    @staticmethod
    def tenants(*, collection, tenant=None, create=False, read=False, update=False, delete=False)

    @staticmethod
    def replicate(*, collection, shard=None, create=False, read=False, update=False, delete=False)

    @staticmethod
    def roles(*, role, create=False, read=False, update=False, delete=False, scope=None)

    @staticmethod
    def users(*, user, create=False, read=False, update=False, delete=False, assign_and_revoke=False)

    @staticmethod
    def backup(*, collection, manage=False)

    @staticmethod
    def cluster(*, read=False)

class NodesPermissions:
    @staticmethod
    def verbose(*, collection, read=False)

    @staticmethod
    def minimal(*, read=False)

class GroupsPermissions:
    @staticmethod
    def oidc(*, group, read=False, assign_and_revoke=False)
```

### Elixir Permission Types

```elixir
# File: lib/weaviate_ex/rbac/actions.ex

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

### Elixir Permission Builder

```elixir
# File: lib/weaviate_ex/rbac/permissions.ex

defmodule WeaviateEx.RBAC.Permissions do
  def collections(actions)
  def collections(collection, actions)

  def data(actions)
  def data(collection, actions)
  def data(collection, actions, opts)  # tenant, object

  def tenants(actions)
  def tenants(collection, actions)
  def tenants(collection, actions, opts)  # tenant

  def roles(actions)
  def roles(role, actions)

  def users(actions)
  def users(user, actions)

  def groups(actions)
  def groups(group, actions)

  def cluster(action \\ :read)
  def nodes(verbosity \\ :minimal)
  def backups(action \\ :manage)

  def replicate(actions)
  def replicate(collection, actions)

  def alias_permission(actions)
  def alias_permission(alias_name, actions)

  def flatten(permissions)
end
```

### Gap Analysis

| Permission Type | Python Actions | Elixir Actions | Status |
|----------------|----------------|----------------|--------|
| alias | CRUD | CRUD | **Implemented** |
| collections | CRUD + manage | CRUD + manage | **Implemented** |
| data | CRUD + manage | CRUD + manage | **Implemented** |
| tenants | CRUD | CRUD | **Implemented** |
| roles | CRUD (+ deprecated manage) | CRUD | **Implemented** |
| users | CRUD + assign_and_revoke | CRUD + assign_and_revoke | **Implemented** |
| groups | read + assign_and_revoke | read + assign_and_revoke | **Implemented** |
| cluster | read | read | **Implemented** |
| nodes | read (verbose/minimal) | read (verbose/minimal) | **Implemented** |
| backups | manage | manage | **Implemented** |
| replicate | CRUD | CRUD | **Implemented** |

| Builder Feature | Python | Elixir | Status |
|-----------------|--------|--------|--------|
| Boolean flags for actions | Yes | No (list-based) | **Different API** |
| Wildcard support (*) | Yes | Yes (`:all`) | **Implemented** |
| Collection filter | Yes | Yes | **Implemented** |
| Tenant filter | Yes | Yes | **Implemented** |
| Object filter | Yes | Yes | **Implemented** |
| Role filter | Yes | Yes | **Implemented** |
| User filter | Yes | Yes | **Implemented** |
| Group filter | Yes | Yes | **Implemented** |
| Verbosity (nodes) | Yes | Yes | **Implemented** |
| Scope (roles) | Yes | Partial | **Partial** |
| Shard filter (replicate) | Yes | No | **Missing** |

**Status: Mostly Implemented** - Missing shard filter for replicate and scope for roles.

---

## 8. Users API

### Python Implementation

```python
# File: weaviate/users/base.py

class _UsersExecutor:
    def get_my_user(self) -> executor.Result[OwnUser]:
        """Get the currently authenticated user."""
        path = "/users/own-info"
        # Returns: user_id, roles (Dict[str, Role]), groups

class _UsersDBExecutor:
    """DB-specific user operations."""

    def get_assigned_roles(self, *, user_id, include_permissions=False) -> Dict[str, Role|RoleBase]:
        """Get roles for DB user."""
        path = f"/authz/users/{user_id}/roles/db"

    def assign_roles(self, *, user_id, role_names) -> None:
        """Assign roles to DB user."""
        path = f"/authz/users/{user_id}/assign"

    def revoke_roles(self, *, user_id, role_names) -> None:
        """Revoke roles from DB user."""
        path = f"/authz/users/{user_id}/revoke"

    def create(self, *, user_id) -> str:
        """Create a new DB user, returns API key."""
        path = f"/users/db/{user_id}"

    def delete(self, *, user_id) -> bool:
        """Delete a DB user."""
        path = f"/users/db/{user_id}"

    def rotate_key(self, *, user_id) -> str:
        """Rotate API key for DB user."""
        path = f"/users/db/{user_id}/rotate-key"

    def activate(self, *, user_id) -> bool:
        """Activate a deactivated user."""
        path = f"/users/db/{user_id}/activate"

    def deactivate(self, *, user_id, revoke_key=False) -> bool:
        """Deactivate an active user."""
        path = f"/users/db/{user_id}/deactivate"

    def get(self, *, user_id) -> Optional[UserDB]:
        """Get user info."""
        path = f"/users/db/{user_id}"

    def list_all(self) -> List[UserDB]:
        """List all DB users."""
        path = "/users/db"

class _UsersOIDCExecutor:
    """OIDC-specific user operations."""

    def get_assigned_roles(self, *, user_id, include_permissions=False) -> Dict[str, Role|RoleBase]:
        """Get roles for OIDC user."""
        path = f"/authz/users/{user_id}/roles/oidc"

    def assign_roles(self, *, user_id, role_names) -> None:
        """Assign roles to OIDC user."""

    def revoke_roles(self, *, user_id, role_names) -> None:
        """Revoke roles from OIDC user."""

# User types
class UserTypes(str, Enum):
    DB_DYNAMIC = "db_user"
    DB_STATIC = "db_env_user"
    OIDC = "oidc"

# User models
@dataclass
class OwnUser:
    user_id: str
    roles: Dict[str, Role]
    groups: List[str]

@dataclass
class UserDB(UserBase):
    user_type: UserTypes
    active: bool

@dataclass
class UserOIDC(UserBase):
    user_type: UserTypes = UserTypes.OIDC

# Usage
client.users.get_my_user()
client.users.db.create(user_id="new-user")
client.users.db.activate(user_id="user")
client.users.db.deactivate(user_id="user", revoke_key=True)
client.users.db.rotate_key(user_id="user")
client.users.oidc.assign_roles(user_id="user", role_names=["admin"])
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/api/users.ex

defmodule WeaviateEx.API.Users do
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
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Get current user | `get_my_user()` | `get_my_user/2` | **Implemented** |
| Create DB user | `db.create()` | `create/3` | **Implemented** |
| Delete user | `db.delete()` | `delete/3` | **Implemented** |
| Activate user | `db.activate()` | `activate/3` | **Implemented** |
| Deactivate user | `db.deactivate(revoke_key)` | `deactivate/3` (no revoke_key) | **Partial** |
| Rotate API key | `db.rotate_key()` | `rotate_key/3` | **Implemented** |
| Get user | `db.get()` | `get/3` | **Implemented** |
| List all DB users | `db.list_all()` | `list_all/2` | **Implemented** |
| Assign roles | `db.assign_roles()` / `oidc.assign_roles()` | `assign_roles/4` | **Partial** |
| Revoke roles | `db.revoke_roles()` / `oidc.revoke_roles()` | `revoke_roles/4` | **Partial** |
| Get assigned roles | With `include_permissions` | Without permission details | **Partial** |
| Separate DB namespace | `users.db.*` | No separation | **Missing** |
| Separate OIDC namespace | `users.oidc.*` | No separation | **Missing** |
| User type in response | Yes (db_user/db_env_user/oidc) | Partial | **Partial** |

**Status: Partial**

**Key Missing Features:**
1. No separation between DB and OIDC user operations
2. `deactivate` missing `revoke_key` option
3. No `include_permissions` option for `get_assigned_roles`
4. User type not consistently exposed

**Recommendation:**
```elixir
# Proposed structure mirroring Python
defmodule WeaviateEx.API.Users do
  # Current user
  def get_my_user(client, opts \\ [])
end

defmodule WeaviateEx.API.Users.DB do
  def create(client, user_id, opts \\ [])
  def delete(client, user_id, opts \\ [])
  def get(client, user_id, opts \\ [])
  def list_all(client, opts \\ [])
  def activate(client, user_id, opts \\ [])
  def deactivate(client, user_id, opts \\ [])  # Add revoke_key: false option
  def rotate_key(client, user_id, opts \\ [])
  def assign_roles(client, user_id, role_names, opts \\ [])
  def revoke_roles(client, user_id, role_names, opts \\ [])
  def get_assigned_roles(client, user_id, opts \\ [])  # Add include_permissions: false
end

defmodule WeaviateEx.API.Users.OIDC do
  def assign_roles(client, user_id, role_names, opts \\ [])
  def revoke_roles(client, user_id, role_names, opts \\ [])
  def get_assigned_roles(client, user_id, opts \\ [])
end
```

---

## 9. Groups API

### Python Implementation

```python
# File: weaviate/groups/base.py

class _GroupsOIDCExecutor:
    """OIDC group operations."""

    def get_assigned_roles(self, *, group_id, include_permissions=False) -> Dict[str, Role|RoleBase]:
        """Get roles assigned to an OIDC group."""
        path = f"/authz/groups/{group_id}/roles/oidc"

    def assign_roles(self, *, group_id, role_names) -> None:
        """Assign roles to an OIDC group."""
        path = f"/authz/groups/{group_id}/assign"

    def revoke_roles(self, *, group_id, role_names) -> None:
        """Revoke roles from an OIDC group."""
        path = f"/authz/groups/{group_id}/revoke"

    def get_known_group_names(self) -> List[str]:
        """Get known OIDC group names."""
        path = f"/authz/groups/oidc"

# Usage
client.groups.oidc.get_known_group_names()
client.groups.oidc.assign_roles(group_id="engineering", role_names=["developer"])
client.groups.oidc.get_assigned_roles(group_id="engineering", include_permissions=True)
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/api/groups.ex

defmodule WeaviateEx.API.Groups do
  def list_known(client, opts \\ [])
  def get_assigned_roles(client, group_id, opts \\ [])
  def assign_roles(client, group_id, role_names, opts \\ [])
  def revoke_roles(client, group_id, role_names, opts \\ [])
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List known groups | `oidc.get_known_group_names()` | `list_known/2` | **Implemented** |
| Get assigned roles | `oidc.get_assigned_roles()` | `get_assigned_roles/3` | **Implemented** |
| Include permissions | Yes (`include_permissions`) | No | **Missing** |
| Assign roles | `oidc.assign_roles()` | `assign_roles/4` | **Implemented** |
| Revoke roles | `oidc.revoke_roles()` | `revoke_roles/4` | **Implemented** |
| OIDC namespace | `groups.oidc.*` | Flat structure | **Different** |

**Status: Mostly Implemented** - Missing `include_permissions` option.

**Recommendation:**
```elixir
# Add include_permissions option
def get_assigned_roles(client, group_id, opts \\ []) do
  include_permissions = Keyword.get(opts, :include_permissions, false)
  # Include in request params
end

# Consider OIDC namespace for consistency
defmodule WeaviateEx.API.Groups.OIDC do
  # Move all functions here
end
```

---

## 10. Azure-Specific Authentication

### Python Implementation

```python
# File: weaviate/connect/authentication.py

def _validate(self, oidc_config: OIDC_CONFIG):
    if isinstance(self._credentials, AuthClientPassword):
        def resp(res: str) -> None:
            if res.startswith("https://login.microsoftonline.com"):
                raise AuthenticationFailedError(
                    """Microsoft/azure does not recommend to authenticate using username and password
                    and this method is not supported by the python client."""
                )

def __get_common_scopes(self):
    def resp(res: str) -> List[str]:
        if res.startswith("https://login.microsoftonline.com"):
            return [self._client_id + "/.default"]
        raise MissingScopeError
```

### Elixir Implementation

```elixir
# File: lib/weaviate_ex/auth/azure.ex

defmodule WeaviateEx.Auth.Azure do
  @azure_patterns [
    "login.microsoftonline.com",
    "login.microsoft.com",
    "sts.windows.net"
  ]

  def azure_endpoint?(endpoint)
  def default_scopes(client_id)  # Returns ["client_id/.default"]
  def apply_azure_defaults(opts)
  def detect_version(endpoint)  # :v1 or :v2
  def build_token_params(:v1 | :v2, client_id)
  def format_resource(client_id)
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Azure endpoint detection | Yes | Yes | **Implemented** |
| Default scopes (`/.default`) | Yes | Yes | **Implemented** |
| Password flow rejection | Yes (raises error) | No | **Missing** |
| v1/v2 endpoint detection | Implicit | Explicit | **Implemented** |
| Resource vs scope (v1/v2) | Implicit | Explicit | **Implemented** |

**Status: Mostly Implemented** - Missing password flow validation for Azure.

---

## 11. Summary and Priority Recommendations

### Priority 1: High (Required for Production Use)

1. **Custom Headers Support**
   - Required for OpenAI, Cohere, HuggingFace API keys
   - Affects all vectorizer and generative module usage
   - Implementation: Add `additional_headers` to config and apply to HTTP/gRPC

2. **Users API Separation (DB vs OIDC)**
   - Required for proper user management in production
   - Different operations available for each user type
   - Implementation: Create `Users.DB` and `Users.OIDC` submodules

3. **Deactivate with revoke_key option**
   - Security feature for user management
   - Implementation: Add `revoke_key` option to `deactivate/3`

### Priority 2: Medium (Important for Enterprise)

4. **Granular Timeouts**
   - Query, insert, and init timeouts separately
   - Implementation: Replace single timeout with timeout map

5. **Proxy Support**
   - Required for enterprise deployments behind firewalls
   - HTTP, HTTPS, and gRPC proxy configuration
   - Environment variable support (`trust_env`)

6. **User/Group Assignments with Types**
   - Return user/group type information in role assignments
   - Implementation: Enhance `get_user_assignments` and `get_group_assignments`

7. **include_permissions Option**
   - For `get_assigned_roles` on users and groups
   - Reduces API calls when only role names needed

### Priority 3: Low (Nice to Have)

8. **Azure Password Flow Validation**
   - Warn/error when using password flow with Azure endpoints

9. **Missing Refresh Token Warning**
   - Warn when bearer token has no refresh token

10. **Connection Pool Configuration**
    - Expose Finch pool options to users

11. **Role Scope Support**
    - Add scope parameter to roles permissions

12. **Replicate Shard Filter**
    - Add shard filter to replicate permissions

### Implementation Effort Estimates

| Feature | Complexity | Effort |
|---------|------------|--------|
| Custom Headers | Low | 2-4 hours |
| Users DB/OIDC Split | Medium | 4-8 hours |
| Deactivate revoke_key | Low | 1 hour |
| Granular Timeouts | Low | 2-4 hours |
| Proxy Support | Medium | 4-8 hours |
| Assignment Types | Low | 2 hours |
| include_permissions | Low | 1-2 hours |
| Azure Password Validation | Low | 1 hour |
| Warnings | Low | 1-2 hours |
| Pool Config | Medium | 4 hours |
| Role Scope | Low | 1-2 hours |
| Shard Filter | Low | 1 hour |

**Total Estimated Effort: 24-40 hours**

---

## Appendix A: API Endpoint Mapping

| Python Path | Elixir Path | Status |
|------------|-------------|--------|
| `/authz/roles` | `/v1/authz/roles` | **Implemented** |
| `/authz/roles/{name}` | `/v1/authz/roles/{name}` | **Implemented** |
| `/authz/roles/{name}/add-permissions` | `/v1/authz/roles/{name}/add-permissions` | **Implemented** |
| `/authz/roles/{name}/remove-permissions` | `/v1/authz/roles/{name}/remove-permissions` | **Implemented** |
| `/authz/roles/{name}/has-permission` | `/v1/authz/roles/{name}/has-permissions` | **Implemented** |
| `/authz/roles/{name}/users` | `/v1/authz/roles/{name}/users` | **Implemented** |
| `/authz/roles/{name}/groups` | `/v1/authz/roles/{name}/groups` | **Implemented** |
| `/authz/roles/{name}/user-assignments` | Not implemented | **Missing** |
| `/authz/roles/{name}/group-assignments` | Not implemented | **Missing** |
| `/users/own-info` | `/v1/users/own` | **Different** |
| `/users/db/{id}` | `/v1/users/{id}` | **Different** |
| `/users/db` | `/v1/users` | **Different** |
| `/authz/users/{id}/roles/db` | Not separated | **Missing** |
| `/authz/users/{id}/roles/oidc` | Not separated | **Missing** |
| `/authz/groups/{id}/roles/oidc` | `/v1/authz/groups/{id}/roles` | **Implemented** |
| `/authz/groups/oidc` | `/v1/authz/groups` | **Implemented** |

## Appendix B: Type Mapping

| Python Type | Elixir Type | Notes |
|-------------|-------------|-------|
| `UserTypes.DB_DYNAMIC` | `:db_user` | - |
| `UserTypes.DB_STATIC` | `:db_env_user` | - |
| `UserTypes.OIDC` | `:oidc` | - |
| `GroupTypes.OIDC` | `:oidc` | - |
| `RoleScope.MATCH` | `:match` | Not implemented |
| `RoleScope.ALL` | `:all` | Not implemented |
| `Verbosity.MINIMAL` | `:minimal` | **Implemented** |
| `Verbosity.VERBOSE` | `:verbose` | **Implemented** |
