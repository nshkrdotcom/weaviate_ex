defmodule WeaviateEx.Application do
  @moduledoc """
  Application module for WeaviateEx.

  Starts the Finch HTTP client pool and performs startup health checks
  to ensure Weaviate is properly configured and accessible.
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
        Task.start(fn -> perform_health_check() end)
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
  """
  def perform_health_check do
    case WeaviateEx.health_check() do
      {:ok, _meta} ->
        Logger.info("""
        [WeaviateEx] Successfully connected to Weaviate
          URL: #{weaviate_url()}
          Version: #{get_version_from_meta()}
        """)

        :ok

      {:error, reason} ->
        log_health_check_error(reason)
        {:error, reason}
    end
  end

  # Configuration helpers

  defp weaviate_url do
    System.get_env("WEAVIATE_URL") ||
      Application.get_env(:weaviate_ex, :url)
  end

  defp weaviate_host do
    System.get_env("WEAVIATE_HOST") ||
      Application.get_env(:weaviate_ex, :host) ||
      "localhost"
  end

  defp weaviate_port do
    port =
      System.get_env("WEAVIATE_PORT") ||
        Application.get_env(:weaviate_ex, :port) ||
        "8080"

    case Integer.parse(to_string(port)) do
      {port_int, _} -> port_int
      :error -> 8080
    end
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and not is_nil(uri.host)
  end

  defp get_version_from_meta do
    case WeaviateEx.health_check() do
      {:ok, %{"version" => version}} -> version
      _ -> "unknown"
    end
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
    ║  See INSTALL.md for installation instructions                    ║
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

  defp log_health_check_error(reason) do
    Logger.warning("""

    ╔════════════════════════════════════════════════════════════════╗
    ║              WeaviateEx Health Check Failed                      ║
    ╠════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  Could not connect to Weaviate instance                          ║
    ║  URL: #{weaviate_url()}
    ║  Error: #{inspect(reason)}
    ║                                                                  ║
    ║  Troubleshooting steps:                                          ║
    ║                                                                  ║
    ║  1. Verify Weaviate is running:                                  ║
    ║     docker compose ps                                            ║
    ║                                                                  ║
    ║  2. Check if Weaviate is accessible:                             ║
    ║     curl #{weaviate_url()}/v1/meta
    ║                                                                  ║
    ║  3. Start Weaviate if not running:                               ║
    ║     docker compose up -d                                         ║
    ║                                                                  ║
    ║  4. Check Weaviate logs:                                         ║
    ║     docker compose logs -f weaviate                              ║
    ║                                                                  ║
    ║  5. Verify WEAVIATE_URL matches your setup:                      ║
    ║     echo $WEAVIATE_URL                                           ║
    ║                                                                  ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  For installation help, see: INSTALL.md                          ║
    ╚════════════════════════════════════════════════════════════════╝

    """)
  end
end
