# Authentication and Connection Management Gap Analysis

## Executive Summary

This document provides a comprehensive analysis of the gaps between the Python Weaviate client and the Elixir WeaviateEx client in the areas of authentication and connection management.

### Critical Findings

The Elixir client has **significant gaps** in authentication and connection management compared to the Python client:

| Category | Python Features | Elixir Implementation | Gap Severity |
|----------|-----------------|----------------------|--------------|
| Connection Types | 5 factory methods | 1 basic pattern | **Critical** |
| Authentication | 4 auth methods | 1 (API key only) | **Critical** |
| OIDC Support | Full OAuth2 flows | None | **Critical** |
| Timeout Config | 3 granular timeouts | 1 basic timeout | **High** |
| Connection Pooling | Full configuration | Basic Finch defaults | **High** |
| gRPC Support | Native gRPC | None | **Critical** |
| Proxy Support | HTTP/HTTPS/gRPC | None | **High** |
| Retry Mechanism | Exponential backoff | None | **High** |
| Async Client | Full async/await | Basic (Elixir native) | **Medium** |
| Embedded Mode | Full parity | Good parity | **Low** |

---

## 1. Connection Types

### 1.1 Python Connection Factory Methods

The Python client provides 5 distinct connection factory methods for different deployment scenarios:

#### connect_to_weaviate_cloud (Weaviate Cloud Services)

```python
import weaviate
from weaviate.classes.init import Auth

client = weaviate.connect_to_weaviate_cloud(
    cluster_url="rAnD0mD1g1t5.something.weaviate.cloud",
    auth_credentials=Auth.api_key("my-api-key"),
    headers={"X-OpenAI-Api-Key": "sk-..."},  # Optional vectorizer headers
    additional_config=wvc.init.AdditionalConfig(
        timeout=wvc.init.Timeout(init=30, query=60, insert=120)
    ),
    skip_init_checks=False
)
```

**Key Features:**
- Automatic gRPC host derivation from cluster URL
- HTTPS/TLS enabled by default (port 443)
- Automatic handling of `.weaviate.network` vs other domains
- Support for API key, bearer token, client credentials, or password auth

#### connect_to_local

```python
client = weaviate.connect_to_local(
    host="localhost",
    port=8080,
    grpc_port=50051,
    headers={"X-OpenAI-Api-Key": "sk-..."},
    additional_config=None,
    skip_init_checks=False,
    auth_credentials=None  # Optional for local auth
)
```

#### connect_to_embedded

```python
client = weaviate.connect_to_embedded(
    hostname="127.0.0.1",
    port=8079,
    grpc_port=50050,
    headers=None,
    additional_config=None,
    version="1.30.5",
    persistence_data_path="/custom/path",
    binary_path="/custom/cache",
    environment_variables={"ENABLE_MODULES": "text2vec-openai"}
)
```

#### connect_to_custom

```python
client = weaviate.connect_to_custom(
    http_host="weaviate.example.com",
    http_port=443,
    http_secure=True,
    grpc_host="grpc.weaviate.example.com",
    grpc_port=443,
    grpc_secure=True,
    headers={"Authorization": "Bearer custom-token"},
    additional_config=None,
    auth_credentials=Auth.api_key("my-key"),
    skip_init_checks=False
)
```

#### Async Variants

Each sync method has an async counterpart:
- `use_async_with_weaviate_cloud`
- `use_async_with_local`
- `use_async_with_embedded`
- `use_async_with_custom`

### 1.2 Elixir Current Implementation

The Elixir client has a single basic connection pattern:

```elixir
# Current implementation in lib/weaviate_ex.ex
def base_url do
  System.get_env("WEAVIATE_URL") ||
    Application.get_env(:weaviate_ex, :url) ||
    "http://localhost:8080"
end

def api_key do
  System.get_env("WEAVIATE_API_KEY") ||
    Application.get_env(:weaviate_ex, :api_key)
end
```

### 1.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Connect do
  @moduledoc """
  Connection factory functions for different Weaviate deployment scenarios.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Auth
  alias WeaviateEx.Config.{ConnectionParams, AdditionalConfig}

  @doc """
  Connect to a Weaviate Cloud (WCD) instance.

  ## Examples

      {:ok, client} = WeaviateEx.Connect.to_weaviate_cloud(
        cluster_url: "rAnD0mD1g1t5.something.weaviate.cloud",
        auth: WeaviateEx.Auth.api_key("my-api-key"),
        headers: %{"X-OpenAI-Api-Key" => "sk-..."}
      )
  """
  @spec to_weaviate_cloud(keyword()) :: {:ok, Client.t()} | {:error, term()}
  def to_weaviate_cloud(opts) do
    cluster_url = Keyword.fetch!(opts, :cluster_url)
    auth = Keyword.fetch!(opts, :auth)
    headers = Keyword.get(opts, :headers, %{})
    config = Keyword.get(opts, :additional_config, %AdditionalConfig{})
    skip_init_checks = Keyword.get(opts, :skip_init_checks, false)

    {http_host, grpc_host} = parse_weaviate_cloud_url(cluster_url)

    connection_params = %ConnectionParams{
      http: %{host: http_host, port: 443, secure: true},
      grpc: %{host: grpc_host, port: 443, secure: true}
    }

    Client.new(
      connection_params: connection_params,
      auth: auth,
      headers: headers,
      config: config,
      skip_init_checks: skip_init_checks
    )
  end

  @doc """
  Connect to a local Weaviate instance (Docker/Kubernetes).

  ## Examples

      {:ok, client} = WeaviateEx.Connect.to_local(
        host: "localhost",
        port: 8080,
        grpc_port: 50051
      )
  """
  @spec to_local(keyword()) :: {:ok, Client.t()} | {:error, term()}
  def to_local(opts \\ []) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 8080)
    grpc_port = Keyword.get(opts, :grpc_port, 50051)
    headers = Keyword.get(opts, :headers, %{})
    auth = Keyword.get(opts, :auth)
    config = Keyword.get(opts, :additional_config, %AdditionalConfig{})
    skip_init_checks = Keyword.get(opts, :skip_init_checks, false)

    connection_params = %ConnectionParams{
      http: %{host: host, port: port, secure: false},
      grpc: %{host: host, port: grpc_port, secure: false}
    }

    Client.new(
      connection_params: connection_params,
      auth: auth,
      headers: headers,
      config: config,
      skip_init_checks: skip_init_checks
    )
  end

  @doc """
  Connect to an embedded Weaviate instance.

  ## Examples

      {:ok, client} = WeaviateEx.Connect.to_embedded(
        version: "1.30.5",
        port: 8079,
        grpc_port: 50050
      )
  """
  @spec to_embedded(keyword()) :: {:ok, Client.t()} | {:error, term()}
  def to_embedded(opts \\ []) do
    alias WeaviateEx.Embedded

    hostname = Keyword.get(opts, :hostname, "127.0.0.1")
    port = Keyword.get(opts, :port, 8079)
    grpc_port = Keyword.get(opts, :grpc_port, 50050)
    version = Keyword.get(opts, :version, "1.30.5")
    headers = Keyword.get(opts, :headers, %{})
    config = Keyword.get(opts, :additional_config, %AdditionalConfig{})
    persistence_data_path = Keyword.get(opts, :persistence_data_path)
    binary_path = Keyword.get(opts, :binary_path)
    environment_variables = Keyword.get(opts, :environment_variables, %{})

    embedded_opts = [
      hostname: hostname,
      port: port,
      grpc_port: grpc_port,
      version: version,
      persistence_data_path: persistence_data_path,
      binary_path: binary_path,
      environment_variables: environment_variables
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    with {:ok, instance} <- Embedded.start(embedded_opts) do
      connection_params = %ConnectionParams{
        http: %{host: hostname, port: port, secure: false},
        grpc: %{host: hostname, port: grpc_port, secure: false}
      }

      case Client.new(
        connection_params: connection_params,
        headers: headers,
        config: config,
        embedded_instance: instance
      ) do
        {:ok, client} -> {:ok, client}
        {:error, reason} ->
          Embedded.stop(instance)
          {:error, reason}
      end
    end
  end

  @doc """
  Connect to a Weaviate instance with custom connection parameters.

  ## Examples

      {:ok, client} = WeaviateEx.Connect.to_custom(
        http_host: "weaviate.example.com",
        http_port: 443,
        http_secure: true,
        grpc_host: "grpc.weaviate.example.com",
        grpc_port: 443,
        grpc_secure: true,
        auth: WeaviateEx.Auth.api_key("my-key")
      )
  """
  @spec to_custom(keyword()) :: {:ok, Client.t()} | {:error, term()}
  def to_custom(opts) do
    http_host = Keyword.fetch!(opts, :http_host)
    http_port = Keyword.fetch!(opts, :http_port)
    http_secure = Keyword.fetch!(opts, :http_secure)
    grpc_host = Keyword.fetch!(opts, :grpc_host)
    grpc_port = Keyword.fetch!(opts, :grpc_port)
    grpc_secure = Keyword.fetch!(opts, :grpc_secure)
    headers = Keyword.get(opts, :headers, %{})
    auth = Keyword.get(opts, :auth)
    config = Keyword.get(opts, :additional_config, %AdditionalConfig{})
    skip_init_checks = Keyword.get(opts, :skip_init_checks, false)

    connection_params = %ConnectionParams{
      http: %{host: http_host, port: http_port, secure: http_secure},
      grpc: %{host: grpc_host, port: grpc_port, secure: grpc_secure}
    }

    Client.new(
      connection_params: connection_params,
      auth: auth,
      headers: headers,
      config: config,
      skip_init_checks: skip_init_checks
    )
  end

  # Private helpers

  defp parse_weaviate_cloud_url(cluster_url) do
    # Remove http(s):// prefix if present
    host = cluster_url
    |> String.replace(~r/^https?:\/\//, "")
    |> String.trim_trailing("/")

    grpc_host = if String.ends_with?(host, ".weaviate.network") do
      [ident | domain_parts] = String.split(host, ".", parts: 2)
      "#{ident}.grpc.#{Enum.join(domain_parts, ".")}"
    else
      "grpc-#{host}"
    end

    {host, grpc_host}
  end
end
```

**Priority: Critical**

---

## 2. Authentication Methods

### 2.1 Python Authentication Classes

The Python client supports 4 authentication methods:

#### API Key Authentication

```python
from weaviate.classes.init import Auth

# Simple API key
auth = Auth.api_key("my-api-key")

# Usage
client = weaviate.connect_to_weaviate_cloud(
    cluster_url="...",
    auth_credentials=auth
)
```

**Implementation (weaviate/auth.py):**

```python
@dataclass
class _APIKey:
    """Using the given API key to authenticate with weaviate."""
    api_key: str
```

#### Bearer Token Authentication

```python
auth = Auth.bearer_token(
    access_token="eyJhbGciOiJS...",
    expires_in=3600,  # seconds
    refresh_token="dGhpcyBpcyBh..."  # Optional
)
```

**Implementation:**

```python
@dataclass
class _BearerToken:
    access_token: str
    expires_in: int = 60
    refresh_token: Optional[str] = None
```

#### Client Credentials (OIDC)

```python
auth = Auth.client_credentials(
    client_secret="my-client-secret",
    scope=["openid", "offline_access"]  # Optional
)
```

**Implementation:**

```python
@dataclass
class _ClientCredentials:
    client_secret: str
    scope: Optional[SCOPES] = None
```

#### Resource Owner Password (OIDC)

```python
auth = Auth.client_password(
    username="user@example.com",
    password="secret123",
    scope=["openid", "offline_access"]
)
```

**Implementation:**

```python
@dataclass
class _ClientPassword:
    username: str
    password: str
    scope: Optional[SCOPES] = None
```

### 2.2 Python OIDC Flow Implementation

The Python client implements full OIDC support with automatic token refresh:

```python
# From weaviate/connect/authentication.py

class _Auth:
    def __init__(
        self,
        oidc_config: OIDC_CONFIG,
        credentials: AuthCredentials,
        make_mounts: MountsMaker,
        colour: executor.Colour,
    ) -> None:
        self._credentials = credentials
        self._open_id_config_url = oidc_config["href"]
        self._client_id = oidc_config["clientId"]
        self._default_scopes = oidc_config.get("scopes", [])
        self._token_endpoint = None

    def get_auth_session(self) -> OAuth2Client:
        if isinstance(self._credentials, AuthBearerToken):
            return self._get_session_auth_bearer_token(self._credentials)
        elif isinstance(self._credentials, AuthClientCredentials):
            return self._get_session_client_credential(self._credentials)
        else:
            return self._get_session_user_pw(self._credentials)

    def _create_background_token_refresh(self, _auth: Optional[_Auth] = None) -> None:
        """Background thread that periodically refreshes tokens."""
        # Daemon thread that refreshes tokens before expiration
        demon = Thread(
            target=periodic_refresh_token,
            args=(expires_in, _auth),
            daemon=True,
            name="TokenRefresh",
        )
        demon.start()
```

### 2.3 Elixir Current Implementation

The Elixir client only supports API key authentication via environment variable or config:

```elixir
# Current: Only API key support
def api_key do
  System.get_env("WEAVIATE_API_KEY") ||
    Application.get_env(:weaviate_ex, :api_key)
end

# In protocol/http/client.ex
defp build_headers(config, body) do
  headers = [{"content-type", "application/json"}]
  if config.api_key do
    [{"authorization", "Bearer #{config.api_key}"} | headers]
  else
    headers
  end
end
```

### 2.4 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Auth do
  @moduledoc """
  Authentication credentials for connecting to Weaviate.

  Supports:
  - API Key authentication
  - Bearer token authentication with optional refresh
  - OIDC Client Credentials flow
  - OIDC Resource Owner Password flow
  """

  @type scope :: String.t() | [String.t()]

  @type t ::
          api_key()
          | bearer_token()
          | client_credentials()
          | client_password()

  @type api_key :: %{type: :api_key, api_key: String.t()}
  @type bearer_token :: %{
          type: :bearer_token,
          access_token: String.t(),
          expires_in: non_neg_integer(),
          refresh_token: String.t() | nil
        }
  @type client_credentials :: %{
          type: :client_credentials,
          client_secret: String.t(),
          scope: [String.t()]
        }
  @type client_password :: %{
          type: :client_password,
          username: String.t(),
          password: String.t(),
          scope: [String.t()]
        }

  @doc """
  Create API key credentials.

  ## Examples

      auth = WeaviateEx.Auth.api_key("my-api-key")
  """
  @spec api_key(String.t()) :: api_key()
  def api_key(key) when is_binary(key) do
    %{type: :api_key, api_key: key}
  end

  @doc """
  Create bearer token credentials.

  ## Options

    * `:expires_in` - Token expiration in seconds (default: 60)
    * `:refresh_token` - Optional refresh token for automatic renewal

  ## Examples

      auth = WeaviateEx.Auth.bearer_token("eyJhbGci...",
        expires_in: 3600,
        refresh_token: "dGhpcyBpcyBh..."
      )
  """
  @spec bearer_token(String.t(), keyword()) :: bearer_token()
  def bearer_token(access_token, opts \\ []) when is_binary(access_token) do
    expires_in = Keyword.get(opts, :expires_in, 60)
    refresh_token = Keyword.get(opts, :refresh_token)

    if expires_in < 0 do
      require Logger
      Logger.warning("[WeaviateEx.Auth] Negative expiration time: #{expires_in}")
    end

    %{
      type: :bearer_token,
      access_token: access_token,
      expires_in: expires_in,
      refresh_token: refresh_token
    }
  end

  @doc """
  Create OIDC client credentials.

  Used for server-to-server authentication with client ID and secret.

  ## Options

    * `:scope` - OAuth2 scopes (string or list of strings)

  ## Examples

      auth = WeaviateEx.Auth.client_credentials("my-client-secret",
        scope: ["openid", "offline_access"]
      )
  """
  @spec client_credentials(String.t(), keyword()) :: client_credentials()
  def client_credentials(client_secret, opts \\ []) when is_binary(client_secret) do
    scope = parse_scope(Keyword.get(opts, :scope))

    %{
      type: :client_credentials,
      client_secret: client_secret,
      scope: scope
    }
  end

  @doc """
  Create OIDC resource owner password credentials.

  Used for authentication with username and password.

  ## Options

    * `:scope` - OAuth2 scopes (string or list of strings)
              For some providers, include "offline_access" to get refresh tokens.

  ## Examples

      auth = WeaviateEx.Auth.client_password("user@example.com", "secret123",
        scope: "openid offline_access"
      )
  """
  @spec client_password(String.t(), String.t(), keyword()) :: client_password()
  def client_password(username, password, opts \\ [])
      when is_binary(username) and is_binary(password) do
    scope = parse_scope(Keyword.get(opts, :scope))

    %{
      type: :client_password,
      username: username,
      password: password,
      scope: scope
    }
  end

  # Private helpers

  defp parse_scope(nil), do: []
  defp parse_scope(scope) when is_binary(scope), do: String.split(scope, " ")
  defp parse_scope(scope) when is_list(scope), do: scope
end
```

#### OIDC Authentication Manager

```elixir
defmodule WeaviateEx.Auth.OIDC do
  @moduledoc """
  OIDC authentication flow implementation with automatic token refresh.
  """

  use GenServer
  require Logger

  @auth_timeout 5_000
  @refresh_buffer_seconds 30

  defstruct [
    :credentials,
    :oidc_config,
    :client_id,
    :token_endpoint,
    :default_scopes,
    :current_token,
    :token_expires_at,
    :refresh_timer
  ]

  # Client API

  @doc """
  Start the OIDC authentication manager.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize OIDC authentication by fetching configuration and obtaining tokens.
  """
  @spec init_auth(map(), map()) :: {:ok, pid()} | {:error, term()}
  def init_auth(credentials, oidc_config) do
    GenServer.call(__MODULE__, {:init_auth, credentials, oidc_config}, @auth_timeout)
  end

  @doc """
  Get the current access token.
  """
  @spec get_access_token() :: {:ok, String.t()} | {:error, term()}
  def get_access_token do
    GenServer.call(__MODULE__, :get_access_token)
  end

  @doc """
  Get the current bearer token header value.
  """
  @spec get_bearer_token() :: String.t()
  def get_bearer_token do
    case get_access_token() do
      {:ok, token} -> "Bearer #{token}"
      _ -> ""
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:init_auth, credentials, oidc_config}, _from, state) do
    with {:ok, token_endpoint} <- fetch_token_endpoint(oidc_config["href"]),
         {:ok, session} <- create_auth_session(credentials, token_endpoint, oidc_config) do
      new_state = %{state |
        credentials: credentials,
        oidc_config: oidc_config,
        client_id: oidc_config["clientId"],
        token_endpoint: token_endpoint,
        default_scopes: oidc_config["scopes"] || [],
        current_token: session.access_token,
        token_expires_at: calculate_expiry(session.expires_in)
      }

      # Schedule token refresh
      new_state = schedule_token_refresh(new_state, session.expires_in)

      {:reply, {:ok, self()}, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_access_token, _from, %{current_token: token} = state)
      when not is_nil(token) do
    {:reply, {:ok, token}, state}
  end

  def handle_call(:get_access_token, _from, state) do
    {:reply, {:error, :no_token}, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    case refresh_token(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning("[WeaviateEx.Auth.OIDC] Token refresh failed: #{inspect(reason)}")
        # Retry in 1 second
        new_state = schedule_token_refresh(state, 1)
        {:noreply, new_state}
    end
  end

  # Private functions

  defp fetch_token_endpoint(config_url) do
    case Req.get(config_url, receive_timeout: @auth_timeout) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["token_endpoint"]}

      {:ok, %{status: status}} ->
        {:error, {:oidc_config_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_auth_session(%{type: :bearer_token} = creds, _token_endpoint, _oidc_config) do
    {:ok, %{
      access_token: creds.access_token,
      expires_in: creds.expires_in,
      refresh_token: creds.refresh_token
    }}
  end

  defp create_auth_session(%{type: :client_credentials} = creds, token_endpoint, oidc_config) do
    scope = merge_scopes(oidc_config["scopes"] || [], creds.scope)

    body = %{
      grant_type: "client_credentials",
      client_id: oidc_config["clientId"],
      client_secret: creds.client_secret,
      scope: Enum.join(scope, " ")
    }

    case Req.post(token_endpoint, form: body, receive_timeout: @auth_timeout) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, %{
          access_token: response["access_token"],
          expires_in: response["expires_in"] || 60,
          refresh_token: response["refresh_token"]
        }}

      {:ok, %{status: status, body: body}} ->
        {:error, {:token_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_auth_session(%{type: :client_password} = creds, token_endpoint, oidc_config) do
    scope = merge_scopes(oidc_config["scopes"] || [], creds.scope)

    body = %{
      grant_type: "password",
      client_id: oidc_config["clientId"],
      username: creds.username,
      password: creds.password,
      scope: Enum.join(scope, " ")
    }

    case Req.post(token_endpoint, form: body, receive_timeout: @auth_timeout) do
      {:ok, %{status: 200, body: response}} ->
        if is_nil(response["refresh_token"]) do
          Logger.warning(
            "[WeaviateEx.Auth.OIDC] No refresh token received. " <>
            "Token will expire in #{response["expires_in"]}s. " <>
            "Consider adding 'offline_access' scope."
          )
        end

        {:ok, %{
          access_token: response["access_token"],
          expires_in: response["expires_in"] || 60,
          refresh_token: response["refresh_token"]
        }}

      {:ok, %{status: status, body: body}} ->
        {:error, {:token_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp refresh_token(%{credentials: %{type: :client_credentials}} = state) do
    # Client credentials: fetch new token with same credentials
    case create_auth_session(state.credentials, state.token_endpoint, state.oidc_config) do
      {:ok, session} ->
        new_state = %{state |
          current_token: session.access_token,
          token_expires_at: calculate_expiry(session.expires_in)
        }
        {:ok, schedule_token_refresh(new_state, session.expires_in)}

      error ->
        error
    end
  end

  defp refresh_token(%{current_token: _, refresh_token: nil} = state) do
    # No refresh token, cannot refresh
    {:error, :no_refresh_token}
  end

  defp refresh_token(state) do
    body = %{
      grant_type: "refresh_token",
      client_id: state.client_id,
      refresh_token: state.current_token.refresh_token
    }

    case Req.post(state.token_endpoint, form: body, receive_timeout: @auth_timeout) do
      {:ok, %{status: 200, body: response}} ->
        new_state = %{state |
          current_token: response["access_token"],
          token_expires_at: calculate_expiry(response["expires_in"] || 60)
        }
        {:ok, schedule_token_refresh(new_state, response["expires_in"] || 60)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:refresh_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_token_refresh(state, expires_in) do
    # Cancel existing timer
    if state.refresh_timer, do: Process.cancel_timer(state.refresh_timer)

    # Schedule refresh before expiration
    refresh_in = max((expires_in - @refresh_buffer_seconds) * 1000, 1000)
    timer = Process.send_after(self(), :refresh_token, refresh_in)

    %{state | refresh_timer: timer}
  end

  defp calculate_expiry(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end

  defp merge_scopes(defaults, additional) do
    (defaults ++ additional) |> Enum.uniq()
  end
end
```

**Priority: Critical**

---

## 3. Timeout Configuration

### 3.1 Python Timeout Implementation

Python provides granular timeout configuration:

```python
# From weaviate/config.py

class Timeout(BaseModel):
    """Timeouts for the different operations in the client."""
    query: Union[int, float] = Field(default=30, ge=0)   # For GET, HEAD, GraphQL queries
    insert: Union[int, float] = Field(default=90, ge=0)  # For POST, PUT, PATCH, DELETE
    init: Union[int, float] = Field(default=2, ge=0)     # For initialization checks
```

Usage:

```python
from weaviate.classes.init import AdditionalConfig, Timeout

config = AdditionalConfig(
    timeout=Timeout(
        init=5,     # 5 seconds for init checks
        query=60,   # 60 seconds for queries
        insert=120  # 120 seconds for inserts
    )
)

client = weaviate.connect_to_local(additional_config=config)
```

### 3.2 Elixir Current Implementation

Single timeout value in config:

```elixir
# In lib/weaviate_ex/client/config.ex
defstruct [
  :base_url,
  :grpc_host,
  :grpc_port,
  :api_key,
  timeout: 60_000,  # Single timeout for all operations
  protocol: :http
]
```

### 3.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Config.Timeout do
  @moduledoc """
  Timeout configuration for different operation types.

  - `init` - Timeout for initialization checks (default: 2s)
  - `query` - Timeout for query operations (GET, HEAD, GraphQL) (default: 30s)
  - `insert` - Timeout for write operations (POST, PUT, PATCH, DELETE) (default: 90s)
  """

  @type t :: %__MODULE__{
          init: non_neg_integer(),
          query: non_neg_integer(),
          insert: non_neg_integer()
        }

  @enforce_keys []
  defstruct init: 2_000,
            query: 30_000,
            insert: 90_000

  @doc """
  Create a new timeout configuration.

  ## Examples

      timeout = WeaviateEx.Config.Timeout.new(
        init: 5_000,
        query: 60_000,
        insert: 120_000
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      init: Keyword.get(opts, :init, 2_000),
      query: Keyword.get(opts, :query, 30_000),
      insert: Keyword.get(opts, :insert, 90_000)
    }
  end

  @doc """
  Get the appropriate timeout for an HTTP method.
  """
  @spec for_method(t(), atom(), boolean()) :: non_neg_integer()
  def for_method(%__MODULE__{} = timeout, method, is_gql_query \\ false) do
    case method do
      :get -> timeout.query
      :head -> timeout.query
      :post when is_gql_query -> timeout.query
      :post -> timeout.insert
      :put -> timeout.insert
      :patch -> timeout.insert
      :delete -> timeout.insert
      _ -> timeout.query
    end
  end
end
```

**Priority: High**

---

## 4. Connection Pooling

### 4.1 Python Connection Pool Configuration

```python
# From weaviate/config.py

@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20      # Max keepalive connections
    session_pool_maxsize: int = 100         # Max total connections
    session_pool_max_retries: int = 3       # HTTP retries
    session_pool_timeout: int = 5           # Pool acquisition timeout
```

Usage in connection:

```python
# From weaviate/connect/v4.py

def _make_mounts(self, colour: executor.Colour):
    return {
        f"{key}://": HTTPTransport(
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

### 4.2 Elixir Current Implementation

Uses Finch with default configuration:

```elixir
# In lib/weaviate_ex/application.ex
children = [
  {Finch, name: WeaviateEx.Finch}
]
```

### 4.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Config.Connection do
  @moduledoc """
  Connection pool configuration for HTTP and gRPC connections.
  """

  @type t :: %__MODULE__{
          pool_size: pos_integer(),
          pool_max_idle_time: non_neg_integer(),
          pool_count: pos_integer(),
          max_retries: non_neg_integer(),
          pool_timeout: non_neg_integer()
        }

  defstruct pool_size: 50,
            pool_max_idle_time: 30_000,
            pool_count: 1,
            max_retries: 3,
            pool_timeout: 5_000

  @doc """
  Create connection configuration.

  ## Options

    * `:pool_size` - Size of each connection pool (default: 50)
    * `:pool_max_idle_time` - Max idle time for connections in ms (default: 30000)
    * `:pool_count` - Number of connection pools (default: 1)
    * `:max_retries` - Number of retry attempts (default: 3)
    * `:pool_timeout` - Timeout for acquiring a connection in ms (default: 5000)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      pool_size: Keyword.get(opts, :pool_size, 50),
      pool_max_idle_time: Keyword.get(opts, :pool_max_idle_time, 30_000),
      pool_count: Keyword.get(opts, :pool_count, 1),
      max_retries: Keyword.get(opts, :max_retries, 3),
      pool_timeout: Keyword.get(opts, :pool_timeout, 5_000)
    }
  end

  @doc """
  Convert to Finch pool configuration.
  """
  @spec to_finch_pools(t(), String.t()) :: keyword()
  def to_finch_pools(%__MODULE__{} = config, base_url) do
    uri = URI.parse(base_url)
    scheme = if uri.scheme == "https", do: :https, else: :http
    port = uri.port || if(scheme == :https, do: 443, else: 80)

    [
      default: [
        size: config.pool_size,
        count: config.pool_count,
        max_idle_time: config.pool_max_idle_time
      ],
      {scheme, uri.host, port} => [
        size: config.pool_size,
        count: config.pool_count,
        max_idle_time: config.pool_max_idle_time,
        protocol: :http1  # Use HTTP/1.1 for REST
      ]
    ]
  end
end

# Updated application.ex
defmodule WeaviateEx.Application do
  use Application

  def start(_type, _args) do
    connection_config = Application.get_env(:weaviate_ex, :connection, %{})
    config = WeaviateEx.Config.Connection.new(connection_config)
    base_url = WeaviateEx.base_url()

    children = [
      {Finch,
       name: WeaviateEx.Finch,
       pools: WeaviateEx.Config.Connection.to_finch_pools(config, base_url)}
    ]

    opts = [strategy: :one_for_one, name: WeaviateEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Priority: High**

---

## 5. Retry Mechanism

### 5.1 Python Retry Implementation

```python
# From weaviate/retry.py

class _Retry:
    def __init__(self, n: float = 4) -> None:
        self.n = n  # Max retries

    def with_exponential_backoff(
        self,
        count: int,
        error: str,
        f: Callable[P, T],
        *args: P.args,
        **kwargs: P.kwargs,
    ) -> T:
        try:
            return f(*args, **kwargs)
        except RpcError as e:
            if err.code() != StatusCode.UNAVAILABLE:
                raise e
            logger.info(
                f"{error} received exception: {e}. "
                f"Retrying with exponential backoff in {2**count} seconds"
            )
            time.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return self.with_exponential_backoff(count + 1, error, f, *args, **kwargs)
```

### 5.2 Elixir Current Implementation

No retry mechanism implemented.

### 5.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Retry do
  @moduledoc """
  Retry mechanism with exponential backoff for transient failures.
  """

  require Logger

  @default_max_retries 4
  @retryable_errors [:timeout, :econnrefused, :closed, :unavailable]

  @type retry_opts :: [
          max_retries: non_neg_integer(),
          base_delay: non_neg_integer(),
          max_delay: non_neg_integer(),
          retryable_errors: [atom()]
        ]

  @doc """
  Execute a function with exponential backoff retry.

  ## Options

    * `:max_retries` - Maximum number of retry attempts (default: 4)
    * `:base_delay` - Base delay in milliseconds for backoff calculation (default: 1000)
    * `:max_delay` - Maximum delay in milliseconds (default: 30000)
    * `:retryable_errors` - List of error types to retry (default: timeout, connection errors)

  ## Examples

      WeaviateEx.Retry.with_exponential_backoff(fn ->
        WeaviateEx.request(:get, "/v1/meta", nil)
      end, max_retries: 3)
  """
  @spec with_exponential_backoff(
          (-> {:ok, term()} | {:error, term()}),
          retry_opts()
        ) :: {:ok, term()} | {:error, term()}
  def with_exponential_backoff(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay, 1_000)
    max_delay = Keyword.get(opts, :max_delay, 30_000)
    retryable_errors = Keyword.get(opts, :retryable_errors, @retryable_errors)
    context = Keyword.get(opts, :context, "operation")

    do_retry(fun, 0, max_retries, base_delay, max_delay, retryable_errors, context)
  end

  defp do_retry(fun, attempt, max_retries, base_delay, max_delay, retryable_errors, context) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %WeaviateEx.Error{type: error_type} = error} ->
        if attempt < max_retries and error_type in retryable_errors do
          delay = calculate_delay(attempt, base_delay, max_delay)

          Logger.info(
            "[WeaviateEx.Retry] #{context} failed with #{error_type}. " <>
            "Retrying in #{delay}ms (attempt #{attempt + 1}/#{max_retries})"
          )

          Process.sleep(delay)
          do_retry(fun, attempt + 1, max_retries, base_delay, max_delay, retryable_errors, context)
        else
          if attempt >= max_retries do
            {:error, %WeaviateEx.Error{
              type: :retry_exhausted,
              message: "Max retries (#{max_retries}) exceeded for #{context}",
              details: %{last_error: error, attempts: attempt + 1}
            }}
          else
            {:error, error}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_delay(attempt, base_delay, max_delay) do
    # Exponential backoff: base_delay * 2^attempt with jitter
    delay = base_delay * :math.pow(2, attempt)
    jitter = :rand.uniform(round(delay * 0.1))
    min(round(delay + jitter), max_delay)
  end
end
```

**Priority: High**

---

## 6. Proxy Support

### 6.1 Python Proxy Implementation

```python
# From weaviate/config.py

class Proxies(BaseModel):
    """Proxy configurations for sending requests to Weaviate through a proxy."""
    http: Optional[str] = Field(default=None)
    https: Optional[str] = Field(default=None)
    grpc: Optional[str] = Field(default=None)

# From weaviate/connect/base.py

def _get_proxies(proxies: Union[dict, str, Proxies, None], trust_env: bool) -> Dict[str, str]:
    """Get proxies, compatible with 'requests' library."""
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

    proxies = {}
    if http_proxy: proxies["http"] = http_proxy
    if https_proxy: proxies["https"] = https_proxy
    if grpc_proxy: proxies["grpc"] = grpc_proxy

    return proxies
```

### 6.2 Elixir Current Implementation

No proxy support.

### 6.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Config.Proxies do
  @moduledoc """
  Proxy configuration for HTTP and gRPC connections.
  """

  @type t :: %__MODULE__{
          http: String.t() | nil,
          https: String.t() | nil,
          grpc: String.t() | nil
        }

  defstruct http: nil,
            https: nil,
            grpc: nil

  @doc """
  Create proxy configuration.

  Can accept:
  - A single URL string (applied to all protocols)
  - A keyword list with :http, :https, :grpc keys
  - A Proxies struct

  ## Examples

      # Single proxy for all
      proxies = WeaviateEx.Config.Proxies.new("http://proxy.example.com:8080")

      # Different proxies per protocol
      proxies = WeaviateEx.Config.Proxies.new(
        http: "http://proxy.example.com:8080",
        https: "http://proxy.example.com:8080",
        grpc: "http://grpc-proxy.example.com:8080"
      )
  """
  @spec new(String.t() | keyword() | t()) :: t()
  def new(proxy) when is_binary(proxy) do
    %__MODULE__{http: proxy, https: proxy, grpc: proxy}
  end

  def new(opts) when is_list(opts) do
    %__MODULE__{
      http: Keyword.get(opts, :http),
      https: Keyword.get(opts, :https),
      grpc: Keyword.get(opts, :grpc)
    }
  end

  def new(%__MODULE__{} = proxies), do: proxies

  def new(nil), do: %__MODULE__{}

  @doc """
  Load proxy configuration from environment variables.

  Checks for HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY (case-insensitive).
  """
  @spec from_env() :: t()
  def from_env do
    %__MODULE__{
      http: get_env_proxy(["HTTP_PROXY", "http_proxy"]),
      https: get_env_proxy(["HTTPS_PROXY", "https_proxy"]),
      grpc: get_env_proxy(["GRPC_PROXY", "grpc_proxy"])
    }
  end

  @doc """
  Check if any proxy is configured.
  """
  @spec any_configured?(t()) :: boolean()
  def any_configured?(%__MODULE__{http: nil, https: nil, grpc: nil}), do: false
  def any_configured?(_), do: true

  @doc """
  Convert to Finch-compatible proxy configuration.
  """
  @spec to_finch_conn_opts(t(), atom()) :: keyword()
  def to_finch_conn_opts(%__MODULE__{} = proxies, scheme) do
    proxy_url = case scheme do
      :https -> proxies.https || proxies.http
      :http -> proxies.http
      _ -> nil
    end

    if proxy_url do
      uri = URI.parse(proxy_url)
      [proxy: {scheme_to_atom(uri.scheme), uri.host, uri.port || 80}]
    else
      []
    end
  end

  defp get_env_proxy(names) do
    Enum.find_value(names, fn name -> System.get_env(name) end)
  end

  defp scheme_to_atom("https"), do: :https
  defp scheme_to_atom(_), do: :http
end
```

**Priority: High**

---

## 7. gRPC Support

### 7.1 Python gRPC Implementation

The Python client has extensive gRPC support for high-performance operations:

```python
# From weaviate/connect/base.py

MAX_GRPC_MESSAGE_LENGTH = 104858000  # 10mb

class ConnectionParams(BaseModel):
    http: ProtocolParams
    grpc: ProtocolParams

    def _grpc_channel(
        self, proxies: Dict[str, str], grpc_msg_size: Optional[int], is_async: bool
    ) -> Union[AsyncChannel, SyncChannel]:
        opts = [
            ("grpc.max_send_message_length", grpc_msg_size),
            ("grpc.max_receive_message_length", grpc_msg_size),
            ("grpc.default_authority", self.grpc.host),
        ]

        if (p := proxies.get("grpc")) is not None:
            options = [*opts, ("grpc.http_proxy", p)]
        else:
            options = opts

        if is_async:
            mod = grpc.aio
        else:
            mod = grpc

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

gRPC operations include:
- `grpc_search` - Vector search operations
- `grpc_batch_objects` - Batch insertions
- `grpc_batch_stream` - Streaming batch insertions
- `grpc_batch_delete` - Batch deletions
- `grpc_tenants_get` - Tenant retrieval
- `grpc_aggregate` - Aggregation queries

### 7.2 Elixir Current Implementation

No gRPC support - HTTP only.

### 7.3 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Protocol.GRPC do
  @moduledoc """
  gRPC protocol implementation for high-performance Weaviate operations.

  Uses protobuf definitions from Weaviate's protocol buffers.
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.Proto.Weaviate  # Generated from .proto files

  @max_message_length 104_858_000  # 10MB

  defmodule Channel do
    @moduledoc "Manages gRPC channel lifecycle."

    use GenServer

    defstruct [:channel, :stub, :host, :port, :secure, :options]

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def get_stub(pid) do
      GenServer.call(pid, :get_stub)
    end

    @impl true
    def init(opts) do
      host = Keyword.fetch!(opts, :host)
      port = Keyword.fetch!(opts, :port)
      secure = Keyword.get(opts, :secure, false)
      proxy = Keyword.get(opts, :proxy)

      channel_opts = [
        max_send_message_length: @max_message_length,
        max_receive_message_length: @max_message_length
      ]

      channel_opts = if proxy do
        Keyword.put(channel_opts, :http_proxy, proxy)
      else
        channel_opts
      end

      # Note: Requires grpc-elixir library
      {:ok, channel} = if secure do
        GRPC.Stub.connect("#{host}:#{port}", [cred: GRPC.Credential.default()] ++ channel_opts)
      else
        GRPC.Stub.connect("#{host}:#{port}", channel_opts)
      end

      {:ok, %__MODULE__{
        channel: channel,
        host: host,
        port: port,
        secure: secure,
        options: channel_opts
      }}
    end

    @impl true
    def handle_call(:get_stub, _from, state) do
      {:reply, {:ok, state.channel}, state}
    end

    @impl true
    def terminate(_reason, %{channel: channel}) do
      if channel, do: GRPC.Stub.disconnect(channel)
      :ok
    end
  end

  # Protocol implementation

  @impl true
  def request(%Client{} = client, :grpc_search, _path, request, opts) do
    with {:ok, channel} <- get_channel(client) do
      timeout = Keyword.get(opts, :timeout, 30_000)
      metadata = build_metadata(client)

      case Weaviate.Stub.search(channel, request, metadata: metadata, timeout: timeout) do
        {:ok, response} -> {:ok, response}
        {:error, %GRPC.RPCError{status: status, message: message}} ->
          {:error, Error.from_grpc_error(status, message)}
      end
    end
  end

  @impl true
  def request(%Client{} = client, :grpc_batch_objects, _path, request, opts) do
    with {:ok, channel} <- get_channel(client) do
      timeout = Keyword.get(opts, :timeout, 90_000)
      max_retries = Keyword.get(opts, :max_retries, 3)
      metadata = build_metadata(client)

      WeaviateEx.Retry.with_exponential_backoff(fn ->
        case Weaviate.Stub.batch_objects(channel, request, metadata: metadata, timeout: timeout) do
          {:ok, response} ->
            errors = for err <- response.errors, into: %{} do
              {err.index, err.error}
            end
            {:ok, errors}

          {:error, %GRPC.RPCError{status: 14}} ->  # UNAVAILABLE
            {:error, %Error{type: :unavailable, message: "gRPC unavailable"}}

          {:error, %GRPC.RPCError{status: status, message: message}} ->
            {:error, Error.from_grpc_error(status, message)}
        end
      end, max_retries: max_retries, context: "batch objects")
    end
  end

  @impl true
  def request(%Client{} = client, :grpc_aggregate, _path, request, opts) do
    with {:ok, channel} <- get_channel(client) do
      timeout = Keyword.get(opts, :timeout, 30_000)
      metadata = build_metadata(client)

      case Weaviate.Stub.aggregate(channel, request, metadata: metadata, timeout: timeout) do
        {:ok, response} -> {:ok, response}
        {:error, %GRPC.RPCError{status: status, message: message}} ->
          {:error, Error.from_grpc_error(status, message)}
      end
    end
  end

  # Fallback to HTTP for non-gRPC operations
  @impl true
  def request(client, method, path, body, opts) do
    WeaviateEx.Protocol.HTTP.Client.request(client, method, path, body, opts)
  end

  # Private helpers

  defp get_channel(%Client{config: config}) do
    # Channel management would be handled by a supervisor
    case Registry.lookup(WeaviateEx.GRPCChannels, config.grpc_host) do
      [{pid, _}] -> Channel.get_stub(pid)
      [] -> {:error, :no_grpc_channel}
    end
  end

  defp build_metadata(%Client{config: config} = client) do
    headers = [{"content-type", "application/grpc"}]

    headers = if config.api_key do
      [{"authorization", "Bearer #{config.api_key}"} | headers]
    else
      headers
    end

    # Add custom headers
    headers ++ Map.to_list(client.additional_headers || %{})
  end
end
```

**Priority: Critical**

---

## 8. Custom Headers / Integrations

### 8.1 Python Integrations

```python
# From weaviate/connect/integrations.py

class Integrations:
    @staticmethod
    def cohere(*, api_key: str, base_url: Optional[str] = None,
               requests_per_minute_embeddings: Optional[int] = None):
        return _IntegrationConfigCohere(...)

    @staticmethod
    def openai(*, api_key: str, organization: Optional[str] = None,
               requests_per_minute_embeddings: Optional[int] = None,
               tokens_per_minute_embeddings: Optional[int] = None,
               base_url: Optional[str] = None):
        return _IntegrationConfigOpenAi(...)

    @staticmethod
    def huggingface(*, api_key: str, ...): ...
    @staticmethod
    def voyageai(*, api_key: str, ...): ...
    @staticmethod
    def jinaai(*, api_key: str, ...): ...
    @staticmethod
    def mistral(*, api_key: str, ...): ...
```

Headers generated:

```python
# Example headers for OpenAI integration
{
    "X-Openai-Api-Key": "sk-...",
    "X-Openai-Organization": "org-...",
    "X-Openai-Ratelimit-RequestPM-Embedding": "1000",
    "X-Openai-Ratelimit-TokenPM-Embedding": "100000",
    "X-Openai-Baseurl": "https://api.openai.com"
}
```

### 8.2 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Integrations do
  @moduledoc """
  Integration configurations for third-party vectorization services.
  """

  @type integration_config :: %{String.t() => String.t()}

  @doc """
  Configure OpenAI integration.

  ## Options

    * `:api_key` - Required. OpenAI API key
    * `:organization` - Optional. OpenAI organization ID
    * `:requests_per_minute_embeddings` - Optional. Rate limit
    * `:tokens_per_minute_embeddings` - Optional. Token rate limit
    * `:base_url` - Optional. Custom API base URL

  ## Examples

      headers = WeaviateEx.Integrations.openai(
        api_key: "sk-...",
        organization: "org-...",
        requests_per_minute_embeddings: 1000
      )
  """
  @spec openai(keyword()) :: integration_config()
  def openai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Openai-Api-Key" => api_key
    }
    |> maybe_put("X-Openai-Organization", opts[:organization])
    |> maybe_put("X-Openai-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Openai-Ratelimit-TokenPM-Embedding", opts[:tokens_per_minute_embeddings])
    |> maybe_put("X-Openai-Baseurl", opts[:base_url])
  end

  @doc "Configure Cohere integration."
  @spec cohere(keyword()) :: integration_config()
  def cohere(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Cohere-Api-Key" => api_key
    }
    |> maybe_put("X-Cohere-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Cohere-Baseurl", opts[:base_url])
  end

  @doc "Configure HuggingFace integration."
  @spec huggingface(keyword()) :: integration_config()
  def huggingface(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Huggingface-Api-Key" => api_key
    }
    |> maybe_put("X-Huggingface-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Huggingface-Baseurl", opts[:base_url])
  end

  @doc "Configure VoyageAI integration."
  @spec voyageai(keyword()) :: integration_config()
  def voyageai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Voyageai-Api-Key" => api_key
    }
    |> maybe_put("X-Voyageai-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Voyageai-Ratelimit-TokenPM-Embedding", opts[:tokens_per_minute_embeddings])
    |> maybe_put("X-Voyageai-Baseurl", opts[:base_url])
  end

  @doc "Configure JinaAI integration."
  @spec jinaai(keyword()) :: integration_config()
  def jinaai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Jinaai-Api-Key" => api_key
    }
    |> maybe_put("X-Jinaai-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Jinaai-Baseurl", opts[:base_url])
  end

  @doc "Configure Mistral integration."
  @spec mistral(keyword()) :: integration_config()
  def mistral(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    %{
      "X-Mistral-Api-Key" => api_key
    }
    |> maybe_put("X-Mistral-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute_embeddings])
    |> maybe_put("X-Mistral-Ratelimit-TokenPM-Embedding", opts[:tokens_per_minute_embeddings])
  end

  @doc """
  Merge multiple integration configurations.

  ## Examples

      headers = WeaviateEx.Integrations.merge([
        WeaviateEx.Integrations.openai(api_key: "sk-..."),
        WeaviateEx.Integrations.cohere(api_key: "co-...")
      ])
  """
  @spec merge([integration_config()]) :: integration_config()
  def merge(configs) when is_list(configs) do
    Enum.reduce(configs, %{}, &Map.merge(&2, &1))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, to_string(value))
end
```

**Priority: Medium**

---

## 9. Additional Configuration

### 9.1 Python AdditionalConfig

```python
# From weaviate/config.py

class AdditionalConfig(BaseModel):
    connection: ConnectionConfig = Field(default_factory=ConnectionConfig)
    proxies: Union[str, Proxies, None] = Field(default=None)
    timeout_: Union[Tuple[int, int], Timeout] = Field(default_factory=Timeout, alias="timeout")
    trust_env: bool = Field(default=False)
```

### 9.2 Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Config.AdditionalConfig do
  @moduledoc """
  Additional configuration options for Weaviate client.
  """

  alias WeaviateEx.Config.{Connection, Proxies, Timeout}

  @type t :: %__MODULE__{
          connection: Connection.t(),
          proxies: Proxies.t() | nil,
          timeout: Timeout.t(),
          trust_env: boolean(),
          skip_init_checks: boolean()
        }

  defstruct connection: %Connection{},
            proxies: nil,
            timeout: %Timeout{},
            trust_env: false,
            skip_init_checks: false

  @doc """
  Create additional configuration.

  ## Options

    * `:connection` - Connection pool configuration
    * `:proxies` - Proxy configuration (string, keyword list, or Proxies struct)
    * `:timeout` - Timeout configuration
    * `:trust_env` - Whether to read proxy settings from environment (default: false)
    * `:skip_init_checks` - Skip initialization checks (default: false)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      connection: opts |> Keyword.get(:connection, []) |> Connection.new(),
      proxies: opts |> Keyword.get(:proxies) |> parse_proxies(Keyword.get(opts, :trust_env, false)),
      timeout: opts |> Keyword.get(:timeout, []) |> Timeout.new(),
      trust_env: Keyword.get(opts, :trust_env, false),
      skip_init_checks: Keyword.get(opts, :skip_init_checks, false)
    }
  end

  defp parse_proxies(nil, true), do: Proxies.from_env()
  defp parse_proxies(nil, false), do: nil
  defp parse_proxies(proxies, _), do: Proxies.new(proxies)
end
```

**Priority: Medium**

---

## 10. Complete Configuration Comparison Table

| Feature | Python | Elixir Current | Elixir Proposed | Priority |
|---------|--------|----------------|-----------------|----------|
| **Connection Types** |||||
| connect_to_weaviate_cloud | Yes | No | `Connect.to_weaviate_cloud/1` | Critical |
| connect_to_local | Yes | Partial | `Connect.to_local/1` | Critical |
| connect_to_embedded | Yes | Yes | `Connect.to_embedded/1` | Low |
| connect_to_custom | Yes | No | `Connect.to_custom/1` | Critical |
| Async variants | Yes | N/A (Elixir native) | N/A | N/A |
| **Authentication** |||||
| API Key | Yes | Yes | `Auth.api_key/1` | Done |
| Bearer Token | Yes | No | `Auth.bearer_token/2` | Critical |
| Client Credentials (OIDC) | Yes | No | `Auth.client_credentials/2` | Critical |
| Resource Owner Password | Yes | No | `Auth.client_password/3` | Critical |
| Automatic token refresh | Yes | No | `Auth.OIDC` GenServer | Critical |
| **Timeouts** |||||
| Query timeout | Yes (30s) | No | `Timeout.query` | High |
| Insert timeout | Yes (90s) | No | `Timeout.insert` | High |
| Init timeout | Yes (2s) | No | `Timeout.init` | High |
| Method-specific | Yes | No | `Timeout.for_method/3` | High |
| **Connection Pool** |||||
| Max connections | Yes (100) | Finch default | `Connection.pool_size` | High |
| Keep-alive connections | Yes (20) | Finch default | Configurable | High |
| Max retries | Yes (3) | No | `Connection.max_retries` | High |
| Pool timeout | Yes (5s) | Finch default | `Connection.pool_timeout` | High |
| **Retry** |||||
| Exponential backoff | Yes | No | `Retry.with_exponential_backoff/2` | High |
| gRPC retries | Yes | N/A | gRPC module | High |
| **Proxy** |||||
| HTTP proxy | Yes | No | `Proxies.http` | High |
| HTTPS proxy | Yes | No | `Proxies.https` | High |
| gRPC proxy | Yes | No | `Proxies.grpc` | High |
| Environment reading | Yes | No | `Proxies.from_env/0` | High |
| **gRPC** |||||
| gRPC channel | Yes | No | `Protocol.GRPC` | Critical |
| gRPC search | Yes | No | `grpc_search` | Critical |
| gRPC batch | Yes | No | `grpc_batch_objects` | Critical |
| gRPC stream | Yes | No | `grpc_batch_stream` | Medium |
| **Integrations** |||||
| OpenAI headers | Yes | Partial | `Integrations.openai/1` | Medium |
| Cohere headers | Yes | No | `Integrations.cohere/1` | Medium |
| HuggingFace headers | Yes | No | `Integrations.huggingface/1` | Medium |
| VoyageAI headers | Yes | No | `Integrations.voyageai/1` | Medium |
| JinaAI headers | Yes | No | `Integrations.jinaai/1` | Medium |
| Mistral headers | Yes | No | `Integrations.mistral/1` | Medium |
| **Health/Init** |||||
| is_ready | Yes | Yes | Done | Done |
| is_live | Yes | Yes | Done | Done |
| wait_for_weaviate | Yes | Yes | `Health.wait_until_ready/1` | Done |
| Skip init checks | Yes | No | `skip_init_checks` option | Medium |
| Version check | Yes | No | Add package version check | Low |
| **Embedded** |||||
| Binary download | Yes | Yes | Done | Done |
| Version support | Yes | Yes | Done | Done |
| Custom paths | Yes | Yes | Done | Done |
| Environment vars | Yes | Yes | Done | Done |
| Platform detection | Yes | Yes | Done | Done |

---

## 11. Implementation Roadmap

### Phase 1: Critical (Week 1-2)

1. **Connection Factory Methods**
   - Implement `WeaviateEx.Connect` module
   - Add all 4 connection factory functions
   - Update documentation

2. **Authentication System**
   - Implement `WeaviateEx.Auth` module
   - Add bearer token support
   - Implement OIDC client credentials
   - Implement OIDC password flow
   - Create `Auth.OIDC` GenServer for token refresh

3. **gRPC Support**
   - Generate Elixir modules from Weaviate protobuf files
   - Implement `WeaviateEx.Protocol.GRPC`
   - Add gRPC channel management

### Phase 2: High Priority (Week 3-4)

4. **Timeout Configuration**
   - Implement `WeaviateEx.Config.Timeout`
   - Update HTTP client to use method-specific timeouts
   - Add to connection options

5. **Connection Pooling**
   - Implement `WeaviateEx.Config.Connection`
   - Configure Finch pools dynamically
   - Add pool monitoring

6. **Retry Mechanism**
   - Implement `WeaviateEx.Retry`
   - Add exponential backoff
   - Integrate with HTTP and gRPC clients

7. **Proxy Support**
   - Implement `WeaviateEx.Config.Proxies`
   - Add environment variable reading
   - Integrate with Finch

### Phase 3: Medium Priority (Week 5-6)

8. **Integrations Module**
   - Implement all provider-specific header generators
   - Add rate limit header support

9. **Additional Config**
   - Implement `WeaviateEx.Config.AdditionalConfig`
   - Add `skip_init_checks` support

10. **Testing & Documentation**
    - Add comprehensive tests for all new modules
    - Update documentation
    - Add examples

---

## 12. Dependencies Required

```elixir
# mix.exs additions

defp deps do
  [
    # Existing
    {:finch, "~> 0.18"},
    {:jason, "~> 1.4"},

    # New for OIDC
    {:req, "~> 0.5"},  # For OIDC token requests

    # New for gRPC (optional)
    {:grpc, "~> 0.7"},
    {:protobuf, "~> 0.12"}
  ]
end
```

---

## 13. Summary

The Elixir WeaviateEx client has significant gaps compared to the Python client in authentication and connection management:

**Critical Gaps (Must Have):**
- Connection factory methods for different deployment scenarios
- OIDC authentication (client credentials, password flow)
- Bearer token with refresh support
- gRPC protocol support

**High Priority Gaps:**
- Granular timeout configuration (query/insert/init)
- Connection pool configuration
- Retry mechanism with exponential backoff
- Proxy support

**Medium Priority Gaps:**
- Third-party integration header helpers
- Skip init checks option
- Full additional config support

The proposed implementations provide idiomatic Elixir solutions that leverage OTP patterns (GenServer for token refresh, supervision trees for connection management) while maintaining API compatibility with the Python client concepts.
