defmodule WeaviateEx.Auth do
  @moduledoc """
  Authentication configuration for Weaviate connections.

  Supports multiple authentication methods:

  - API Key authentication (Weaviate Cloud)
  - Bearer token authentication
  - OIDC Client Credentials flow
  - OIDC Password flow

  ## Examples

      # API Key (Weaviate Cloud)
      auth = Auth.api_key("your-api-key")

      # Bearer Token
      auth = Auth.bearer_token("access-token", expires_in: 3600)

      # OIDC Client Credentials
      auth = Auth.client_credentials("client-id", "client-secret")

      # OIDC Password
      auth = Auth.client_password("username", "password",
        client_id: "my-client",
        scopes: ["openid", "profile"]
      )
  """

  alias WeaviateEx.Auth.TokenManager

  @type auth_type ::
          :api_key
          | :bearer_token
          | :oidc_client_credentials
          | :oidc_password

  @type api_key_auth :: %{
          type: :api_key,
          api_key: String.t()
        }

  @type bearer_token_auth :: %{
          type: :bearer_token,
          access_token: String.t(),
          expires_in: integer() | nil,
          refresh_token: String.t() | nil
        }

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

  @type t :: api_key_auth() | bearer_token_auth() | client_credentials_auth() | password_auth()

  @doc """
  Create API key authentication.

  This is the most common authentication method for Weaviate Cloud.

  ## Examples

      auth = Auth.api_key("your-weaviate-api-key")
  """
  @spec api_key(String.t()) :: api_key_auth()
  def api_key(key) when is_binary(key) do
    %{
      type: :api_key,
      api_key: key
    }
  end

  @doc """
  Create bearer token authentication.

  ## Options

    - `:expires_in` - Token expiration time in seconds
    - `:refresh_token` - Refresh token for token renewal

  ## Examples

      auth = Auth.bearer_token("access-token")
      auth = Auth.bearer_token("access-token", expires_in: 3600)
  """
  @spec bearer_token(String.t(), keyword()) :: bearer_token_auth()
  def bearer_token(token, opts \\ []) when is_binary(token) do
    %{
      type: :bearer_token,
      access_token: token,
      expires_in: Keyword.get(opts, :expires_in),
      refresh_token: Keyword.get(opts, :refresh_token)
    }
  end

  @doc """
  Create OIDC Client Credentials authentication.

  Used for service-to-service authentication.

  ## Options

    - `:scopes` - OAuth scopes to request (default: [])

  ## Examples

      auth = Auth.client_credentials("client-id", "client-secret")
      auth = Auth.client_credentials("client-id", "client-secret", scopes: ["openid"])
  """
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

  @doc """
  Create OIDC Password (Resource Owner Password Credentials) authentication.

  ## Options

    - `:client_id` - Client ID (optional for some providers)
    - `:client_secret` - Client secret (optional)
    - `:scopes` - OAuth scopes to request (default: [])

  ## Examples

      auth = Auth.client_password("user@example.com", "password")
      auth = Auth.client_password("user", "pass",
        client_id: "my-client",
        scopes: ["openid", "profile"]
      )
  """
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

  @doc """
  Convert authentication config to HTTP headers.

  For OIDC types, this returns an empty list as tokens must be obtained
  via the OIDC token manager first.

  ## Examples

      auth = Auth.api_key("my-key")
      headers = Auth.to_headers(auth)
      # => [{"Authorization", "Bearer my-key"}]
  """
  @spec to_headers(t()) :: [{String.t(), String.t()}]
  def to_headers(%{type: :api_key, api_key: key}) do
    [{"Authorization", "Bearer #{key}"}]
  end

  def to_headers(%{type: :bearer_token, access_token: token}) do
    [{"Authorization", "Bearer #{token}"}]
  end

  def to_headers(%{type: type}) when type in [:oidc_client_credentials, :oidc_password] do
    # OIDC types need token manager to get access token first
    []
  end

  @doc """
  Get headers from an OIDC TokenManager.

  This is a convenience function to get authorization headers when using
  OIDC authentication with a TokenManager.

  ## Examples

      {:ok, headers} = Auth.get_oidc_headers(MyApp.TokenManager)
      # => [{"Authorization", "Bearer <access-token>"}]
  """
  @spec get_oidc_headers(GenServer.server()) ::
          {:ok, [{String.t(), String.t()}]} | {:error, term()}
  def get_oidc_headers(token_manager) do
    case TokenManager.get_access_token(token_manager) do
      {:ok, access_token} ->
        {:ok, [{"Authorization", "Bearer #{access_token}"}]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Create OIDC configuration for use with TokenManager.

  This creates a configuration that can be passed to TokenManager.start_link/1.

  ## Options

    - `:issuer_url` - OIDC issuer URL (required)
    - `:client_id` - Client ID (required)
    - `:client_secret` - Client secret (required for client_credentials)
    - `:username` - Username (required for password grant)
    - `:password` - Password (required for password grant)
    - `:scopes` - OAuth scopes (default: [])
    - `:grant_type` - Grant type: `:client_credentials` or `:password` (default: :client_credentials)

  ## Examples

      # Client credentials grant
      config = Auth.oidc_config(
        issuer_url: "https://auth.example.com",
        client_id: "my-client",
        client_secret: "my-secret"
      )

      {:ok, _pid} = WeaviateEx.Auth.TokenManager.start_link(
        issuer_url: config.issuer_url,
        auth: config.auth,
        name: MyApp.WeaviateTokenManager
      )

      # Password grant
      config = Auth.oidc_config(
        issuer_url: "https://auth.example.com",
        grant_type: :password,
        username: "user@example.com",
        password: "secret",
        client_id: "my-client"
      )
  """
  @spec oidc_config(keyword()) :: %{issuer_url: String.t(), auth: map()}
  def oidc_config(opts) do
    issuer_url = Keyword.fetch!(opts, :issuer_url)
    grant_type = Keyword.get(opts, :grant_type, :client_credentials)

    auth =
      case grant_type do
        :client_credentials ->
          client_credentials(
            Keyword.fetch!(opts, :client_id),
            Keyword.fetch!(opts, :client_secret),
            scopes: Keyword.get(opts, :scopes, [])
          )

        :password ->
          client_password(
            Keyword.fetch!(opts, :username),
            Keyword.fetch!(opts, :password),
            client_id: Keyword.get(opts, :client_id),
            client_secret: Keyword.get(opts, :client_secret),
            scopes: Keyword.get(opts, :scopes, [])
          )
      end

    %{
      issuer_url: issuer_url,
      auth: auth
    }
  end
end
