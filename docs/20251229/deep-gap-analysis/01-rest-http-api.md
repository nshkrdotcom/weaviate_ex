# Deep Gap Analysis: REST/HTTP API Implementation

**Date**: 2025-12-29
**Focus**: HTTP client implementation comparison between Python canonical client and Elixir port
**Reference**: `weaviate-python-client/weaviate/connect/` and `lib/weaviate_ex/protocol/http/`

---

## Executive Summary

This analysis compares the REST/HTTP API implementation between the canonical Python Weaviate client and the WeaviateEx Elixir port. The analysis reveals that while WeaviateEx has a functional HTTP implementation, there are significant gaps in advanced features that the Python client provides for production deployments.

### Key Findings

| Category | Python Status | Elixir Status | Gap Severity |
|----------|---------------|---------------|--------------|
| HTTP Client Library | httpx (async/sync) | Finch | Equivalent |
| Connection Pooling | Full pool config | Basic Finch config | Medium |
| Timeout Configuration | Per-operation type | Single timeout | High |
| Retry Logic (HTTP) | Transport-level | Not implemented | High |
| Proxy Support | Full (HTTP/HTTPS/gRPC) | Implemented | Low |
| OIDC Authentication | Full OAuth2 flows | Implemented | Low |
| Rate Limit Headers | Supported | Not implemented | Medium |
| Error Handling | Rich exception hierarchy | Basic error struct | Medium |
| SSL/TLS Configuration | Configurable | Implicit | Low |

### Overall Assessment
- **Python**: Production-ready with comprehensive HTTP features
- **Elixir**: Functional but missing key production features (HTTP retry, granular timeouts)

---

## 1. HTTP Client Implementation

### 1.1 Python Implementation (`weaviate/connect/v4.py`)

The Python client uses **httpx** for HTTP/2 and async support:

```python
# File: weaviate-python-client/weaviate/connect/v4.py

from httpx import (
    AsyncClient,
    AsyncHTTPTransport,
    Client,
    HTTPTransport,
    Limits,
    Proxy,
    Timeout,
)

Session = Union[Client, OAuth2Client]
AsyncSession = Union[AsyncClient, AsyncOAuth2Client]
```

**Key Features**:
- Dual sync/async client support via `Client` and `AsyncClient`
- OAuth2 integration via `authlib` (`OAuth2Client`, `AsyncOAuth2Client`)
- HTTP/2 support built into httpx
- Transport-level retry configuration

**Client Creation (`_make_client` method, lines 188-206)**:
```python
def _make_client(self, colour: executor.Colour) -> Union[AsyncClient, Client]:
    if colour == "async":
        return AsyncClient(
            headers=self._headers,
            mounts=self._make_mounts(colour),
            trust_env=self.__trust_env,
        )
    if colour == "sync":
        return Client(
            headers=self._headers,
            mounts=self._make_mounts(colour),
            trust_env=self.__trust_env,
        )
```

### 1.2 Elixir Implementation (`lib/weaviate_ex/protocol/http/client.ex`)

The Elixir client uses **Finch** for HTTP:

```elixir
# File: lib/weaviate_ex/protocol/http/client.ex

defmodule WeaviateEx.Protocol.HTTP.Client do
  @behaviour WeaviateEx.Protocol

  @impl true
  def request(%Client{config: config} = _client, method, path, body, opts) do
    url = build_url(config.base_url, path)
    headers = build_headers(config, body)
    encoded_body = encode_body(body)
    finch_request = Finch.build(method, url, headers, encoded_body)
    timeout = Keyword.get(opts, :timeout, config.timeout)

    case Finch.request(finch_request, WeaviateEx.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: response_body}}
      when status >= 200 and status < 300 ->
        parse_response(response_body)
      # ... error handling
    end
  end
end
```

**Key Features**:
- Single synchronous implementation (no async variant)
- Uses Finch with built-in connection pooling
- Simple request/response pattern
- Basic error handling

### 1.3 Comparison Table: HTTP Client Core

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| HTTP Library | httpx | Finch | Different, both excellent |
| HTTP/2 Support | Built-in | Via Finch/Mint | Equivalent |
| Async Support | Full (async/sync) | Sync only | **Gap**: No async client |
| Request Building | `build_request()` | `Finch.build()` | Equivalent |
| Response Handling | Callbacks, exceptions | Pattern matching | Equivalent |
| JSON Encoding | httpx built-in | Jason | Equivalent |

---

## 2. Connection Pooling and Timeouts

### 2.1 Python Connection Configuration (`weaviate/config.py`)

```python
# File: weaviate-python-client/weaviate/config.py

@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20     # Keep-alive connections
    session_pool_maxsize: int = 100        # Maximum pool size
    session_pool_max_retries: int = 3      # Transport-level retries
    session_pool_timeout: int = 5          # Pool acquire timeout

class Timeout(BaseModel):
    """Timeouts for the different operations in the client."""
    query: Union[int, float] = Field(default=30, ge=0)
    insert: Union[int, float] = Field(default=90, ge=0)
    init: Union[int, float] = Field(default=2, ge=0)
```

**Transport Configuration (`_make_mounts` method, lines 214-244)**:
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

### 2.2 Elixir Connection Configuration

**Pool Configuration (`lib/weaviate_ex/client/pool.ex`)**:
```elixir
defmodule WeaviateEx.Client.Pool do
  defstruct size: 10,
            overflow: 5,
            strategy: :lifo,
            timeout: 5000,
            idle_timeout: 60_000,
            max_age: nil

  def to_finch_opts(%__MODULE__{} = pool) do
    [size: pool.size, count: 1]
  end
end
```

**Timeout Configuration (`lib/weaviate_ex/config/timeout.ex`)**:
```elixir
defmodule WeaviateEx.Config.Timeout do
  @default_init 2_000
  @default_query 30_000
  @default_insert 90_000

  defstruct init: @default_init,
            query: @default_query,
            insert: @default_insert

  def for_method(%__MODULE__{query: query}, :get), do: query
  def for_method(%__MODULE__{insert: insert}, :post), do: insert
  # ...
end
```

### 2.3 Comparison Table: Connection Pooling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Max Connections | `session_pool_maxsize=100` | `size: 10` | **Gap**: Lower default |
| Keep-alive Connections | `session_pool_connections=20` | Via Finch | Implicit |
| Pool Acquire Timeout | `session_pool_timeout=5` | `timeout: 5000` | Equivalent |
| Connection Recycling | Not explicit | `max_age: nil` | Elixir has option |
| Idle Timeout | Via httpx | `idle_timeout: 60_000` | Elixir has explicit |
| Pool Strategy | LIFO implicit | `:lifo` configurable | Elixir better |
| Transport Retries | `session_pool_max_retries=3` | **Not implemented** | **Critical Gap** |

### 2.4 Critical Gap: HTTP Transport-Level Retries

**Python has transport-level retries**:
```python
AsyncHTTPTransport(
    retries=self.__connection_config.session_pool_max_retries,  # 3 retries
)
```

**Elixir is missing this feature** - no automatic retry on transport errors (connection refused, timeout, etc.)

**Recommendation**: Implement an HTTP retry wrapper in Elixir:
```elixir
defmodule WeaviateEx.HTTP.Retry do
  def with_retry(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 500)
    # Implement exponential backoff
  end
end
```

---

## 3. Timeout Configuration

### 3.1 Python Per-Operation Timeouts (`v4.py`, lines 605-634)

```python
def __get_timeout(
    self,
    method: Literal["DELETE", "GET", "HEAD", "PATCH", "POST", "PUT"],
    is_gql_query: bool,
) -> Timeout:
    """Get the timeout for the request based on operation type."""
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
        timeout=5.0,           # Default for connect, write, pool
        read=timeout,          # Custom read timeout
        pool=self.__connection_config.session_pool_timeout,
    )
```

**Key insight**: Python uses **granular httpx Timeout** with different values for:
- `connect`: Socket connection timeout (5s)
- `read`: Response read timeout (varies by operation)
- `write`: Request write timeout (5s)
- `pool`: Pool acquire timeout (configurable)

### 3.2 Elixir Timeout Configuration

**Current Implementation (`protocol/http/client.ex`)**:
```elixir
def request(%Client{config: config} = _client, method, path, body, opts) do
  timeout = Keyword.get(opts, :timeout, config.timeout)

  case Finch.request(finch_request, WeaviateEx.Finch, receive_timeout: timeout) do
    # ...
  end
end
```

**Gap Analysis**:
- Elixir uses a single `timeout` value
- No differentiation between connect/read/write/pool timeouts
- `Timeout` module exists but **not used in HTTP client**

### 3.3 Recommendation

Update `WeaviateEx.Protocol.HTTP.Client` to use the `Timeout` module:

```elixir
def request(%Client{config: config} = _client, method, path, body, opts) do
  timeout_config = config.timeout_config || Timeout.new()
  operation_timeout = Timeout.for_method(timeout_config, method)

  finch_opts = [
    receive_timeout: operation_timeout,
    pool_timeout: 5_000  # Add pool timeout
  ]

  case Finch.request(finch_request, WeaviateEx.Finch, finch_opts) do
    # ...
  end
end
```

---

## 4. REST Endpoint Coverage

### 4.1 Python Endpoint Methods (`v4.py`, lines 749-862)

```python
class _ConnectionBase:
    def delete(self, path, weaviate_object=None, params=None, ...) -> Response
    def patch(self, path, weaviate_object, params=None, ...) -> Response
    def post(self, path, weaviate_object, params=None, ...) -> Response
    def put(self, path, weaviate_object, params=None, ...) -> Response
    def get(self, path, params=None, ...) -> Response
    def head(self, path, params=None, ...) -> Response
    def get_meta(self, check_is_connected=True) -> Dict[str, str]
    def get_open_id_configuration(self) -> Optional[Dict[str, Any]]
```

### 4.2 Elixir Endpoint Methods

**HTTP Client (`protocol/http/client.ex`)**:
```elixir
def request(%Client{config: config} = _client, method, path, body, opts)
# Single method dispatches to: :get, :post, :put, :patch, :delete, :head
```

**API Modules (`lib/weaviate_ex/api/*.ex`)**:
- `Collections` - Schema operations
- `Data` - Object CRUD
- `Batch` - Batch operations
- `Tenants` - Multi-tenancy
- `RBAC` - Role-based access control
- `Cluster` - Cluster management
- `Aliases` - Collection aliases

### 4.3 REST Endpoint Comparison

| Endpoint Category | Python Methods | Elixir Status | Gap |
|-------------------|----------------|---------------|-----|
| Schema (`/v1/schema`) | Full CRUD | Implemented | None |
| Objects (`/v1/objects`) | Full CRUD + validate | Implemented | None |
| Batch (`/v1/batch`) | Objects, refs, delete | Implemented | None |
| GraphQL (`/v1/graphql`) | POST | Implemented | None |
| Meta (`/v1/meta`) | GET | Implemented | None |
| Nodes (`/v1/nodes`) | GET | Implemented | None |
| Backups (`/v1/backups`) | Full lifecycle | Implemented | None |
| Tenants (`/v1/schema/.../tenants`) | Full CRUD | Implemented | None |
| OIDC (`/.well-known/openid-configuration`) | GET | Implemented | None |
| Ready (`/.well-known/ready`) | GET | Implemented | None |
| Live (`/.well-known/live`) | GET | Implemented | None |
| Roles (`/v1/authz/roles`) | Full CRUD | Implemented | None |
| Users (`/v1/users`) | Full CRUD | Implemented | None |

**Conclusion**: REST endpoint coverage is comprehensive in Elixir.

---

## 5. Request/Response Handling Patterns

### 5.1 Python Request Flow (`v4.py`, lines 657-694)

```python
def _send(
    self,
    method: Literal["DELETE", "GET", "HEAD", "PATCH", "POST", "PUT"],
    *,
    url: str,
    error_msg: str,
    status_codes: Optional[_ExpectedStatusCodes],
    is_gql_query: bool = False,
    weaviate_object: Optional[JSONPayload] = None,
    params: Optional[Dict[str, Any]] = None,
    check_is_connected: bool = True,
) -> executor.Result[Response]:
    # 1. Connection check
    if check_is_connected and not self.is_connected():
        raise WeaviateClosedClientError()

    # 2. Embedded DB check
    if self.embedded_db is not None:
        self.embedded_db.ensure_running()

    # 3. Build request with latest headers (OIDC token refresh)
    request = self._client.build_request(
        method, url,
        json=weaviate_object,
        params=params,
        headers=self.__get_latest_headers(),
        timeout=self.__get_timeout(method, is_gql_query),
    )

    # 4. Execute with callbacks
    return executor.execute(
        response_callback=resp,
        exception_callback=exc,
        method=self._client.send,
        request=request,
    )
```

**Key Features**:
- Connection state validation
- Embedded DB lifecycle management
- Dynamic header refresh (OAuth tokens)
- Executor pattern for sync/async unification

### 5.2 Elixir Request Flow (`protocol/http/client.ex`)

```elixir
def request(%Client{config: config} = _client, method, path, body, opts) do
  url = build_url(config.base_url, path)
  headers = build_headers(config, body)
  encoded_body = encode_body(body)
  finch_request = Finch.build(method, url, headers, encoded_body)
  timeout = Keyword.get(opts, :timeout, config.timeout)

  case Finch.request(finch_request, WeaviateEx.Finch, receive_timeout: timeout) do
    {:ok, %Finch.Response{status: status, body: response_body}}
    when status >= 200 and status < 300 ->
      parse_response(response_body)

    {:ok, %Finch.Response{status: status, body: response_body}} ->
      handle_error_response(status, response_body)

    {:error, %Mint.TransportError{reason: :econnrefused}} ->
      {:error, Error.exception(type: :connection_error, message: "Connection refused")}

    {:error, %Mint.TransportError{reason: :timeout}} ->
      {:error, Error.exception(type: :timeout_error, message: "Request timeout")}

    {:error, reason} ->
      {:error, Error.exception(type: :connection_error, message: inspect(reason))}
  end
end
```

### 5.3 Gaps in Request Handling

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Connection state check | `is_connected()` | Not enforced | **Gap** |
| Token refresh | `__get_latest_headers()` | Not implemented | **Gap** |
| Expected status codes | `_ExpectedStatusCodes` | Implicit (2xx check) | Minor |
| Error context | `error_msg` parameter | Not included | Minor |
| Embedded DB | `ensure_running()` | Different approach | Design difference |

### 5.4 Recommendation: Dynamic Token Refresh

Add token refresh support:

```elixir
defp build_headers(config, body) do
  headers = base_headers()

  headers =
    case get_auth_headers(config) do
      {:ok, auth_headers} -> auth_headers ++ headers
      _ -> headers
    end

  add_additional_headers(headers, config)
end

defp get_auth_headers(%{auth: %{type: :oidc_client_credentials} = auth, token_manager: tm}) do
  WeaviateEx.Auth.get_oidc_headers(tm)
end

defp get_auth_headers(%{api_key: key}) when is_binary(key) do
  {:ok, [{"authorization", "Bearer #{key}"}]}
end
```

---

## 6. Error Handling

### 6.1 Python Exception Hierarchy (`weaviate/exceptions.py`)

```python
class WeaviateBaseError(Exception)
    # HTTP Errors
    UnexpectedStatusCodeError      # Unexpected HTTP status
    InsufficientPermissionsError   # 403 Forbidden
    ResponseCannotBeDecodedError   # JSON decode failure

    # Connection Errors
    WeaviateConnectionError        # Connection failed
    WeaviateTimeoutError           # Request timeout
    WeaviateClosedClientError      # Client was closed
    WeaviateStartUpError           # Startup failed

    # Auth Errors
    AuthenticationFailedError      # Auth failed
    MissingScopeError              # OIDC scope missing

    # Query Errors
    WeaviateQueryError             # Query failed
    WeaviateBatchError             # Batch operation failed
    WeaviateRetryError             # Retry exhausted

    # Validation Errors
    WeaviateInvalidInputError      # Invalid input
    SchemaValidationError          # Schema validation failed
```

### 6.2 Elixir Error Structure (`lib/weaviate_ex/error.ex`)

```elixir
defmodule WeaviateEx.Error do
  defexception [:type, :message, :details, :status_code]

  # Type atoms:
  # :bad_request, :authentication_failed, :forbidden, :not_found,
  # :conflict, :validation_error, :server_error, :service_unavailable,
  # :connection_error, :timeout_error, :retry_exhausted, ...

  def from_status_code(400), do: :bad_request
  def from_status_code(401), do: :authentication_failed
  def from_status_code(403), do: :forbidden
  def from_status_code(404), do: :not_found
  # ...
end

defmodule WeaviateEx.Error.ClosedClientError do
  defexception [:message, :closed_at]
end
```

### 6.3 Error Handling Comparison

| Error Type | Python | Elixir | Gap |
|------------|--------|--------|-----|
| Base exception | `WeaviateBaseError` | `WeaviateEx.Error` | Equivalent |
| HTTP status mapping | Rich classes | `:type` atoms | Equivalent |
| Status code access | `.status_code` property | `.status_code` field | Equivalent |
| Error body | `.error` property | `.details` map | Equivalent |
| Closed client | `WeaviateClosedClientError` | `ClosedClientError` | Equivalent |
| Permission denied | `InsufficientPermissionsError` | `:forbidden` type | Equivalent |
| Retry exhausted | `WeaviateRetryError(count)` | `:retry_exhausted` type | Equivalent |

**Conclusion**: Error handling is largely equivalent.

---

## 7. Authentication Header Handling

### 7.1 Python Authentication (`v4.py`, `authentication.py`)

**Header Construction (`_ConnectionBase.__init__`, lines 123-177)**:
```python
def __init__(self, ...):
    self._headers = {"content-type": "application/json"}

    # Weaviate Cloud service header
    if is_weaviate_domain(host):
        self._headers["X-Weaviate-Cluster-URL"] = "https://" + host

    # Additional headers
    if additional_headers is not None:
        for key, value in additional_headers.items():
            self._headers[key.lower()] = value

    # API Key authentication
    if isinstance(auth_client_secret, AuthApiKey):
        self._headers["authorization"] = "Bearer " + auth_client_secret.api_key
```

**OIDC Token Refresh (`_create_background_token_refresh`, lines 508-590)**:
```python
def _create_background_token_refresh(self, _auth: Optional[_Auth] = None) -> None:
    """Background thread for token refresh."""
    expires_in = self._client.token.get("expires_in", 60)
    self._shutdown_background_event = Event()

    def periodic_refresh_token(refresh_time: int, _auth):
        while not self._shutdown_background_event.is_set():
            time.sleep(max(refresh_time, 1))
            if "refresh_token" in self._client.token:
                refresh_token()
            else:
                refresh_session()
            refresh_time = update_refresh_time()

    Thread(target=periodic_refresh_token, daemon=True).start()
```

### 7.2 Elixir Authentication (`lib/weaviate_ex/auth.ex`, `auth/oidc.ex`)

**Auth Module**:
```elixir
defmodule WeaviateEx.Auth do
  def api_key(key), do: %{type: :api_key, api_key: key}
  def bearer_token(token, opts \\ [])
  def client_credentials(client_id, client_secret, opts \\ [])
  def client_password(username, password, opts \\ [])

  def to_headers(%{type: :api_key, api_key: key}) do
    [{"Authorization", "Bearer #{key}"}]
  end

  def to_headers(%{type: :bearer_token, access_token: token}) do
    [{"Authorization", "Bearer #{token}"}]
  end
end
```

**Token Manager (`lib/weaviate_ex/auth/token_manager.ex`)**: GenServer for token lifecycle

### 7.3 Authentication Comparison

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| API Key | `AuthApiKey` class | `api_key/1` function | Equivalent |
| Bearer Token | `AuthBearerToken` | `bearer_token/2` | Equivalent |
| Client Credentials | `AuthClientCredentials` | `client_credentials/3` | Equivalent |
| Password Grant | `AuthClientPassword` | `client_password/3` | Equivalent |
| Background refresh | Daemon thread | TokenManager GenServer | Different design, equivalent |
| OIDC Discovery | Automatic | `OIDC.discover/1` | Equivalent |
| Weaviate Cloud header | `X-Weaviate-Cluster-URL` | Not implemented | **Gap** |

### 7.4 Missing: Weaviate Cloud Header

Python adds a special header for Weaviate Cloud:
```python
if is_weaviate_domain(host):
    self._headers["X-Weaviate-Cluster-URL"] = "https://" + host
```

**Recommendation**: Add to Elixir HTTP client.

---

## 8. Proxy Support

### 8.1 Python Proxy Configuration (`base.py`, lines 148-199)

```python
def _get_proxies(proxies: Union[dict, str, Proxies, None], trust_env: bool) -> Dict[str, str]:
    """Get proxies compatible with 'requests' library."""
    if proxies is not None:
        if isinstance(proxies, str):
            return {"http": proxies, "https": proxies, "grpc": proxies}
        if isinstance(proxies, dict):
            return proxies
        if isinstance(proxies, Proxies):
            return proxies.model_dump(exclude_none=True)

    if not trust_env:
        return {}

    # Read from environment variables
    http_proxy = os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy")
    https_proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
    grpc_proxy = os.environ.get("GRPC_PROXY") or os.environ.get("grpc_proxy")

    return {k: v for k, v in {...} if v}
```

### 8.2 Elixir Proxy Configuration (`lib/weaviate_ex/config/proxy.ex`)

```elixir
defmodule WeaviateEx.Config.Proxy do
  defstruct http: nil, https: nil, grpc: nil

  def from_env do
    %__MODULE__{
      http: get_env_case_insensitive("HTTP_PROXY"),
      https: get_env_case_insensitive("HTTPS_PROXY"),
      grpc: get_env_case_insensitive("GRPC_PROXY")
    }
  end

  def to_finch_opts(%__MODULE__{} = proxy) do
    proxy_url = proxy.https || proxy.http
    case parse_proxy_url(proxy_url) do
      {:ok, scheme, host, port} -> [proxy: {scheme, host, port, []}]
      :error -> []
    end
  end

  def to_grpc_opts(%__MODULE__{grpc: grpc_proxy}) do
    [http_proxy: grpc_proxy]
  end
end
```

### 8.3 Proxy Comparison

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| HTTP Proxy | Supported | Supported | Equivalent |
| HTTPS Proxy | Supported | Supported | Equivalent |
| gRPC Proxy | Supported | Supported | Equivalent |
| Environment Variables | `HTTP_PROXY`, etc. | Same variables | Equivalent |
| Case Sensitivity | Both cases checked | Both cases checked | Equivalent |
| String URL shorthand | `"http://proxy:8080"` | Not supported | Minor gap |
| Finch/httpx Integration | Full | Full | Equivalent |

**Conclusion**: Proxy support is comprehensive in Elixir.

---

## 9. Rate Limiting Headers

### 9.1 Python Integration Headers (`connect/integrations.py`)

```python
class _IntegrationConfigOpenAi(_IntegrationConfig):
    api_key: str = Field(serialization_alias="X-Openai-Api-Key")
    organization: Optional[str] = Field(serialization_alias="X-Openai-Organization")
    requests_per_minute_embeddings: Optional[int] = Field(
        serialization_alias="X-Openai-Ratelimit-RequestPM-Embedding"
    )
    tokens_per_minute_embeddings: Optional[int] = Field(
        serialization_alias="X-Openai-Ratelimit-TokenPM-Embedding"
    )
    base_url: Optional[str] = Field(serialization_alias="X-Openai-Baseurl")
```

### 9.2 Elixir Integration Headers (`lib/weaviate_ex/integrations.ex`)

```elixir
defmodule WeaviateEx.Integrations do
  def openai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    [{"X-OpenAI-Api-Key", api_key}]
    |> maybe_add("X-OpenAI-Organization", Keyword.get(opts, :organization))
  end
  # No rate limit headers
end
```

### 9.3 Rate Limit Gap

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| API Key Headers | All providers | All providers | Equivalent |
| Rate Limit Headers | Full support | **Not implemented** | **Gap** |
| Base URL Override | Supported | Not implemented | **Gap** |

**Missing in Elixir**:
- `X-OpenAI-Ratelimit-RequestPM-Embedding`
- `X-OpenAI-Ratelimit-TokenPM-Embedding`
- `X-Cohere-Ratelimit-RequestPM-Embedding`
- `X-*-Baseurl` for custom endpoints

---

## 10. Recommendations Summary

### High Priority (Production Critical)

1. **HTTP Transport Retry** (Critical)
   - Implement retry wrapper with exponential backoff for transport errors
   - Match Python's 3 retry default

2. **Per-Operation Timeouts** (High)
   - Use existing `Timeout` module in HTTP client
   - Apply different timeouts for queries vs inserts

3. **Connection State Tracking** (High)
   - Enforce connection checks before requests
   - Add `is_connected?/1` function

### Medium Priority (Feature Parity)

4. **Rate Limit Headers** (Medium)
   - Add `requests_per_minute` and `tokens_per_minute` options to integrations
   - Add `base_url` override for custom endpoints

5. **Weaviate Cloud Header** (Medium)
   - Detect Weaviate Cloud URLs
   - Add `X-Weaviate-Cluster-URL` header automatically

6. **Dynamic Token Refresh** (Medium)
   - Integrate TokenManager with HTTP client
   - Refresh tokens before they expire

### Low Priority (Nice to Have)

7. **Async HTTP Client** (Low)
   - Consider Task-based async API for parallel requests
   - Not critical for OTP apps (use Task.async_stream)

8. **String Proxy Shorthand** (Low)
   - Accept `"http://proxy:8080"` as proxy config
   - Auto-apply to http/https/grpc

---

## Appendix: File References

### Python Files Analyzed
- `weaviate-python-client/weaviate/connect/base.py` - Connection parameters
- `weaviate-python-client/weaviate/connect/v4.py` - HTTP client core
- `weaviate-python-client/weaviate/connect/authentication.py` - OIDC auth
- `weaviate-python-client/weaviate/connect/helpers.py` - Connection helpers
- `weaviate-python-client/weaviate/connect/integrations.py` - API integrations
- `weaviate-python-client/weaviate/connect/executor.py` - Sync/async executor
- `weaviate-python-client/weaviate/config.py` - Configuration classes
- `weaviate-python-client/weaviate/retry.py` - Retry logic
- `weaviate-python-client/weaviate/exceptions.py` - Exception hierarchy

### Elixir Files Analyzed
- `lib/weaviate_ex/protocol/http/client.ex` - HTTP client
- `lib/weaviate_ex/client/config.ex` - Client configuration
- `lib/weaviate_ex/client/pool.ex` - Connection pool config
- `lib/weaviate_ex/client/state.ex` - Client state tracking
- `lib/weaviate_ex/config/timeout.ex` - Timeout configuration
- `lib/weaviate_ex/config/proxy.ex` - Proxy configuration
- `lib/weaviate_ex/auth.ex` - Authentication
- `lib/weaviate_ex/auth/oidc.ex` - OIDC implementation
- `lib/weaviate_ex/auth/token_manager.ex` - Token lifecycle
- `lib/weaviate_ex/connect.ex` - Connection helpers
- `lib/weaviate_ex/integrations.ex` - API integrations
- `lib/weaviate_ex/error.ex` - Error handling
- `lib/weaviate_ex/grpc/retry.ex` - gRPC retry (HTTP missing)
