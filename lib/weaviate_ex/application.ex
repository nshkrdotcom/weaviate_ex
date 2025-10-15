defmodule WeaviateEx.Application do
  @moduledoc """
  Application module for WeaviateEx.

  Starts the Finch HTTP client pool and performs startup health checks
  to ensure Weaviate is properly configured and accessible.

  ## Configuration

  You can configure the strictness of health checks:

      config :weaviate_ex,
        url: "http://localhost:8080",
        strict: true  # Default: true

  When `strict: true`, the application will raise an error if it cannot
  connect to Weaviate on startup. Set to `false` to allow the application
  to start even if Weaviate is unreachable (useful for development).

  ## Mix Tasks

  WeaviateEx provides Mix tasks for managing local Weaviate instances:

    * `mix weaviate.start` - Start Weaviate Docker container
    * `mix weaviate.stop` - Stop Weaviate Docker container
    * `mix weaviate.status` - Show Weaviate status
    * `mix weaviate.logs` - View Weaviate logs
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Validate configuration on startup
    case validate_config() do
      :ok ->
        start_application()

      {:error, message} ->
        log_configuration_error(message)
        # Still start the application but log warnings
        start_application()
    end
  end

  defp start_application do
    children = [
      # Start Finch HTTP client pool
      {Finch,
       name: WeaviateEx.Finch,
       pools: %{
         default: [size: 25, count: 2]
       }}
    ]

    opts = [strategy: :one_for_one, name: WeaviateEx.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Perform health check after supervisor starts
        strict = Application.get_env(:weaviate_ex, :strict, true)
        Task.start(fn -> perform_health_check(strict) end)
        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Validates that required configuration is present.
  """
  def validate_config do
    url = weaviate_url()

    cond do
      is_nil(url) or url == "" ->
        {:error, :missing_url}

      not valid_url?(url) ->
        {:error, {:invalid_url, url}}

      true ->
        :ok
    end
  end

  @doc """
  Performs a health check against the Weaviate instance.
  Returns :ok if healthy, {:error, reason} otherwise.

  If `strict` is true (default), raises an error on connection failure.
  If `strict` is false, logs a warning and continues.
  """
  def perform_health_check(strict \\ true) do
    WeaviateEx.Health.validate_connection!(strict: strict)
  end

  # Configuration helpers

  defp weaviate_url do
    System.get_env("WEAVIATE_URL") ||
      Application.get_env(:weaviate_ex, :url)
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and not is_nil(uri.host)
  end

  # Error logging with helpful messages

  defp log_configuration_error(:missing_url) do
    Logger.warning("""

    ╔════════════════════════════════════════════════════════════════╗
    ║                  WeaviateEx Configuration Error                 ║
    ╠════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  Missing required configuration: WEAVIATE_URL                    ║
    ║                                                                  ║
    ║  Please set the Weaviate URL using one of these methods:        ║
    ║                                                                  ║
    ║  1. Environment variable:                                        ║
    ║     export WEAVIATE_URL=http://localhost:8080                   ║
    ║                                                                  ║
    ║  2. Application configuration (config/config.exs):               ║
    ║     config :weaviate_ex,                                        ║
    ║       url: "http://localhost:8080"                              ║
    ║                                                                  ║
    ║  3. Runtime configuration (config/runtime.exs):                  ║
    ║     config :weaviate_ex,                                        ║
    ║       url: System.get_env("WEAVIATE_URL")                       ║
    ║                                                                  ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  Need help setting up Weaviate?                                  ║
    ║  Run: mix weaviate.start                                         ║
    ╚════════════════════════════════════════════════════════════════╝

    """)
  end

  defp log_configuration_error({:invalid_url, url}) do
    Logger.warning("""

    ╔════════════════════════════════════════════════════════════════╗
    ║                  WeaviateEx Configuration Error                 ║
    ╠════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  Invalid WEAVIATE_URL: #{url}
    ║                                                                  ║
    ║  The URL must include a scheme (http:// or https://) and host.  ║
    ║                                                                  ║
    ║  Examples of valid URLs:                                         ║
    ║    - http://localhost:8080                                      ║
    ║    - https://my-cluster.weaviate.network                        ║
    ║    - http://192.168.1.100:8080                                  ║
    ║                                                                  ║
    ╚════════════════════════════════════════════════════════════════╝

    """)
  end
end
