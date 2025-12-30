# Multi-Agent Gap Analysis: Authentication and Connection Handling

**Date:** 2024-12-29
**Analysis Type:** Deep Comparative Analysis
**Python Client:** `./weaviate-python-client/weaviate/connect/`, `auth.py`, `client.py`
**Elixir Port:** `./lib/weaviate_ex/auth/`, `./lib/weaviate_ex/connect.ex`, `./lib/weaviate_ex/client/`

---

## Executive Summary

This document provides a comprehensive gap analysis comparing authentication and connection handling between the canonical Python Weaviate client and the WeaviateEx Elixir implementation. The analysis covers 11 specific areas as requested.

### Overall Status Matrix

| Area | Python Coverage | Elixir Coverage | Gap Severity |
|------|-----------------|-----------------|--------------|
| 1. Authentication Methods | Complete | High | Low |
| 2. Token Management & Refresh | Complete | High | Low |
| 3. Connection Pooling | Configurable | Basic | Medium |
| 4. HTTP Client Configuration | Complete | High | Low |
| 5. gRPC Connection Handling | Complete | High | Low |
| 6. Proxy Support | Complete | Partial | Medium |
| 7. Custom Headers | Complete | High | Low |
| 8. SSL/TLS Configuration | Complete | Basic | Medium |
| 9. Health Checks | Complete | High | Low |
| 10. Retry Logic & Backoff | Complete | Complete | None |
| 11. Rate Limiting | Complete | Complete | None |

---

## 1. Authentication Methods

### 1.1 API Key Authentication

#### Python Implementation

**File:** `weaviate/auth.py` (lines 78-88)

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

**Usage in connection (v4.py:174-175):**
```python
if auth_client_secret is not None and isinstance(auth_client_secret, AuthApiKey):
    self._headers["authorization"] = "Bearer " + auth_client_secret.api_key
```

**Key Features:**
- Simple dataclass-based implementation
- Immediately added to headers on connection initialization
- Supports both HTTP and gRPC with `Bearer` prefix
- No token refresh needed (static credential)

#### Elixir Implementation

**File:** `lib/weaviate_ex/client/config.ex`

```elixir
defstruct base_url: "http://localhost:8080",
          grpc_host: "localhost",
          grpc_port: @default_grpc_port,
          api_key: nil,
          timeout: @default_timeout,
          timeout_config: nil,
          grpc_max_message_size: @default_grpc_max_message_size,
          additional_headers: %{}
```

**File:** `lib/weaviate_ex/protocol/http/client.ex` (lines 113-118)

```elixir
defp build_headers(config, body) do
  headers = [{"content-type", "application/json"}]

  headers =
    if config.api_key do
      [{"authorization", "Bearer #{config.api_key}"} | headers]
    else
      headers
    end
  # ...
end
```

**File:** `lib/weaviate_ex/grpc/channel.ex` (lines 129-148)

```elixir
def build_metadata(config) when is_map(config) do
  auth_metadata =
    case Map.get(config, :api_key) do
      nil -> %{}
      "" -> %{}
      api_key -> %{"authorization" => "Bearer #{api_key}"}
    end
  # ...
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| API key struct | `_APIKey` dataclass | Config field | **Complete** |
| Bearer prefix | Yes | Yes | **Complete** |
| HTTP support | Yes | Yes | **Complete** |
| gRPC metadata | Yes | Yes | **Complete** |
| String shorthand in connect helpers | Yes (`Auth.api_key("key")`) | Via config field | **Different approach** |

**Gaps:** None critical. API key authentication is fully implemented.

---

### 1.2 OIDC Client Credentials Flow

#### Python Implementation

**File:** `weaviate/auth.py` (lines 12-32)

```python
@dataclass
class _ClientCredentials:
    """Authenticate for the Client Credential flow using client secrets."""
    client_secret: str
    scope: Optional[SCOPES] = None

    def __post_init__(self) -> None:
        if self.scope is None:
            self.scope_list: List[str] = []
        elif isinstance(self.scope, str):
            self.scope_list = self.scope.split(" ")  # Space-separated scopes
        elif isinstance(self.scope, list):
            self.scope_list = self.scope
```

**File:** `weaviate/connect/authentication.py` (lines 220-260)

```python
def _get_session_client_credential(self, config: AuthClientCredentials) -> Result:
    scope: List[str] = self._default_scopes.copy()
    if config.scope_list is not None:
        scope.extend(config.scope_list)

    session = OAuth2Client(
        client_id=self._client_id,
        client_secret=config.client_secret,
        token_endpoint_auth_method="client_secret_post",
        scope=(scope if len(scope) > 0 else executor.result(self.__get_common_scopes())),
        token_endpoint=self._token_endpoint,
        grant_type="client_credentials",
        token={"access_token": None, "expires_in": -100},
        default_timeout=AUTH_DEFAULT_TIMEOUT,  # 5 seconds
    )
    # Explicitly fetch tokens to avoid race conditions
    session.fetch_token()
    return session
```

**Key Features:**
- Uses `authlib` OAuth2Client for robust OAuth handling
- Supports both sync and async via `AsyncOAuth2Client`
- Auto-detects Azure endpoints for default scopes
- Explicit token fetch to prevent race conditions
- 5-second default timeout for auth requests
- Reads `client_id` from OIDC discovery response

#### Elixir Implementation

**File:** `lib/weaviate_ex/auth/oidc.ex` (lines 203-212)

```elixir
defp build_token_params(%{type: :oidc_client_credentials} = auth) do
  params = [
    {"grant_type", "client_credentials"},
    {"client_id", auth.client_id},
    {"client_secret", auth.client_secret}
  ]
  maybe_add_scope(params, auth.scopes)
end
```

**File:** `lib/weaviate_ex/auth/oidc.ex` (lines 165-178)

```elixir
def get_token(%Config{token_endpoint: token_endpoint}, auth) do
  params = build_token_params(auth)

  case http_post_form(token_endpoint, params) do
    {:ok, %{status: 200, body: body}} ->
      parse_token_response(body)
    {:ok, %{status: _status, body: body}} ->
      parse_error_response(body)
    {:error, reason} ->
      {:error, reason}
  end
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Client credentials grant | Full | Implemented | **Complete** |
| Uses OAuth library | authlib | Finch (manual) | **Different** |
| Space-separated scope parsing | Yes | No | **Gap** |
| Default scopes from OIDC config | Yes | No | **Gap** |
| Azure auto-scopes | Yes | Partial | **Partial** |
| Token endpoint auth method | `client_secret_post` | Form-encoded | **Complete** |
| Auth timeout | 5s default | Not configurable | **Minor Gap** |
| Async support | Yes | N/A (BEAM) | N/A |

**Critical Gaps:**
1. Scope string parsing (space-separated)
2. Default scopes from OIDC discovery

---

### 1.3 OIDC Password Grant (Resource Owner)

#### Python Implementation

**File:** `weaviate/auth.py` (lines 34-55)

```python
@dataclass
class _ClientPassword:
    """Using username and password for authentication with Resource Owner Password flow."""
    username: str
    password: str
    scope: Optional[SCOPES] = None
```

**File:** `weaviate/connect/authentication.py` (lines 177-210)

```python
def _get_session_user_pw(self, config: AuthClientPassword) -> Result:
    scope: List[str] = self._default_scopes.copy()
    scope.extend(config.scope_list)

    session = OAuth2Client(
        client_id=self._client_id,
        token_endpoint=executor.result(self._get_token_endpoint()),
        grant_type="password",
        scope=scope,
        default_timeout=AUTH_DEFAULT_TIMEOUT,
    )
    token: dict = session.fetch_token(username=config.username, password=config.password)
    if "refresh_token" not in token:
        _Warnings.auth_no_refresh_token(token["expires_in"])
    return session
```

**Azure validation (lines 88-108):**
```python
def _validate(self, oidc_config: OIDC_CONFIG) -> executor.Result[None]:
    if isinstance(self._credentials, AuthClientPassword):
        def resp(res: str) -> None:
            if res.startswith("https://login.microsoftonline.com"):
                raise AuthenticationFailedError(
                    """Microsoft/azure does not recommend to authenticate using username
                    and password and this method is not supported by the python client."""
                )
```

#### Elixir Implementation

**File:** `lib/weaviate_ex/auth/oidc.ex` (lines 214-236)

```elixir
defp build_token_params(%{type: :oidc_password} = auth) do
  params = [
    {"grant_type", "password"},
    {"username", auth.username},
    {"password", auth.password}
  ]
  params = if auth.client_id, do: params ++ [{"client_id", auth.client_id}], else: params
  params = if auth.client_secret, do: params ++ [{"client_secret", auth.client_secret}], else: params
  maybe_add_scope(params, auth.scopes)
end
```

**File:** `lib/weaviate_ex/auth/azure.ex` (lines 183-203)

```elixir
@spec validate_password_flow(map()) :: :ok | {:error, String.t()}
def validate_password_flow(%{username: username, password: password, client_id: client_id})
    when is_binary(username) and is_binary(password) and is_binary(client_id) do
  cond do
    String.length(password) < 1 ->
      {:error, "Password cannot be empty"}
    not String.contains?(username, "@") ->
      {:error, "Username must be a valid email address for Microsoft auth"}
    String.length(client_id) < 1 ->
      {:error, "Client ID cannot be empty"}
    true ->
      :ok
  end
end
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Password grant | Full | Implemented | **Complete** |
| Warns on no refresh token | Yes | No | **Gap** |
| Azure password block | Yes (hard block) | Validation only | **Partial** |
| Optional client_id/secret | No | Yes | **Enhanced** |
| Scope handling | Full | Implemented | **Complete** |
| Grant types validation | Yes | No | **Gap** |

**Critical Gaps:**
1. No warning when refresh token is missing
2. Azure password flow should be blocked (not just validated)
3. No `grant_types_supported` validation from OIDC config

---

### 1.4 Bearer Token (Pre-existing Token)

#### Python Implementation

**File:** `weaviate/auth.py` (lines 58-76)

```python
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

**File:** `weaviate/connect/authentication.py` (lines 149-175)

```python
def _get_session_auth_bearer_token(self, config: AuthBearerToken) -> Result:
    token: Dict[str, Union[str, int]] = {"access_token": config.access_token}
    if config.expires_in is not None:
        token["expires_in"] = config.expires_in
    if config.refresh_token is not None:
        token["refresh_token"] = config.refresh_token

    if "refresh_token" not in token:
        _Warnings.auth_no_refresh_token(config.expires_in)

    return OAuth2Client(
        token=token,
        token_endpoint=await executor.aresult(self._get_token_endpoint()),
        client_id=self._client_id,
        default_timeout=AUTH_DEFAULT_TIMEOUT,
    )
```

#### Elixir Implementation

The Elixir implementation handles bearer tokens through the TokenManager GenServer, which can work with pre-existing tokens.

**File:** `lib/weaviate_ex/auth/oidc.ex` (TokenResponse struct, lines 21-42)

```elixir
@type t :: %__MODULE__{
  access_token: String.t() | nil,
  token_type: String.t() | nil,
  expires_in: non_neg_integer() | nil,
  refresh_token: String.t() | nil,
  id_token: String.t() | nil,
  scope: String.t() | nil,
  issued_at: DateTime.t() | nil
}
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Bearer token struct | `_BearerToken` | TokenResponse | **Complete** |
| Expires_in support | Yes | Yes | **Complete** |
| Refresh token support | Yes | Yes | **Complete** |
| Negative expiry warning | Yes | No | **Gap** |
| No refresh token warning | Yes | No | **Gap** |

**Minor Gaps:**
- No warning for negative expiration time
- No warning when refresh token is missing

---

## 2. Token Management and Refresh

### Python Implementation

**File:** `weaviate/connect/v4.py` (lines 508-590)

```python
def _create_background_token_refresh(self, _auth: Optional[_Auth] = None) -> None:
    """Create a background thread that periodically refreshes access and refresh tokens."""
    assert isinstance(self._client, (OAuth2Client, AsyncOAuth2Client))
    if "refresh_token" not in self._client.token and _auth is None:
        return

    # Event loop for async token refresh
    event_loop = (
        _EventLoopSingleton.get_instance()
        if isinstance(self._client, AsyncOAuth2Client)
        else None
    )

    expires_in: int = self._client.token.get("expires_in", 60)
    self._shutdown_background_event = Event()

    def refresh_token() -> None:
        if isinstance(self._client, AsyncOAuth2Client):
            self._client.token = event_loop.run_until_complete(
                self._client.refresh_token,
                url=self._client.metadata["token_endpoint"],
            )
        elif isinstance(self._client, OAuth2Client):
            self._client.token = self._client.refresh_token(
                url=self._client.metadata["token_endpoint"]
            )

    def periodic_refresh_token(refresh_time: int, _auth: Optional[_Auth]) -> None:
        while not self._shutdown_background_event.is_set():
            time.sleep(max(refresh_time, 1))
            try:
                if "refresh_token" in self._client.token:
                    refresh_token()
                else:
                    refresh_session()  # Re-authenticate for client credentials
                refresh_time = update_refresh_time()
            except HTTPError as exc:
                refresh_time = 1  # Retry after 1 second
                _Warnings.token_refresh_failed(exc)

    demon = Thread(target=periodic_refresh_token, args=(expires_in, _auth), daemon=True)
    demon.start()
```

**Key Features:**
- Background daemon thread for token refresh
- Handles both refresh token and client credentials re-authentication
- Event-based shutdown
- Retry on HTTP errors with 1-second delay
- Separate event loop for async clients
- Refresh 30 seconds before expiry by default

### Elixir Implementation

**File:** `lib/weaviate_ex/auth/token_manager.ex`

```elixir
defmodule WeaviateEx.Auth.TokenManager do
  use GenServer

  @default_refresh_buffer 60

  def handle_info(:fetch_token, state) do
    state = cancel_refresh_timer(state)

    case fetch_or_refresh_token(state) do
      {:ok, token} ->
        state = %{state | token: token}
        state = schedule_refresh(state)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("TokenManager: Failed to fetch token: #{inspect(reason)}")
        # Retry after a delay
        Process.send_after(self(), :fetch_token, 5000)
        {:noreply, state}
    end
  end

  defp fetch_or_refresh_token(%{token: nil, oidc_config: config, auth: auth}) do
    OIDC.get_token(config, auth)
  end

  defp fetch_or_refresh_token(%{token: token, oidc_config: config, auth: auth}) do
    if token.refresh_token do
      case OIDC.refresh_token(config, token.refresh_token) do
        {:ok, new_token} -> {:ok, new_token}
        {:error, _reason} -> OIDC.get_token(config, auth)  # Fallback
      end
    else
      OIDC.get_token(config, auth)
    end
  end

  defp schedule_refresh(%{token: token, refresh_buffer_seconds: buffer} = state) do
    case token.expires_in do
      nil -> state
      expires_in ->
        refresh_in = max(1, (expires_in - buffer) * 1000)
        timer_ref = Process.send_after(self(), :refresh_token, refresh_in)
        %{state | refresh_timer: timer_ref}
    end
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Background refresh | Daemon thread | GenServer | **Equivalent** |
| Refresh token support | Yes | Yes | **Complete** |
| Client credentials fallback | Yes | Yes | **Complete** |
| Retry on error | 1s delay | 5s delay | **Different** |
| Configurable buffer | 30s default | 60s default | **Different** |
| Graceful shutdown | Event-based | Process-based | **Equivalent** |
| Thread-safe access | Thread lock | GenServer | **Equivalent** |
| HTTP error warning | Yes | Logger.error | **Complete** |

**Minor Differences:**
- Python uses 30s buffer, Elixir uses 60s (more conservative)
- Different retry delay (1s vs 5s)
- Architecture differs (threading vs OTP) - both are appropriate for their platforms

---

## 3. Connection Pooling

### Python Implementation

**File:** `weaviate/config.py` (lines 8-31)

```python
@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20      # Max keepalive connections
    session_pool_maxsize: int = 100         # Max total connections
    session_pool_max_retries: int = 3       # HTTP transport retries
    session_pool_timeout: int = 5           # Pool acquisition timeout (seconds)
```

**Usage in v4.py (lines 217-244):**
```python
def _make_mounts(self, colour: executor.Colour):
    return {
        f"{key}://": AsyncHTTPTransport(
            limits=Limits(
                max_connections=self.__connection_config.session_pool_maxsize,
                max_keepalive_connections=self.__connection_config.session_pool_connections,
            ),
            proxy=Proxy(url=proxy),
            retries=self.__connection_config.session_pool_max_retries,
            trust_env=self.__trust_env,
        )
        for key, proxy in self._proxies.items()
        if key != "grpc"
    }
```

**Key Features:**
- Separate keepalive and max connection limits
- Transport-level retry configuration
- Pool acquisition timeout
- Per-protocol proxy configuration
- Applied via httpx transport mounts

### Elixir Implementation

**File:** `lib/weaviate_ex/client/pool.ex`

```elixir
defmodule WeaviateEx.Client.Pool do
  @type t :: %__MODULE__{
    size: pos_integer(),           # Default: 10
    overflow: non_neg_integer(),   # Default: 5
    strategy: strategy(),          # Default: :lifo
    timeout: pos_integer(),        # Default: 5000ms
    idle_timeout: pos_integer(),   # Default: 60000ms
    max_age: pos_integer() | nil   # Default: nil
  }

  def default_http do
    new(size: 10, overflow: 5, strategy: :lifo, timeout: 5000, idle_timeout: 60_000)
  end

  def default_grpc do
    new(size: 5, overflow: 2, strategy: :lifo, timeout: 10_000, idle_timeout: 120_000)
  end

  def to_finch_opts(%__MODULE__{} = pool) do
    [size: pool.size, count: 1]
  end

  def to_grpc_opts(%__MODULE__{} = pool) do
    [pool_size: pool.size, timeout: pool.timeout]
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Max connections | 100 | 10 | **Smaller default** |
| Keepalive connections | 20 | Via Finch | **Different** |
| Transport retries | 3 (via httpx) | Separate module | **Different** |
| Pool timeout | 5s | 5s | **Complete** |
| Idle timeout | Not explicit | 60s | **Enhanced** |
| Overflow connections | Not explicit | 5 | **Enhanced** |
| LIFO/FIFO strategy | httpx default | Configurable | **Enhanced** |
| gRPC pool config | Not exposed | Explicit | **Enhanced** |
| Max connection age | Not explicit | Configurable | **Enhanced** |

**Critical Gaps:**
1. Default pool size (100 vs 10) - may need tuning
2. Finch uses HTTP/2 multiplexing differently than httpx

**Recommendations:**
- Consider increasing Elixir default pool size
- Document HTTP/2 multiplexing behavior differences

---

## 4. HTTP Client Configuration (Timeouts, Retries)

### Python Implementation

**File:** `weaviate/config.py` (lines 53-58)

```python
class Timeout(BaseModel):
    """Timeouts for the different operations in the client."""
    query: Union[int, float] = Field(default=30, ge=0)
    insert: Union[int, float] = Field(default=90, ge=0)
    init: Union[int, float] = Field(default=2, ge=0)
```

**Timeout application (v4.py:605-634):**
```python
def __get_timeout(self, method, is_gql_query: bool) -> Timeout:
    timeout = None
    if method == "DELETE" or method == "PATCH" or method == "PUT":
        timeout = self.timeout_config.insert
    elif method == "GET" or method == "HEAD":
        timeout = self.timeout_config.query
    elif method == "POST" and is_gql_query:
        timeout = self.timeout_config.query
    elif method == "POST" and not is_gql_query:
        timeout = self.timeout_config.insert
    return Timeout(
        timeout=5.0,  # Connect/write timeout
        read=timeout,
        pool=self.__connection_config.session_pool_timeout,
    )
```

### Elixir Implementation

**File:** `lib/weaviate_ex/protocol/http/client.ex` (lines 83-100)

```elixir
defp get_operation_timeout(config, method, path, opts) do
  case Keyword.get(opts, :timeout) do
    nil ->
      timeout_config = Map.get(config, :timeout_config) || Timeout.new()

      if method == :post and String.contains?(path, "graphql") do
        timeout_config.query
      else
        Timeout.for_method(timeout_config, method)
      end

    explicit_timeout ->
      explicit_timeout
  end
end
```

**File:** `lib/weaviate_ex/config/timeout.ex` (lines in config.ex based on pattern)

```elixir
defstruct init: 2_000,
          query: 30_000,
          insert: 90_000

def for_method(%__MODULE__{query: query}, :get), do: query
def for_method(%__MODULE__{insert: insert}, :post), do: insert
def for_method(%__MODULE__{insert: insert}, :put), do: insert
def for_method(%__MODULE__{insert: insert}, :patch), do: insert
def for_method(%__MODULE__{insert: insert}, :delete), do: insert
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Query timeout | 30s | 30s | **Complete** |
| Insert timeout | 90s | 90s | **Complete** |
| Init timeout | 2s | 2s | **Complete** |
| Method-based mapping | Yes | Yes | **Complete** |
| GraphQL detection | `is_gql_query` param | Path-based | **Complete** |
| Connect timeout | 5s (separate) | Not separated | **Gap** |
| Pool timeout | Configurable | Fixed | **Gap** |
| Float support | Yes | No (integers) | **Minor Gap** |
| Pydantic validation | ge=0 | None | **Gap** |

**Minor Gaps:**
1. Connect/write timeouts not separated from read timeout
2. Pool timeout not exposed in Elixir
3. No validation for non-negative values

---

## 5. gRPC Connection Handling

### Python Implementation

**File:** `weaviate/connect/base.py` (lines 107-137)

```python
def _grpc_channel(self, proxies, grpc_msg_size, is_async):
    if grpc_msg_size is None:
        grpc_msg_size = MAX_GRPC_MESSAGE_LENGTH  # 10MB
    opts = [
        ("grpc.max_send_message_length", grpc_msg_size),
        ("grpc.max_receive_message_length", grpc_msg_size),
        ("grpc.default_authority", self.grpc.host),
    ]

    if (p := proxies.get("grpc")) is not None:
        options: list = [*opts, ("grpc.http_proxy", p)]

    if is_async:
        mod = grpc.aio
    if self.grpc.secure:
        return mod.secure_channel(
            target=self._grpc_target,
            credentials=ssl_channel_credentials(),
            options=options,
        )
    else:
        return mod.insecure_channel(target=self._grpc_target, options=options)
```

**gRPC stub creation (v4.py:361-369):**
```python
def open_connection_grpc(self, colour: executor.Colour) -> None:
    channel = self._connection_params._grpc_channel(
        proxies=self._proxies,
        grpc_msg_size=self._grpc_max_msg_size,
        is_async=colour == "async",
    )
    self._grpc_channel = channel
    self._grpc_stub = weaviate_pb2_grpc.WeaviateStub(self._grpc_channel)
```

### Elixir Implementation

**File:** `lib/weaviate_ex/grpc/channel.ex`

```elixir
def connect(config, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, @default_timeout)
  tls = Map.get(config, :tls, false)
  max_message_size = Map.get(config, :max_message_size, @default_max_message_size)

  host = "#{config.grpc_host}:#{config.grpc_port}"
  channel_opts = build_channel_opts(tls, max_message_size, timeout)

  case GRPC.Stub.connect(host, channel_opts) do
    {:ok, channel} -> {:ok, channel}
    {:error, reason} -> {:error, connection_error(reason)}
  end
end

defp build_channel_opts(tls, _max_message_size, timeout) do
  base_opts = [
    adapter: GRPC.Client.Adapters.Gun,
    adapter_opts: %{
      transport_opts: %{timeout: timeout}
    }
  ]

  cred_opts = if tls do
    [cred: GRPC.Credential.new(ssl: [])]
  else
    []
  end

  interceptors = [{GRPC.Client.Interceptors.Logger, level: :debug}]

  base_opts ++ cred_opts ++ [interceptors: interceptors]
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Secure channel | `ssl_channel_credentials()` | `GRPC.Credential.new(ssl: [])` | **Complete** |
| Insecure channel | Yes | Yes | **Complete** |
| Max message size | Configurable | Configurable | **Complete** |
| gRPC proxy | `grpc.http_proxy` | Not implemented | **Gap** |
| Default authority | `grpc.default_authority` | Not implemented | **Gap** |
| Async/sync channels | Both | Single (Gun adapter) | **Different** |
| Connection state | `_connected` flag | `connected?/1` function | **Complete** |
| Stub creation | Explicit | Via GRPC library | **Complete** |

**Critical Gaps:**
1. `grpc.default_authority` option not set (important for virtual hosting)
2. gRPC proxy support not fully implemented

---

## 6. Proxy Support

### Python Implementation

**File:** `weaviate/connect/base.py` (lines 148-199)

```python
class Proxies(BaseModel):
    """Proxy configurations for sending requests to Weaviate through a proxy."""
    http: Optional[str] = Field(default=None)
    https: Optional[str] = Field(default=None)
    grpc: Optional[str] = Field(default=None)

def _get_proxies(proxies: Union[dict, str, Proxies, None], trust_env: bool) -> Dict[str, str]:
    if proxies is not None:
        if isinstance(proxies, str):
            return {"http": proxies, "https": proxies, "grpc": proxies}
        if isinstance(proxies, dict):
            return proxies
        if isinstance(proxies, Proxies):
            return proxies.model_dump(exclude_none=True)

    if not trust_env:
        return {}

    # Environment variable reading (case-insensitive)
    http_proxy = (os.environ.get("HTTP_PROXY"), os.environ.get("http_proxy"))
    https_proxy = (os.environ.get("HTTPS_PROXY"), os.environ.get("https_proxy"))
    grpc_proxy = (os.environ.get("GRPC_PROXY"), os.environ.get("grpc_proxy"))

    proxies = {}
    if any(http_proxy):
        proxies["http"] = http_proxy[0] if http_proxy[0] else http_proxy[1]
    # ... same for https and grpc
    return proxies
```

**Usage in transport (base.py:118-121):**
```python
if (p := proxies.get("grpc")) is not None:
    options: list = [*opts, ("grpc.http_proxy", p)]
```

### Elixir Implementation

The Elixir implementation has proxy support in the config module but not fully integrated.

**File:** Based on architecture in `lib/weaviate_ex/client/config.ex`:

```elixir
# Proxy support would need to be added:
# - Environment variable reading
# - Finch proxy configuration
# - gRPC proxy configuration
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HTTP proxy | Full | Not integrated | **Gap** |
| HTTPS proxy | Full | Not integrated | **Gap** |
| gRPC proxy | Full | Not integrated | **Gap** |
| Environment variables | Case-insensitive | Not implemented | **Gap** |
| String-to-all-proxies | Yes | No | **Gap** |
| trust_env parameter | Yes | No | **Gap** |
| Proxies struct | Pydantic model | Not implemented | **Gap** |

**Critical Gaps:**
1. Full proxy support not implemented
2. No `trust_env` parameter for environment variable control
3. No gRPC HTTP/2 proxy support

---

## 7. Custom Headers

### Python Implementation

**File:** `weaviate/connect/v4.py` (lines 153-176)

```python
def __init__(self, ...):
    self._headers = {"content-type": "application/json"}
    self.__add_weaviate_embedding_service_header(connection_params.http.host)

    if additional_headers is not None:
        _validate_input(_ValidateArgument([dict], "additional_headers", additional_headers))
        self.__additional_headers = additional_headers
        for key, value in additional_headers.items():
            if value is None:
                raise WeaviateInvalidInputError(
                    f"Value for key '{key}' in headers cannot be None."
                )
            self._headers[key.lower()] = value

def __add_weaviate_embedding_service_header(self, wcd_host: str) -> None:
    if is_weaviate_domain(wcd_host):
        self._headers["X-Weaviate-Cluster-URL"] = "https://" + wcd_host
```

**gRPC header handling (v4.py:256-292):**
```python
def _prepare_grpc_headers(self) -> None:
    self.__metadata_list: List[Tuple[str, str]] = []
    if len(self.additional_headers):
        for key, val in self.additional_headers.items():
            if val is not None:
                self.__metadata_list.append((key.lower(), val))

    if self._auth is not None:
        if "X-Weaviate-Cluster-URL" in self._headers:
            self.__metadata_list.append(
                ("x-weaviate-cluster-url", self._headers["X-Weaviate-Cluster-URL"])
            )
        if isinstance(self._auth, AuthApiKey):
            self.__metadata_list.append(("authorization", "Bearer " + self._auth.api_key))
        else:
            self.__metadata_list.append(("authorization", "dummy_will_be_refreshed"))
```

### Elixir Implementation

**File:** `lib/weaviate_ex/client/config.ex` (lines 127-146)

```elixir
defp validate_additional_headers!(headers) when is_map(headers) do
  Enum.each(headers, fn
    {key, nil} ->
      raise ArgumentError,
            "Header values cannot be nil. Found nil value for header: #{key}"
    {_key, value} when is_binary(value) ->
      :ok
    {key, value} ->
      raise ArgumentError,
            "Header values must be strings. Found #{inspect(value)} for header: #{key}"
  end)
end
```

**File:** `lib/weaviate_ex/grpc/channel.ex` (lines 150-155)

```elixir
defp lowercase_header_keys(headers) when is_map(headers) do
  Map.new(headers, fn {key, value} ->
    {String.downcase(to_string(key)), value}
  end)
end
```

**WCS detection (config.ex:159-167):**
```elixir
@wcs_domains ["weaviate.network", "wcs.api.weaviate.io", "semi.network", "weaviate.cloud"]

@spec wcs_host?(String.t()) :: boolean()
def wcs_host?(host) when is_binary(host) do
  uri = URI.parse(host)
  domain = uri.host || host
  Enum.any?(@wcs_domains, &String.contains?(domain, &1))
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Header validation | Non-None values | Non-nil, string values | **Enhanced** |
| Lowercase keys | Yes | Yes (gRPC only) | **Partial** |
| X-Weaviate-Cluster-URL | Auto-added | `maybe_add_wcs_headers/1` | **Complete** |
| WCS domain detection | Yes | Yes | **Complete** |
| gRPC metadata propagation | Yes | Yes | **Complete** |
| Integration headers | `set_integrations()` | `additional_headers` | **Partial** |

**Minor Gaps:**
1. HTTP headers not lowercased (only gRPC)
2. No `set_integrations()` method for third-party API keys

---

## 8. SSL/TLS Configuration

### Python Implementation

**File:** `weaviate/connect/base.py` (lines 127-133)

```python
if self.grpc.secure:
    return mod.secure_channel(
        target=self._grpc_target,
        credentials=ssl_channel_credentials(),  # Uses system certificates
        options=options,
    )
else:
    return mod.insecure_channel(target=self._grpc_target, options=options)
```

**HTTP TLS (v4.py:217-228):**
```python
AsyncHTTPTransport(
    limits=Limits(...),
    proxy=Proxy(url=proxy),
    retries=self.__connection_config.session_pool_max_retries,
    trust_env=self.__trust_env,  # Trust system certificates
)
```

### Elixir Implementation

**File:** `lib/weaviate_ex/grpc/channel.ex` (lines 169-174)

```elixir
cred_opts = if tls do
  [cred: GRPC.Credential.new(ssl: [])]  # Empty options = system certs
else
  []
end
```

**File:** `lib/weaviate_ex/client/config.ex` (lines 107-110)

```elixir
@spec use_tls?(t()) :: boolean()
def use_tls?(%__MODULE__{base_url: base_url, grpc_port: port}) do
  String.starts_with?(base_url, "https://") or port == 443
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| gRPC TLS | `ssl_channel_credentials()` | `GRPC.Credential.new(ssl: [])` | **Complete** |
| HTTP TLS | httpx trust_env | Finch default | **Complete** |
| System cert trust | Yes | Yes | **Complete** |
| Custom CA certs | Not exposed | Not exposed | **Equivalent** |
| Client certificates | Not exposed | Not exposed | **Equivalent** |
| TLS auto-detection | Via secure flag | Via URL/port | **Complete** |
| Custom SSL options | Not exposed | Not exposed | **Equivalent** |
| gRPC default authority | Yes | No | **Gap** |

**Critical Gaps:**
1. `grpc.default_authority` not set (important for SNI/virtual hosting)
2. No custom SSL options exposed

---

## 9. Health Checks

### Python Implementation

**File:** `weaviate/connect/v4.py` (lines 294-334)

```python
def _ping_grpc(self, colour: executor.Colour) -> Union[None, Awaitable[None]]:
    """Performs a grpc health check and raises WeaviateGRPCUnavailableError if not."""
    assert self._grpc_channel is not None

    try:
        res = self._grpc_channel.unary_unary(
            "/grpc.health.v1.Health/Check",
            request_serializer=health_weaviate_pb2.WeaviateHealthCheckRequest.SerializeToString,
            response_deserializer=health_weaviate_pb2.WeaviateHealthCheckResponse.FromString,
        )(health_weaviate_pb2.WeaviateHealthCheckRequest(), timeout=self.timeout_config.init)
        # ... handle response
    except Exception as e:
        raise WeaviateGRPCUnavailableError(...)
```

**HTTP readiness check (v4.py:932-950):**
```python
def wait_for_weaviate(self, startup_period: int) -> None:
    for _i in range(startup_period):
        try:
            executor.result(
                self.get("/.well-known/ready", check_is_connected=False)
            ).raise_for_status()
            return
        except (ConnectError, ReadError, TimeoutError, HTTPStatusError):
            time.sleep(1)
    raise WeaviateStartUpError(...)
```

### Elixir Implementation

**File:** `lib/weaviate_ex/grpc/services/health.ex`

```elixir
defmodule WeaviateEx.GRPC.Services.Health do
  @spec check(GRPC.Channel.t(), health_opts()) ::
          {:ok, :serving} | {:error, Error.t()}
  def check(channel, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    service = Keyword.get(opts, :service, "")

    request = %WeaviateHealthCheckRequest{service: service}

    case execute_health_check(channel, request, timeout) do
      {:ok, %WeaviateHealthCheckResponse{status: :SERVING}} ->
        {:ok, :serving}
      {:ok, %WeaviateHealthCheckResponse{status: :NOT_SERVING}} ->
        {:error, Error.exception(type: :service_unavailable, ...)}
      {:error, error} ->
        {:error, error}
    end
  end

  @spec wait_for_ready(GRPC.Channel.t(), keyword()) :: :ok | {:error, :timeout | Error.t()}
  def wait_for_ready(channel, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    interval = Keyword.get(opts, :interval, 1_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_ready(channel, deadline, interval, opts)
  end

  @spec ping(GRPC.Channel.t() | nil, keyword()) :: :ok | {:error, term()}
  def ping(channel, opts \\ [])
  def ping(nil, _opts), do: {:error, :no_channel}
  def ping(channel, opts) do
    case check(channel, opts) do
      {:ok, :serving} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| gRPC health check | Full | Full | **Complete** |
| HTTP readiness | `/.well-known/ready` | Via HTTP client | **Complete** |
| wait_for_weaviate | Startup period loop | `wait_for_ready/2` | **Complete** |
| Health check timeout | Uses init timeout | Configurable | **Complete** |
| NOT_SERVING handling | Error | Error | **Complete** |
| UNKNOWN handling | Not explicit | Error | **Enhanced** |
| Polling interval | 1s fixed | Configurable | **Enhanced** |
| healthy?/1 helper | No | Yes | **Enhanced** |

**Gaps:** None - Health check support is comprehensive and matches or exceeds Python.

---

## 10. Retry Logic and Backoff Strategies

### Python Implementation

**File:** `weaviate/retry.py`

```python
class _Retry:
    def __init__(self, n: float = 4) -> None:
        self.n = n

    async def awith_exponential_backoff(self, count, error, f, *args, **kwargs) -> T:
        try:
            return await f(*args, **kwargs)
        except AioRpcError as e:
            if e.code() != StatusCode.UNAVAILABLE:
                raise e
            logger.info(f"{error} received exception: {e}. Retrying in {2**count} seconds")
            await asyncio.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return await self.awith_exponential_backoff(count + 1, error, f, *args, **kwargs)

    def with_exponential_backoff(self, count, error, f, *args, **kwargs) -> T:
        # Same logic, synchronous version
```

**gRPC usage (v4.py:952-970):**
```python
def grpc_search(self, request):
    res = _Retry(4).with_exponential_backoff(
        0,
        f"Searching in collection {request.collection}",
        self.grpc_stub.Search,
        request,
        metadata=self.grpc_headers(),
        timeout=self.timeout_config.query,
    )
```

### Elixir Implementation

**File:** `lib/weaviate_ex/grpc/retry.ex`

```elixir
defmodule WeaviateEx.GRPC.Retry do
  @default_max_retries 4
  @default_base_delay_ms 1000
  @max_backoff_ms 32_000

  # Retryable gRPC status codes
  @unavailable 14
  @resource_exhausted 8
  @aborted 10
  @deadline_exceeded 4

  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    do_retry(fun, 0, max_retries, base_delay_ms)
  end

  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    delay = :math.pow(2, attempt) * 1000
    min(trunc(delay), @max_backoff_ms)
  end

  def retryable?(%GRPC.RPCError{status: status}) do
    status in [@unavailable, @resource_exhausted, @aborted, @deadline_exceeded]
  end
end
```

**File:** `lib/weaviate_ex/protocol/http/retry.ex`

```elixir
defmodule WeaviateEx.Protocol.HTTP.Retry do
  @default_max_retries 3
  @default_base_delay_ms 500
  @max_backoff_ms 32_000

  # Transport errors that are safe to retry
  @retryable_reasons [:econnrefused, :econnreset, :timeout, :closed, :nxdomain]

  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    do_retry(fun, 0, max_retries, base_delay_ms)
  end

  def retryable_transport_error?(%Mint.TransportError{reason: reason}) do
    reason in @retryable_reasons
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| gRPC retry | UNAVAILABLE only | Multiple status codes | **Enhanced** |
| HTTP retry | Via transport | Via Retry module | **Complete** |
| Exponential backoff | 2^n seconds | 2^n * base_ms | **Complete** |
| Max backoff cap | Not explicit | 32 seconds | **Enhanced** |
| Configurable retries | Default 4 | Default 4 (gRPC), 3 (HTTP) | **Complete** |
| Retryable status codes | UNAVAILABLE | UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED, DEADLINE_EXCEEDED | **Enhanced** |
| Logging | logger.info | Not shown | **Gap** |
| Async support | Yes | N/A (BEAM) | N/A |

**Enhancements in Elixir:**
- More gRPC status codes considered retryable
- Explicit max backoff cap
- Separate HTTP and gRPC retry modules
- Configurable base delay

**Minor Gaps:**
- No logging on retry (could add Logger calls)

---

## 11. Rate Limiting

### Python Implementation

Python does not have explicit client-side rate limiting in the core client. Rate limit headers are processed by httpx but not exposed to users programmatically.

### Elixir Implementation

**File:** `lib/weaviate_ex/protocol/http/rate_limit.ex`

```elixir
defmodule WeaviateEx.Protocol.HTTP.RateLimit do
  @type t :: %__MODULE__{
    limit: non_neg_integer() | nil,
    remaining: non_neg_integer() | nil,
    reset_at: DateTime.t() | nil
  }

  @spec from_headers(list({String.t(), String.t()})) :: t()
  def from_headers(headers) when is_list(headers) do
    headers_map = normalize_headers(headers)
    %__MODULE__{
      limit: parse_int(headers_map["x-ratelimit-limit"]),
      remaining: parse_int(headers_map["x-ratelimit-remaining"]),
      reset_at: parse_reset(headers_map["x-ratelimit-reset"])
    }
  end

  @spec should_wait?(t()) :: {:wait, non_neg_integer()} | :ok
  def should_wait?(%__MODULE__{remaining: 0, reset_at: reset_at}) when not is_nil(reset_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(reset_at, now, :millisecond)
    if diff > 0, do: {:wait, diff}, else: :ok
  end
  def should_wait?(_), do: :ok

  @spec near_limit?(t(), number()) :: boolean()
  def near_limit?(%__MODULE__{} = rate_limit, threshold_percent \\ 10) do
    case remaining_percent(rate_limit) do
      nil -> false
      percent -> percent < threshold_percent
    end
  end

  @spec remaining_percent(t()) :: float() | nil
  def remaining_percent(%__MODULE__{limit: limit, remaining: remaining})
      when is_integer(limit) and is_integer(remaining) and limit > 0 do
    remaining / limit * 100
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Rate limit header parsing | Not exposed | Full | **Enhanced** |
| should_wait? helper | No | Yes | **Enhanced** |
| near_limit? threshold | No | Yes | **Enhanced** |
| remaining_percent | No | Yes | **Enhanced** |
| stale? detection | No | Yes | **Enhanced** |
| Human-readable summary | No | Yes | **Enhanced** |
| Automatic waiting | No | Helper only | **Partial** |

**Elixir Enhancements:**
- Full rate limit header parsing
- Utility functions for client-side rate limiting decisions
- Threshold-based warnings
- Better developer experience

---

## Summary: Critical Gaps

### High Priority (Should Fix Before Production)

1. **Proxy Support** (Medium effort)
   - HTTP/HTTPS proxy not integrated
   - gRPC proxy not implemented
   - No `trust_env` environment variable control

2. **gRPC Default Authority** (Low effort)
   - Add `grpc.default_authority` option for virtual hosting

3. **Azure Password Flow Block** (Low effort)
   - Block (not just validate) password flow for Azure endpoints

### Medium Priority

4. **Scope String Parsing** (Low effort)
   - Accept space-separated scope strings like Python

5. **Default Scopes from OIDC** (Medium effort)
   - Read default scopes from OIDC discovery response

6. **WCS gRPC Host Pattern** (Low effort)
   - Use `{ident}.grpc.{domain}` for `.weaviate.network` domains

7. **Version Compatibility Check** (Low effort)
   - Check Weaviate version >= 1.27.0 on connect

### Low Priority

8. **Token Expiry Warnings** (Low effort)
   - Warn when no refresh token returned
   - Warn on negative expiry time

9. **Pool Size Alignment** (Evaluation needed)
   - Consider increasing default pool size

10. **Retry Logging** (Low effort)
    - Add Logger calls for retry attempts

11. **Connect/Read Timeout Separation** (Medium effort)
    - Separate connect and read timeouts like Python

---

## Recommendations by Area

### Authentication
- Complete scope string parsing
- Add OIDC default scope reading
- Block Azure password flow
- Add expiry warnings

### Connection
- Implement full proxy support with trust_env
- Add gRPC default authority
- Add version compatibility check
- Consider force reconnect option

### Retry/Rate Limiting
- Already excellent - Elixir exceeds Python in several areas
- Add retry logging for observability

### SSL/TLS
- Add gRPC default authority for SNI
- Consider exposing custom SSL options

---

## File References

### Python Client Files Analyzed
| File | Lines | Purpose |
|------|-------|---------|
| `weaviate/auth.py` | 137 | Auth type definitions |
| `weaviate/connect/authentication.py` | 261 | OIDC flow implementation |
| `weaviate/connect/base.py` | 200 | ConnectionParams, proxies, gRPC channel |
| `weaviate/connect/v4.py` | 1262 | Connection lifecycle, HTTP/gRPC handling |
| `weaviate/connect/helpers.py` | 661 | Connect helper functions |
| `weaviate/config.py` | 90 | Timeout, Proxies, ConnectionConfig |
| `weaviate/retry.py` | 62 | gRPC retry with backoff |

### Elixir Client Files Analyzed
| File | Lines | Purpose |
|------|-------|---------|
| `lib/weaviate_ex/auth/token_manager.ex` | 267 | GenServer for token refresh |
| `lib/weaviate_ex/auth/oidc.ex` | 330 | OIDC discovery and token exchange |
| `lib/weaviate_ex/auth/azure.ex` | 221 | Azure-specific OIDC handling |
| `lib/weaviate_ex/client/config.ex` | 218 | Client configuration |
| `lib/weaviate_ex/client/pool.ex` | 154 | Connection pool configuration |
| `lib/weaviate_ex/client/state.ex` | 119 | Connection state tracking |
| `lib/weaviate_ex/connect.ex` | 211 | Connection factory functions |
| `lib/weaviate_ex/grpc/channel.ex` | 208 | gRPC channel management |
| `lib/weaviate_ex/grpc/retry.ex` | 174 | gRPC retry with backoff |
| `lib/weaviate_ex/grpc/services/health.ex` | 208 | gRPC health checks |
| `lib/weaviate_ex/protocol/http/client.ex` | 166 | HTTP protocol implementation |
| `lib/weaviate_ex/protocol/http/retry.ex` | 175 | HTTP transport retry |
| `lib/weaviate_ex/protocol/http/rate_limit.ex` | 219 | Rate limit header parsing |
| `lib/weaviate_ex/client.ex` | 354 | Main client module |
