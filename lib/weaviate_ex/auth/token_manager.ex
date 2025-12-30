defmodule WeaviateEx.Auth.TokenManager do
  @moduledoc """
  GenServer for managing OIDC tokens with automatic refresh.

  The TokenManager handles:
  - Initial token acquisition
  - Automatic token refresh before expiration
  - Thread-safe token access
  - Error recovery and retry logic

  ## Usage

      # Start with OIDC config
      {:ok, pid} = TokenManager.start_link(
        oidc_config: oidc_config,
        auth: %{type: :oidc_client_credentials, client_id: "id", client_secret: "secret", scopes: []}
      )

      # Or start with issuer URL (auto-discovers OIDC config)
      {:ok, pid} = TokenManager.start_link(
        issuer_url: "https://auth.example.com",
        auth: auth
      )

      # Get current token
      {:ok, token} = TokenManager.get_token(pid)

      # Get just the access token string
      {:ok, access_token} = TokenManager.get_access_token(pid)

      # Force immediate refresh
      :ok = TokenManager.force_refresh(pid)

  ## Options

    - `:oidc_config` - Pre-configured OIDC config struct
    - `:issuer_url` - Issuer URL for auto-discovery (alternative to :oidc_config)
    - `:auth` - Authentication credentials (required)
    - `:name` - GenServer name (optional)
    - `:refresh_buffer_seconds` - Refresh token this many seconds before expiry (default: 60)
  """

  use GenServer
  require Logger

  alias WeaviateEx.Auth.OIDC
  alias WeaviateEx.Auth.OIDC.{Config, TokenResponse}

  @default_refresh_buffer 60

  @doc """
  Returns a child specification for starting TokenManager under a supervisor.

  ## Examples

      # In your supervision tree
      children = [
        {WeaviateEx.Auth.TokenManager,
         issuer_url: "https://auth.example.com",
         auth: %{type: :oidc_client_credentials, client_id: "id", client_secret: "secret", scopes: []},
         name: MyApp.WeaviateTokenManager}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @type state :: %{
          oidc_config: Config.t() | nil,
          auth: map(),
          token: TokenResponse.t() | nil,
          refresh_buffer_seconds: non_neg_integer(),
          refresh_timer: reference() | nil
        }

  # Client API

  @doc """
  Start the TokenManager GenServer.

  ## Options

    - `:oidc_config` - Pre-configured OIDC config struct
    - `:issuer_url` - Issuer URL for auto-discovery
    - `:auth` - Authentication credentials (required)
    - `:name` - GenServer name (optional)
    - `:refresh_buffer_seconds` - Seconds before expiry to refresh (default: 60)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Get the current token.

  Returns `{:ok, token}` if a valid token is available,
  or `{:error, :no_token}` if no token has been acquired.
  """
  @spec get_token(GenServer.server()) :: {:ok, TokenResponse.t()} | {:error, :no_token}
  def get_token(server) do
    GenServer.call(server, :get_token)
  end

  @doc """
  Get just the access token string.

  Convenience function that extracts the access_token from the token response.
  """
  @spec get_access_token(GenServer.server()) :: {:ok, String.t()} | {:error, :no_token}
  def get_access_token(server) do
    case get_token(server) do
      {:ok, token} -> {:ok, token.access_token}
      error -> error
    end
  end

  @doc """
  Force an immediate token refresh.
  """
  @spec force_refresh(GenServer.server()) :: :ok
  def force_refresh(server) do
    GenServer.cast(server, :force_refresh)
  end

  # Server Callbacks

  @valid_grant_types [:oidc_client_credentials, :oidc_password]

  @impl true
  def init(opts) do
    auth = Keyword.fetch!(opts, :auth)

    case validate_auth(auth) do
      :ok -> init_with_valid_auth(opts, auth)
      {:error, reason} -> {:stop, {:invalid_auth, reason}}
    end
  end

  defp init_with_valid_auth(opts, auth) do
    state = %{
      oidc_config: Keyword.get(opts, :oidc_config),
      auth: auth,
      token: nil,
      refresh_buffer_seconds: Keyword.get(opts, :refresh_buffer_seconds, @default_refresh_buffer),
      refresh_timer: nil
    }

    state = maybe_discover_oidc(state, Keyword.get(opts, :issuer_url))

    # Schedule initial token fetch
    send(self(), :fetch_token)

    {:ok, state}
  end

  defp maybe_discover_oidc(state, nil), do: state

  defp maybe_discover_oidc(state, issuer_url) do
    case OIDC.discover(issuer_url) do
      {:ok, config} ->
        %{state | oidc_config: config}

      {:error, reason} ->
        Logger.error("Failed to discover OIDC config: #{inspect(reason)}")
        state
    end
  end

  @impl true
  def handle_call(:get_token, _from, %{token: nil} = state) do
    {:reply, {:error, :no_token}, state}
  end

  def handle_call(:get_token, _from, %{token: token} = state) do
    {:reply, {:ok, token}, state}
  end

  @impl true
  def handle_cast(:force_refresh, state) do
    # Cancel any pending refresh timer
    state = cancel_refresh_timer(state)
    # Fetch new token immediately
    send(self(), :fetch_token)
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_token, %{oidc_config: nil} = state) do
    Logger.warning("TokenManager: No OIDC config available")
    {:noreply, state}
  end

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

  def handle_info(:refresh_token, state) do
    send(self(), :fetch_token)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private helpers

  defp fetch_or_refresh_token(%{token: nil, oidc_config: config, auth: auth}) do
    OIDC.get_token(config, auth)
  end

  defp fetch_or_refresh_token(%{token: token, oidc_config: config, auth: auth}) do
    # Try to use refresh token if available
    if token.refresh_token do
      case OIDC.refresh_token(config, token.refresh_token) do
        {:ok, new_token} ->
          {:ok, new_token}

        {:error, _reason} ->
          # Fall back to getting new token
          OIDC.get_token(config, auth)
      end
    else
      # No refresh token, get a new one
      OIDC.get_token(config, auth)
    end
  end

  defp schedule_refresh(%{token: token, refresh_buffer_seconds: buffer} = state)
       when not is_nil(token) do
    case token.expires_in do
      nil ->
        state

      expires_in ->
        # Schedule refresh before expiration
        refresh_in = max(1, (expires_in - buffer) * 1000)
        timer_ref = Process.send_after(self(), :refresh_token, refresh_in)
        %{state | refresh_timer: timer_ref}
    end
  end

  defp schedule_refresh(state), do: state

  defp cancel_refresh_timer(%{refresh_timer: nil} = state), do: state

  defp cancel_refresh_timer(%{refresh_timer: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | refresh_timer: nil}
  end

  # Auth validation

  @doc false
  def validate_auth(%{type: type} = auth) when type in @valid_grant_types do
    validate_auth_fields(auth)
  end

  def validate_auth(%{type: type}) do
    {:error, {:unsupported_grant_type, type, @valid_grant_types}}
  end

  def validate_auth(_auth) do
    {:error, :missing_type}
  end

  defp validate_auth_fields(%{type: :oidc_client_credentials} = auth) do
    required = [:client_id, :client_secret]
    missing = Enum.filter(required, fn key -> !Map.has_key?(auth, key) || is_nil(auth[key]) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_auth_fields(%{type: :oidc_password} = auth) do
    required = [:username, :password]
    missing = Enum.filter(required, fn key -> !Map.has_key?(auth, key) || is_nil(auth[key]) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end
end
