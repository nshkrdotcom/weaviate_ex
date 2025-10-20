defmodule Mix.Tasks.Weaviate.Stop do
  @moduledoc """
  Stops the Weaviate Docker stack started by `mix weaviate.start`.

  ## Usage

      mix weaviate.stop [options]

  This task shells out to `ci/weaviate/stop_weaviate.sh`, which tears down every compose profile and removes the `weaviate-data` directory.

  ## Options

      --version, -v          - Docker image tag (default: $WEAVIATE_VERSION or "latest")
      --remove-volumes, -r   - Run an additional `docker compose … down -v` to wipe volumes

  ## Examples

      mix weaviate.stop
      mix weaviate.stop --remove-volumes
  """

  use Mix.Task
  require Logger

  @shortdoc "Stop local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [remove_volumes: :boolean, version: :string],
        aliases: [r: :remove_volumes, v: :version]
      )

    remove_volumes? = Keyword.get(opts, :remove_volumes, false)
    version = Keyword.get(opts, :version, System.get_env("WEAVIATE_VERSION") || "latest")

    if remove_volumes?, do: confirm_volume_removal()

    Mix.shell().info("Stopping Weaviate (version: #{version})\n")

    ensure_docker!()

    case WeaviateEx.DevSupport.Compose.run_script("stop_weaviate.sh", [version],
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        if remove_volumes?, do: remove_volumes()
        Mix.shell().info("\n✓ Weaviate containers stopped")

      {output, status} ->
        Mix.raise("""
        Failed to stop Weaviate (exit #{status})

        #{output}
        """)
    end
  end

  defp ensure_docker! do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.raise("Docker Compose is not available")
    end
  end

  defp confirm_volume_removal do
    Mix.shell().info("""

    WARNING: You are about to remove all Weaviate data volumes.
    This will permanently delete all collections and objects.

    """)

    unless Mix.shell().yes?("Are you sure you want to continue?") do
      Mix.shell().info("Aborted.")
      exit(:normal)
    end
  end

  defp remove_volumes do
    Mix.shell().info("""

    Removing Docker volumes for all Weaviate profiles...
    """)

    case WeaviateEx.DevSupport.Compose.exec_all(["down", "--remove-orphans", "-v"],
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        Mix.shell().info("\n✓ Volumes removed")

      {output, status} ->
        Mix.raise("""
        Failed to remove volumes (exit #{status})

        #{output}
        """)
    end
  end
end
