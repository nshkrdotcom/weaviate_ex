# Gap Analysis: Authentication and Connection Handling

## Python Client vs Elixir Port - Deep Dive Analysis

**Date:** 2024-12-29
**Scope:** Authentication methods, connection pooling, retry logic, timeouts, proxy support, HTTP/gRPC connections, connection state management, health checks, embedded Weaviate support, and custom headers

---

## Executive Summary

The Elixir port has achieved solid foundational parity with the Python client for authentication and connection handling, with some notable architectural differences that leverage Elixir/OTP strengths. However, several gaps exist in advanced features, particularly around OIDC flow automation, background token refresh, trust_env support, and some connection pool configuration options.

### Overall Parity Assessment

| Category | Parity Level | Notes |
|----------|-------------|-------|
| API Key Authentication | 95% | Full parity, minor header handling differences |
| OIDC Client Credentials | 75% | Core flow exists, missing auto-discovery integration |
| OIDC Password Flow | 70% | Implemented but less integrated |
| Bearer Token | 85% | Implemented, refresh mechanism differs |
| Connection Pooling | 80% | Finch-based pooling vs httpx transport mounts |
| Retry Logic | 90% | Both HTTP and gRPC retry with exponential backoff |
| Timeout Configuration | 90% | Similar structure, minor differences |
| Proxy Support | 85% | Full proxy config, env var support present |
| HTTP/gRPC Hybrid | 95% | Both support HTTP for schema, gRPC for data |
| Connection State | 80% | Different architectural approaches |
| Health Checks | 90% | HTTP and gRPC health checks implemented |
| Embedded Weaviate | 95% | Full binary management, startup/shutdown |
| Custom Headers | 90% | Additional headers with proper lowercasing |

---

## Feature Comparison Table

| Feature | Python Client | Elixir Port | Gap Status |
|---------|--------------|-------------|------------|
| **Authentication** |
| API Key (`Auth.api_key()`) | Yes | Yes | Complete |
| Bearer Token with expiry | Yes | Yes | Complete |
| Bearer Token refresh | Yes (background thread) | Yes (GenServer) | Different approach |
| OIDC Client Credentials | Yes | Yes | Complete |
| OIDC Password Flow | Yes | Yes | Complete |
| OIDC Auto-Discovery | Yes (automatic) | Partial (manual) | Gap |
| Background Token Refresh | Yes (daemon thread) | Yes (GenServer timer) | Different approach |
| Azure AD Special Handling | Yes | No | Gap |
| Negative Expiry Warning | Yes | No | Minor gap |
| **Connection** |
| HTTP Client | httpx | Finch | Different libraries |
| gRPC Client | grpc-python | grpc-elixir | Different libraries |
| Sync + Async Clients | Yes | N/A (OTP model) | Architectural difference |
| Connection Params | `ConnectionParams` | `Connect` module | Complete |
| Session Pool Size | `session_pool_maxsize` | `max_connections` | Complete |
| Session Pool Connections | `session_pool_connections` | `pool_size` | Complete |
| Session Pool Max Retries | `session_pool_max_retries` | Separate retry module | Complete |
| Session Pool Timeout | `session_pool_timeout` | `pool_timeout` | Complete |
| **Retry Logic** |
| HTTP Transport Retries | Yes | Yes | Complete |
| gRPC Retries | Yes (`_Retry` class) | Yes (`GRPC.Retry`) | Complete |
| Exponential Backoff | Yes (2^count) | Yes (2^attempt) | Complete |
| Max Retry Count | Default: 4 | Default: 4 (gRPC), 3 (HTTP) | Complete |
| Retryable Status Codes | UNAVAILABLE | 4, 8, 10, 14 | Complete |
| Jitter | No | Yes (+/- 10%) | Elixir enhancement |
| **Timeouts** |
| Query Timeout | Yes (default: 30s) | Yes (default: 30s) | Complete |
| Insert Timeout | Yes (default: 90s) | Yes (default: 90s) | Complete |
| Init Timeout | Yes (default: 2s) | Yes (default: 2s) | Complete |
| Per-Method Timeout | Yes | Yes | Complete |
| **Proxy** |
| HTTP Proxy | Yes | Yes | Complete |
| HTTPS Proxy | Yes | Yes | Complete |
| gRPC Proxy | Yes | Yes | Complete |
| Environment Variables | Yes (`HTTP_PROXY`, etc.) | Yes | Complete |
| `trust_env` Option | Yes | No | Gap |
| **Health Checks** |
| HTTP `/.well-known/live` | Yes | Yes | Complete |
| HTTP `/.well-known/ready` | Yes | Yes | Complete |
| gRPC Health Check | Yes (`_ping_grpc`) | Yes (`Health.check`) | Complete |
| Wait for Ready | Yes | Yes | Complete |
| **Embedded Weaviate** |
| Binary Download | Yes | Yes | Complete |
| Version Resolution | Yes (latest, specific) | Yes | Complete |
| Platform Detection | Yes (Darwin, Linux) | Yes | Complete |
| Port Management | Yes | Yes | Complete |
| Environment Variables | Yes | Yes | Complete |
| Process Management | Yes (subprocess) | Yes (Port) | Complete |
| **Custom Headers** |
| Additional Headers | Yes | Yes | Complete |
| Header Validation | Yes (no None values) | Yes (no nil values) | Complete |
| WCS Cluster Header | Yes (auto-detect) | Yes (auto-detect) | Complete |
| Header Lowercasing (gRPC) | Yes | Yes | Complete |

---

## Detailed Gap Analysis

### 1. Authentication Methods

#### 1.1 API Key Authentication

**Python Implementation** (`weaviate/auth.py`):
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

**Elixir Implementation** (`lib/weaviate_ex/auth.ex`):
```elixir
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

**Gap Assessment:** Complete parity. Both implementations provide a simple wrapper around the API key string and convert it to a Bearer token header.

---

#### 1.2 Bearer Token Authentication

**Python Implementation** (`weaviate/auth.py`):
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

**Elixir Implementation** (`lib/weaviate_ex/auth.ex`):
```elixir
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

**Gaps Identified:**
1. **Minor:** Python validates negative expiration times with a warning; Elixir does not
2. **Minor:** Python defaults `expires_in` to 60; Elixir defaults to `nil`

---

#### 1.3 OIDC Client Credentials Flow

**Python Implementation** (`weaviate/connect/authentication.py`):
```python
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

**Python Background Token Refresh** (`weaviate/connect/v4.py`):
```python
def _create_background_token_refresh(self, _auth: Optional[_Auth] = None) -> None:
    """Create a background thread that periodically refreshes access and refresh tokens."""
    # Uses daemon thread with periodic refresh
    demon = Thread(
        target=periodic_refresh_token,
        args=(expires_in, _auth),
        daemon=True,
        name="TokenRefresh",
    )
    demon.start()
```

**Elixir Implementation** (`lib/weaviate_ex/auth/token_manager.ex`):
```elixir
defmodule WeaviateEx.Auth.TokenManager do
  use GenServer

  def handle_info(:fetch_token, state) do
    case fetch_or_refresh_token(state) do
      {:ok, token} ->
        state = %{state | token: token}
        state = schedule_refresh(state)
        {:noreply, state}
      {:error, reason} ->
        Process.send_after(self(), :fetch_token, 5000)
        {:noreply, state}
    end
  end

  defp schedule_refresh(%{token: token, refresh_buffer_seconds: buffer} = state) do
    refresh_in = max(1, (token.expires_in - buffer) * 1000)
    timer_ref = Process.send_after(self(), :refresh_token, refresh_in)
    %{state | refresh_timer: timer_ref}
  end
end
```

**Gap Assessment:**
- **Architecture:** Python uses daemon threads; Elixir uses GenServer with process timers - this is an appropriate idiom difference
- **Minor Gap:** Python's Azure AD special scoping (`[client_id + "/.default"]`) is not implemented in Elixir
- **Gap:** Python's `_Auth.use()` automatically discovers OIDC configuration from Weaviate's `.well-known/openid-configuration` endpoint during connection; Elixir requires manual OIDC discovery

---

#### 1.4 OIDC Password Flow

**Python Implementation** (`weaviate/connect/authentication.py`):
```python
def _get_session_user_pw(self, config: AuthClientPassword) -> Result:
    session = OAuth2Client(
        client_id=self._client_id,
        token_endpoint=self._token_endpoint,
        grant_type="password",
        scope=scope,
        default_timeout=AUTH_DEFAULT_TIMEOUT,
    )
    token = session.fetch_token(username=config.username, password=config.password)
```

**Elixir Implementation** (`lib/weaviate_ex/auth.ex`):
```elixir
def client_password(username, password, opts \\ []) do
  %{
    type: :oidc_password,
    username: username,
    password: password,
    client_id: Keyword.get(opts, :client_id),
    client_secret: Keyword.get(opts, :client_secret),
    scopes: Keyword.get(opts, :scopes, [])
  }
end
```

**Gap Assessment:**
- Elixir has the data structure but integration with TokenManager matches Python's approach
- **Gap:** Python validates that Microsoft/Azure doesn't support password flow; Elixir does not

---

### 2. Connection Pooling

**Python Implementation** (`weaviate/config.py` and `weaviate/connect/v4.py`):
```python
@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20
    session_pool_maxsize: int = 100
    session_pool_max_retries: int = 3
    session_pool_timeout: int = 5

# In _ConnectionBase._make_mounts()
HTTPTransport(
    limits=Limits(
        max_connections=self.__connection_config.session_pool_maxsize,
        max_keepalive_connections=self.__connection_config.session_pool_connections,
    ),
    proxy=Proxy(url=proxy),
    retries=self.__connection_config.session_pool_max_retries,
    trust_env=self.__trust_env,
)
```

**Elixir Implementation** (`lib/weaviate_ex/config/connection.ex`):
```elixir
defmodule WeaviateEx.Config.Connection do
  @default_pool_size 10
  @default_max_connections 100
  @default_pool_timeout 5_000
  @default_max_idle_time 60_000

  defstruct pool_size: @default_pool_size,
            max_connections: @default_max_connections,
            pool_timeout: @default_pool_timeout,
            max_idle_time: @default_max_idle_time

  def to_finch_opts(%__MODULE__{} = config) do
    [
      size: config.pool_size,
      count: div(config.max_connections, config.pool_size),
      pool_timeout: config.pool_timeout
    ]
  end
end
```

**Gap Assessment:**
- Both provide similar configuration options
- **Minor Gap:** Python's `session_pool_max_retries` is integrated into transport; Elixir uses separate retry module
- **Gap:** Python's `trust_env` option for reading proxy from environment is not directly exposed in Elixir connection config

---

### 3. Retry Logic and Exponential Backoff

**Python Implementation** (`weaviate/retry.py`):
```python
class _Retry:
    def __init__(self, n: float = 4) -> None:
        self.n = n

    def with_exponential_backoff(self, count, error, f, *args, **kwargs):
        try:
            return f(*args, **kwargs)
        except RpcError as e:
            if err.code() != StatusCode.UNAVAILABLE:
                raise e
            time.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return self.with_exponential_backoff(count + 1, error, f, *args, **kwargs)
```

**Elixir Implementation** (`lib/weaviate_ex/retry.ex`):
```elixir
defmodule WeaviateEx.Retry do
  @default_max_retries 3
  @default_base_delay 100
  @default_max_delay 5_000
  @retryable_statuses [429, 502, 503, 504]
  @retryable_grpc_codes [4, 8, 10, 14]  # DEADLINE_EXCEEDED, RESOURCE_EXHAUSTED, ABORTED, UNAVAILABLE

  def with_exponential_backoff(fun, opts \\ []) do
    do_retry(fun, 0, max_retries, base_delay, max_delay)
  end

  def calculate_delay(attempt, base_delay, max_delay) do
    delay = (base_delay * :math.pow(2, attempt)) |> trunc()
    delay = min(delay, max_delay)
    # Add jitter (+/- 10%)
    jitter = delay * 0.1
    jitter_amount = :rand.uniform() * jitter * 2 - jitter
    trunc(delay + jitter_amount)
  end
end
```

**Gap Assessment:**
- **Complete:** Both implement exponential backoff with similar formulas
- **Enhancement in Elixir:** Elixir adds jitter to prevent thundering herd
- **Elixir Enhancement:** Elixir supports more retryable status codes (429, 502, 503, 504 for HTTP; 4, 8, 10, 14 for gRPC)
- Python only retries on `UNAVAILABLE`; Elixir is more comprehensive

---

### 4. Timeout Configuration

**Python Implementation** (`weaviate/config.py`):
```python
class Timeout(BaseModel):
    query: Union[int, float] = Field(default=30, ge=0)
    insert: Union[int, float] = Field(default=90, ge=0)
    init: Union[int, float] = Field(default=2, ge=0)
```

**Elixir Implementation** (`lib/weaviate_ex/config/timeout.ex`):
```elixir
defmodule WeaviateEx.Config.Timeout do
  @default_init 2_000      # 2 seconds in ms
  @default_query 30_000    # 30 seconds in ms
  @default_insert 90_000   # 90 seconds in ms

  defstruct init: @default_init,
            query: @default_query,
            insert: @default_insert

  def for_method(%__MODULE__{query: query}, :get), do: query
  def for_method(%__MODULE__{insert: insert}, :post), do: insert
  # ...
end
```

**Gap Assessment:** Complete parity. Both provide three timeout categories with identical defaults. Elixir uses milliseconds consistently; Python uses seconds.

---

### 5. Proxy Support

**Python Implementation** (`weaviate/connect/base.py`):
```python
def _get_proxies(proxies: Union[dict, str, Proxies, None], trust_env: bool) -> Dict[str, str]:
    if proxies is not None:
        if isinstance(proxies, str):
            return {"http": proxies, "https": proxies, "grpc": proxies}
        # ...
    if not trust_env:
        return {}
    # Read from HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY environment variables
```

**Elixir Implementation** (`lib/weaviate_ex/config/proxy.ex`):
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

**Gap Assessment:**
- Both support HTTP, HTTPS, and gRPC proxies
- Both read from environment variables (case-insensitive)
- **Gap:** Python's `trust_env` option to control environment reading is not exposed in Elixir; Elixir always allows env reading via `from_env/0`

---

### 6. HTTP vs gRPC Connections

**Python Implementation** (`weaviate/connect/v4.py`):
```python
class _ConnectionBase:
    def __init__(self, ...):
        self._client: Optional[HttpClient] = None
        self._grpc_stub: Optional[weaviate_pb2_grpc.WeaviateStub] = None
        self._grpc_channel: Union[AsyncChannel, SyncChannel, None] = None

    def open_connection_grpc(self, colour: executor.Colour) -> None:
        channel = self._connection_params._grpc_channel(
            proxies=self._proxies,
            grpc_msg_size=self._grpc_max_msg_size,
            is_async=colour == "async",
        )
        self._grpc_channel = channel
        self._grpc_stub = weaviate_pb2_grpc.WeaviateStub(self._grpc_channel)
```

**Elixir Implementation** (`lib/weaviate_ex/client.ex` and `lib/weaviate_ex/grpc/channel.ex`):
```elixir
defmodule WeaviateEx.Client do
  defstruct [:config, :grpc_channel, :protocol_impl, :state]

  def connect(opts \\ []) do
    config = Config.new(opts)
    grpc_result = if skip_grpc do
      {:ok, nil}
    else
      Channel.connect(grpc_config, timeout: timeout)
    end
    # ...
  end
end

defmodule WeaviateEx.GRPC.Channel do
  def connect(config, opts \\ []) do
    case GRPC.Stub.connect(host, channel_opts) do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} -> {:error, connection_error(reason)}
    end
  end
end
```

**Gap Assessment:**
- Both use HTTP for schema operations, gRPC for data operations
- Both support skipping gRPC connection
- **Difference:** Python has sync/async variants; Elixir uses OTP concurrency model
- Complete functional parity

---

### 7. Connection State Management

**Python Implementation** (`weaviate/connect/v4.py`):
```python
class _ConnectionBase:
    def __init__(self, ...):
        self._connected = False
        self._weaviate_version = _ServerVersion.from_string("")

    def is_connected(self) -> bool:
        return self._connected

    def close(self, colour: executor.Colour) -> executor.Result[None]:
        if self._client is not None:
            self._client.close()
            self._client = None
        if self._grpc_stub is not None:
            self._grpc_channel.close()
            self._grpc_stub = None
        self._connected = False
```

**Elixir Implementation** (`lib/weaviate_ex/client/state.ex`):
```elixir
defmodule WeaviateEx.Client.State do
  @type status :: :initializing | :connected | :disconnected | :closed

  defstruct status: :initializing,
            created_at: nil,
            last_used_at: nil,
            request_count: 0,
            error_count: 0,
            last_error: nil

  def connected(state), do: %{state | status: :connected}
  def disconnected(state, reason), do: %{state | status: :disconnected, last_error: reason}
  def closed(state), do: %{state | status: :closed}
  def record_request(state), do: %{state | request_count: state.request_count + 1, ...}
  def record_error(state, error), do: %{state | error_count: state.error_count + 1, ...}
end
```

**Gap Assessment:**
- **Enhancement in Elixir:** Elixir tracks additional state (request counts, error counts, timestamps)
- Both track connected/disconnected state
- Different architectural approaches: Python uses instance variables, Elixir uses immutable state struct

---

### 8. Health Checks

**Python Implementation** (`weaviate/connect/v4.py` and `weaviate/client_executor.py`):
```python
def _ping_grpc(self, colour: executor.Colour):
    """Performs a grpc health check and raises WeaviateGRPCUnavailableError if not."""
    res = self._grpc_channel.unary_unary(
        "/grpc.health.v1.Health/Check",
        request_serializer=...,
        response_deserializer=...,
    )(WeaviateHealthCheckRequest(), timeout=self.timeout_config.init)

def is_live(self) -> executor.Result[bool]:
    return self._connection.get(path="/.well-known/live")

def is_ready(self) -> executor.Result[bool]:
    return self._connection.get(path="/.well-known/ready")

def wait_for_weaviate(self, startup_period: int) -> None:
    for _i in range(startup_period):
        try:
            self.get("/.well-known/ready").raise_for_status()
            return
        except (ConnectError, ...):
            time.sleep(1)
```

**Elixir Implementation** (`lib/weaviate_ex/health.ex` and `lib/weaviate_ex/grpc/services/health.ex`):
```elixir
defmodule WeaviateEx.Health do
  def alive?(client) do
    case WeaviateEx.Client.request(client, :get, "/.well-known/live", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  def ready?(client) do
    case WeaviateEx.Client.request(client, :get, "/.well-known/ready", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  def wait_until_ready(opts \\ []) do
    # Polls until ready or timeout
  end
end

defmodule WeaviateEx.GRPC.Services.Health do
  def ping(channel, opts \\ []) do
    case check(channel, opts) do
      {:ok, :serving} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def check(channel, opts \\ []) do
    case WeaviateHealthStub.check(channel, request, call_opts) do
      {:ok, %{status: :SERVING}} -> {:ok, :serving}
      # ...
    end
  end

  def wait_for_ready(channel, opts \\ []) do
    # Polls until ready or timeout
  end
end
```

**Gap Assessment:** Complete parity. Both implement:
- HTTP liveness probe (`/.well-known/live`)
- HTTP readiness probe (`/.well-known/ready`)
- gRPC health check
- Wait-for-ready functionality

---

### 9. Embedded Weaviate Support

**Python Implementation** (`weaviate/embedded.py`):
```python
@dataclass
class EmbeddedOptions:
    persistence_data_path: str = DEFAULT_PERSISTENCE_DATA_PATH
    binary_path: str = DEFAULT_BINARY_PATH
    version: str = WEAVIATE_VERSION  # "1.30.5"
    port: int = DEFAULT_PORT  # 8079
    hostname: str = "127.0.0.1"
    additional_env_vars: Optional[Dict[str, str]] = None
    grpc_port: int = DEFAULT_GRPC_PORT  # 50060

class EmbeddedV4(_EmbeddedBase):
    def start(self) -> None:
        self.ensure_weaviate_binary_exists()
        my_env = os.environ.copy()
        my_env.setdefault("AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED", "true")
        # ... many env vars
        process = subprocess.Popen([...], env=my_env)
        self.wait_till_listening()
```

**Elixir Implementation** (`lib/weaviate_ex/embedded.ex`):
```elixir
defmodule WeaviateEx.Embedded do
  @default_version "1.30.5"

  def start(opts \\ []) do
    with {:ok, options} <- build_options(opts),
         :ok <- ensure_supported_platform(),
         {:ok, executable, parsed_version} <- ensure_binary(options),
         env <- build_environment(options, parsed_version),
         {:ok, process_port} <- spawn_instance(executable, env, options),
         :ok <- wait_until_ready(host, port, grpc_port, timeout) do
      {:ok, %Instance{...}}
    end
  end

  defp spawn_instance(executable, env, options) do
    port = Port.open({:spawn_executable, executable}, [
      :binary, :exit_status, {:env, env_list}, {:args, args}
    ])
    {:ok, port}
  end
end
```

**Gap Assessment:**
- Both download binaries from GitHub releases
- Both support version resolution (latest, specific version, URL)
- Both handle platform detection (Darwin/Linux)
- Both set comprehensive environment variables
- **Difference:** Python uses `subprocess.Popen`; Elixir uses Erlang `Port`
- Complete functional parity

---

### 10. Custom Headers

**Python Implementation** (`weaviate/connect/v4.py`):
```python
class _ConnectionBase:
    def __init__(self, ..., additional_headers: Optional[Dict[str, Any]] = None, ...):
        self._headers = {"content-type": "application/json"}
        if additional_headers is not None:
            for key, value in additional_headers.items():
                if value is None:
                    raise WeaviateInvalidInputError(f"Value for key '{key}' cannot be None.")
                self._headers[key.lower()] = value

    def _prepare_grpc_headers(self) -> None:
        self.__metadata_list: List[Tuple[str, str]] = []
        for key, val in self.additional_headers.items():
            if val is not None:
                self.__metadata_list.append((key.lower(), val))
```

**Elixir Implementation** (`lib/weaviate_ex/client/config.ex` and `lib/weaviate_ex/grpc/channel.ex`):
```elixir
defmodule WeaviateEx.Client.Config do
  defp validate_additional_headers!(headers) when is_map(headers) do
    Enum.each(headers, fn
      {key, nil} -> raise ArgumentError, "Header values cannot be nil..."
      {_key, value} when is_binary(value) -> :ok
      {key, value} -> raise ArgumentError, "Header values must be strings..."
    end)
  end
end

defmodule WeaviateEx.GRPC.Channel do
  def build_metadata(config) when is_map(config) do
    additional_metadata =
      config
      |> Map.get(:additional_headers, %{})
      |> lowercase_header_keys()
    # ...
  end

  defp lowercase_header_keys(headers) do
    Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), value} end)
  end
end
```

**Gap Assessment:**
- Both validate that header values are not nil
- Both lowercase header keys for gRPC metadata
- Complete parity

---

## Code Examples Showing Differences

### Authentication Flow Comparison

**Python - Automatic OIDC Discovery:**
```python
# Python automatically discovers OIDC config during connection
client = weaviate.connect_to_weaviate_cloud(
    cluster_url="my-cluster.weaviate.network",
    auth_credentials=Auth.client_credentials(client_secret="secret")
)
# Internally calls /.well-known/openid-configuration
# Sets up background token refresh automatically
```

**Elixir - Manual OIDC Setup:**
```elixir
# Elixir requires more explicit OIDC setup
# First, discover OIDC config
{:ok, oidc_config} = WeaviateEx.Auth.OIDC.discover("https://auth.example.com")

# Start TokenManager with discovered config
{:ok, token_manager} = WeaviateEx.Auth.TokenManager.start_link(
  oidc_config: oidc_config,
  auth: WeaviateEx.Auth.client_credentials("client-id", "client-secret")
)

# Create client with token manager
{:ok, client} = WeaviateEx.Client.connect(
  base_url: "https://my-cluster.weaviate.network",
  token_manager: token_manager
)
```

### Retry Configuration Comparison

**Python:**
```python
# Retry is built into connection with fixed max_retries
_Retry(4).with_exponential_backoff(0, "Searching", stub.Search, request)
# Delay: 2^count seconds (1, 2, 4, 8, 16 seconds)
```

**Elixir:**
```elixir
# Retry is more configurable
WeaviateEx.Retry.with_exponential_backoff(fn ->
  WeaviateEx.Client.request(client, :post, "/v1/objects", object)
end, max_retries: 5, base_delay: 200, max_delay: 10_000)
# Delay: base_delay * 2^attempt with +/- 10% jitter
```

### Connection Pool Configuration Comparison

**Python:**
```python
config = AdditionalConfig(
    connection=ConnectionConfig(
        session_pool_connections=20,
        session_pool_maxsize=100,
        session_pool_max_retries=3,
        session_pool_timeout=5
    ),
    proxies={"http": "http://proxy:8080"},
    trust_env=True  # Read proxies from environment
)
```

**Elixir:**
```elixir
connection = WeaviateEx.Config.Connection.new(
  pool_size: 20,
  max_connections: 100,
  pool_timeout: 5_000,
  max_idle_time: 60_000
)

proxy = WeaviateEx.Config.Proxy.from_env()  # Always reads from env
# or
proxy = WeaviateEx.Config.Proxy.new(http: "http://proxy:8080")
```

---

## Priority Recommendations

### Critical Priority (P0) - Required for Production Parity

1. **Automatic OIDC Discovery During Connection**
   - Python automatically calls `.well-known/openid-configuration` during `connect()`
   - Elixir should integrate OIDC discovery into `Client.connect/1` when auth requires it
   - Effort: Medium

### High Priority (P1) - Important for Feature Completeness

2. **Azure AD Special Handling**
   - Add Microsoft Azure AD scope detection (`[client_id + "/.default"]`)
   - Add validation preventing password flow with Azure
   - Effort: Low

3. **`trust_env` Option for Proxy Configuration**
   - Python allows disabling environment variable proxy reading
   - Elixir should support this in `AdditionalConfig` or similar
   - Effort: Low

4. **Integrated Token Refresh with Client**
   - Python's background token refresh is tightly integrated with connection
   - Elixir's TokenManager is separate; should be auto-started when needed
   - Effort: Medium

### Medium Priority (P2) - Nice to Have

5. **Negative Expiration Warning**
   - Add warning when bearer token expires_in is negative
   - Effort: Trivial

6. **Server Version Tracking**
   - Python tracks `_weaviate_version` from meta endpoint
   - Elixir could track server version in client state
   - Effort: Low

7. **gRPC Max Message Size from Server**
   - Python reads `grpcMaxMessageSize` from meta endpoint
   - Elixir could dynamically configure based on server response
   - Effort: Low

### Low Priority (P3) - Edge Cases

8. **OIDC Grant Type Validation**
   - Python validates `grant_types_supported` from OIDC config
   - Effort: Low

9. **Package Version Check**
   - Python checks PyPI for client version updates
   - Could add Hex version check (optional)
   - Effort: Medium

---

## Architecture Comparison Summary

| Aspect | Python Approach | Elixir Approach |
|--------|-----------------|-----------------|
| Concurrency Model | Threads (daemon for token refresh) | OTP (GenServer, supervised processes) |
| HTTP Client | httpx (async/sync) | Finch (connection pooling) |
| gRPC Client | grpcio | grpc-elixir |
| State Management | Instance variables | Immutable structs |
| Configuration | Pydantic models | Structs with validation |
| Connection Pool | httpx Transport mounts | Finch pools |
| Token Refresh | Background daemon thread | GenServer timer |
| Embedded Process | subprocess.Popen | Erlang Port |

The Elixir port successfully adapts Python patterns to OTP idioms while maintaining functional parity for core authentication and connection features. The remaining gaps are primarily around convenience features and edge-case handling rather than fundamental functionality.
