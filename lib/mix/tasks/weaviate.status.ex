defmodule Mix.Tasks.Weaviate.Status do
  @moduledoc """
  Shows the status of the Weaviate Docker profiles copied from the Python client.

  ## Usage

      mix weaviate.status

  This task iterates every docker-compose file under `ci/weaviate/`, runs `docker compose ps`, and prints any ports configured by the Python client's scripts.

  ## Examples

      mix weaviate.status
  """

  use Mix.Task
  require Logger

  @shortdoc "Show status of local Weaviate Docker container"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Checking Weaviate stack status...\n")
    ensure_docker!()
    show_status()
  end

  defp ensure_docker! do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.raise("Docker Compose is not available")
    end
  end

  defp show_status do
    files = WeaviateEx.DevSupport.Compose.compose_files()

    if files == [] do
      Mix.shell().info("""
      No docker-compose files found under ci/weaviate/.

      Ensure you've copied the assets from the Python client.
      """)
    else
      Enum.each(files, fn file ->
        Mix.shell().info("== #{file} ==")

        case WeaviateEx.DevSupport.Compose.exec_for_file(file, ["ps"],
               into: IO.stream(:stdio, :line)
             ) do
          {_, 0} ->
            Mix.shell().info("")

          {_, exit_code} ->
            Mix.shell().error(
              "docker compose ps failed for #{file} (exit #{exit_code}). Review the output above."
            )
        end
      end)

      display_ports()
    end
  end

  defp display_ports do
    ports = WeaviateEx.DevSupport.Compose.all_ports()

    Mix.shell().info("Exposed HTTP ports (ready when /v1/.well-known/ready returns 200):")

    Enum.each(ports, fn port ->
      Mix.shell().info("  http://localhost:#{port}")
    end)

    Mix.shell().info("""

    Tip: curl http://localhost:8080/v1/meta to verify the primary instance.
    """)

    maybe_show_primary_health()
  end

  defp maybe_show_primary_health do
    {:ok, _} = Application.ensure_all_started(:weaviate_ex)

    case WeaviateEx.health_check() do
      {:ok, meta} ->
        Mix.shell().info("Primary instance (localhost:8080) version: #{meta["version"]}")

      {:error, _reason} ->
        Mix.shell().info("Primary instance at localhost:8080 not reachable yet.")
    end
  end
end
