defmodule WeaviateEx.Health do
  @moduledoc """
  Health check utilities for Weaviate connections.

  Provides functions to validate connectivity and perform health checks
  against Weaviate instances with configurable strictness.
  """

  require Logger

  @type health_result :: {:ok, map()} | {:error, term()}
  @type strict_mode :: :strict | :relaxed

  @doc """
  Validates connection to Weaviate with configurable strictness.

  ## Options

    * `:strict` - (default: `true`) If true, raises on connection failure.
      If false, logs a warning and returns the error.
    * `:timeout` - Connection timeout in milliseconds (default: 5000)
    * `:retries` - Number of retry attempts (default: 0)
    * `:retry_delay` - Delay between retries in milliseconds (default: 1000)

  ## Examples

      # Strict mode (default) - raises on failure
      WeaviateEx.Health.validate_connection!()

      # Relaxed mode - returns error without raising
      WeaviateEx.Health.validate_connection!(strict: false)

      # With retries
      WeaviateEx.Health.validate_connection!(retries: 3, retry_delay: 2000)
  """
  @spec validate_connection!(Keyword.t()) :: :ok | {:error, term()}
  def validate_connection!(opts \\ []) do
    strict = Keyword.get(opts, :strict, true)
    timeout = Keyword.get(opts, :timeout, 5000)
    retries = Keyword.get(opts, :retries, 0)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)

    case attempt_connection(timeout, retries, retry_delay) do
      {:ok, meta} ->
        log_successful_connection(meta)
        :ok

      {:error, reason} = error ->
        if strict do
          log_strict_failure(reason)
          raise_connection_error(reason)
        else
          log_relaxed_failure(reason)
          error
        end
    end
  end

  @doc """
  Checks connection to Weaviate without raising errors.

  Returns `{:ok, meta}` if connected, `{:error, reason}` otherwise.

  ## Examples

      case WeaviateEx.Health.check_connection() do
        {:ok, meta} -> IO.puts("Connected to Weaviate v\#{meta["version"]}")
        {:error, reason} -> IO.puts("Not connected: \#{inspect(reason)}")
      end
  """
  @spec check_connection(Keyword.t()) :: health_result()
  def check_connection(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    retries = Keyword.get(opts, :retries, 0)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)

    attempt_connection(timeout, retries, retry_delay)
  end

  @doc """
  Waits for Weaviate to become ready.

  Useful for startup scripts and testing.

  ## Options

    * `:timeout` - Total wait timeout in milliseconds (default: 30000)
    * `:check_interval` - Time between checks in milliseconds (default: 1000)

  ## Examples

      # Wait up to 30 seconds
      WeaviateEx.Health.wait_until_ready()

      # Wait up to 60 seconds with 2 second intervals
      WeaviateEx.Health.wait_until_ready(timeout: 60000, check_interval: 2000)
  """
  @spec wait_until_ready(Keyword.t()) :: :ok | {:error, :timeout}
  def wait_until_ready(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    check_interval = Keyword.get(opts, :check_interval, 1000)

    start_time = System.monotonic_time(:millisecond)
    wait_loop(start_time, timeout, check_interval)
  end

  @doc """
  Check if Weaviate is alive (liveness probe).

  Uses the `/.well-known/live` endpoint for Kubernetes compatibility.
  Returns `{:ok, true}` if alive, `{:ok, false}` otherwise.

  ## With Client

      {:ok, true} = Health.alive?(client)

  ## Without Client (uses default WeaviateEx config)

      {:ok, true} = Health.alive?()

  This endpoint indicates whether the Weaviate process is running.
  A failed liveness check means the container should be restarted.
  """
  @spec alive?(WeaviateEx.Client.t()) :: {:ok, boolean()}
  @spec alive?() :: {:ok, boolean()}
  def alive?(%WeaviateEx.Client{} = client) do
    case WeaviateEx.Client.request(client, :get, "/.well-known/live", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, %{status_code: status}} when status in 400..599 -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  def alive? do
    case WeaviateEx.request(:get, "/.well-known/live", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, %{status_code: status}} when status in 400..599 -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  @doc """
  Check if Weaviate is ready (readiness probe).

  Uses the `/.well-known/ready` endpoint for Kubernetes compatibility.
  Returns `{:ok, true}` if ready, `{:ok, false}` otherwise.

  ## With Client

      {:ok, true} = Health.ready?(client)

  ## Without Client (uses default WeaviateEx config)

      {:ok, true} = Health.ready?()

  This endpoint indicates whether Weaviate is ready to receive traffic.
  A failed readiness check means the container should not receive requests.
  """
  @spec ready?(WeaviateEx.Client.t()) :: {:ok, boolean()}
  @spec ready?() :: {:ok, boolean()}
  def ready?(%WeaviateEx.Client{} = client) do
    case WeaviateEx.Client.request(client, :get, "/.well-known/ready", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, %{status_code: status}} when status in 400..599 -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  def ready? do
    case WeaviateEx.request(:get, "/.well-known/ready", nil, []) do
      {:ok, _} -> {:ok, true}
      {:error, %{status_code: status}} when status in 400..599 -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  # Private functions

  defp attempt_connection(timeout, retries, retry_delay, attempt \\ 0) do
    case WeaviateEx.request(:get, "/v1/meta", nil, receive_timeout: timeout) do
      {:ok, meta} ->
        {:ok, meta}

      {:error, _reason} when attempt < retries ->
        Logger.debug("Connection attempt #{attempt + 1} failed, retrying in #{retry_delay}ms...")
        Process.sleep(retry_delay)
        attempt_connection(timeout, retries, retry_delay, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_loop(start_time, timeout, check_interval) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed >= timeout do
      {:error, :timeout}
    else
      case check_connection(timeout: 1000) do
        {:ok, _} ->
          :ok

        {:error, _} ->
          Process.sleep(check_interval)
          wait_loop(start_time, timeout, check_interval)
      end
    end
  end

  defp log_successful_connection(meta) do
    version = meta["version"] || "unknown"
    url = WeaviateEx.base_url()

    Logger.info("""
    [WeaviateEx] Successfully connected to Weaviate
      URL: #{url}
      Version: #{version}
    """)
  end

  defp log_strict_failure(reason) do
    url = WeaviateEx.base_url()

    Logger.error("""
    [WeaviateEx] Failed to connect to Weaviate (strict mode)
      URL: #{url}
      Error: #{format_error(reason)}

    The application cannot start without a valid Weaviate connection.

    Troubleshooting:
      1. Ensure Weaviate is running: mix weaviate.start
      2. Check status: mix weaviate.status
      3. View logs: mix weaviate.logs
      4. Verify WEAVIATE_URL is correct: #{url}
    """)
  end

  defp log_relaxed_failure(reason) do
    url = WeaviateEx.base_url()

    Logger.warning("""
    [WeaviateEx] Could not connect to Weaviate (relaxed mode)
      URL: #{url}
      Error: #{format_error(reason)}

    The application will continue, but Weaviate operations will fail.
    Start Weaviate with: mix weaviate.start
    """)
  end

  defp raise_connection_error(reason) do
    raise """
    Failed to connect to Weaviate instance.

    Error: #{format_error(reason)}
    URL: #{WeaviateEx.base_url()}

    Make sure Weaviate is running:
      mix weaviate.start

    Or set :strict option to false in config to allow startup without connection:
      config :weaviate_ex, strict: false
    """
  end

  defp format_error(%WeaviateEx.Error{message: msg, type: type}), do: "#{type}: #{msg}"
end
