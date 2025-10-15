defmodule Mix.Tasks.Weaviate.Status do
  @moduledoc """
  Shows the status of the local Weaviate Docker container.

  ## Usage

      mix weaviate.status

  This task will display:
  - Container running status
  - Health check status
  - Port mappings
  - Weaviate version (if running)
  - Connection information

  ## Examples

      mix weaviate.status
  """

  use Mix.Task
  require Logger

  @shortdoc "Show status of local Weaviate Docker container"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Checking Weaviate status...\n")

    case check_docker_available() do
      :ok -> show_status()
      {:error, reason} -> Mix.raise(reason)
    end
  end

  defp check_docker_available do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        {:error, "Docker Compose is not available"}
    end
  end

  defp show_status do
    case get_container_status() do
      {:running, container_info} ->
        display_running_status(container_info)

      :stopped ->
        display_stopped_status()

      :not_found ->
        display_not_found_status()
    end
  end

  defp get_container_status do
    case System.cmd("docker", ["compose", "ps", "--format", "json"], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 ->
        # Parse the JSON output
        case parse_container_info(output) do
          nil -> :not_found
          info -> if info.state == "running", do: {:running, info}, else: :stopped
        end

      _ ->
        :not_found
    end
  end

  defp parse_container_info(json_output) do
    # Docker compose ps can output multiple JSON objects, one per line
    json_output
    |> String.split("\n", trim: true)
    |> Enum.find_value(fn line ->
      case Jason.decode(line) do
        {:ok, %{"Service" => "weaviate"} = container} ->
          %{
            name: container["Name"],
            state: container["State"],
            status: container["Status"],
            health: container["Health"],
            ports: parse_ports(container["Publishers"] || [])
          }

        _ ->
          nil
      end
    end)
  end

  defp parse_ports(publishers) when is_list(publishers) do
    Enum.map(publishers, fn pub ->
      "#{pub["PublishedPort"]}:#{pub["TargetPort"]}"
    end)
  end

  defp parse_ports(_), do: []

  defp display_running_status(info) do
    health_status = format_health_status(info.health)
    health_icon = if info.health == "healthy", do: "✓", else: "⚠"

    Mix.shell().info("""
    Status: RUNNING #{health_icon}

    Container:
      Name:   #{info.name}
      State:  #{info.state}
      Health: #{health_status}
      Status: #{info.status}
    """)

    unless Enum.empty?(info.ports) do
      Mix.shell().info("Ports:")
      Enum.each(info.ports, fn port -> Mix.shell().info("  #{port}") end)
      Mix.shell().info("")
    end

    check_weaviate_api()
  end

  defp display_stopped_status do
    Mix.shell().info("""
    Status: STOPPED

    The Weaviate container exists but is not running.

    To start:
      mix weaviate.start
    """)
  end

  defp display_not_found_status do
    Mix.shell().info("""
    Status: NOT FOUND

    No Weaviate container found.

    To start:
      mix weaviate.start
    """)
  end

  defp format_health_status("healthy"), do: "✓ Healthy"
  defp format_health_status("unhealthy"), do: "✗ Unhealthy"
  defp format_health_status("starting"), do: "⋯ Starting"
  defp format_health_status(nil), do: "- No health check"
  defp format_health_status(other), do: other

  defp check_weaviate_api do
    url = get_weaviate_url()

    Mix.shell().info("API Connection:")
    Mix.shell().info("  URL: #{url}")

    # Start the application to use HTTP client
    {:ok, _} = Application.ensure_all_started(:weaviate_ex)

    case WeaviateEx.health_check() do
      {:ok, meta} ->
        version = meta["version"] || "unknown"
        Mix.shell().info("  Status: ✓ Connected")
        Mix.shell().info("  Version: #{version}")

        Mix.shell().info("""

        Useful commands:
          mix weaviate.logs    - View logs
          mix weaviate.stop    - Stop Weaviate
          curl #{url}/v1/meta  - Test API
        """)

      {:error, reason} ->
        Mix.shell().error("  Status: ✗ Not reachable")
        Mix.shell().error("  Error: #{inspect(reason)}")

        Mix.shell().info("""

        The container is running but the API is not reachable.
        Check logs with: mix weaviate.logs
        """)
    end
  end

  defp get_weaviate_url do
    System.get_env("WEAVIATE_URL", "http://localhost:8080")
  end
end
