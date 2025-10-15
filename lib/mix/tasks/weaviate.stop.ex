defmodule Mix.Tasks.Weaviate.Stop do
  @moduledoc """
  Stops the local Weaviate Docker container.

  ## Usage

      mix weaviate.stop

  This task will stop the Weaviate container using docker compose.

  ## Options

      --remove-volumes, -v  - Remove data volumes (WARNING: deletes all data)
      --timeout, -t         - Shutdown timeout in seconds (default: 10)

  ## Examples

      # Stop Weaviate
      mix weaviate.stop

      # Stop and remove all data
      mix weaviate.stop --remove-volumes
  """

  use Mix.Task
  require Logger

  @shortdoc "Stop local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [remove_volumes: :boolean, timeout: :integer],
        aliases: [v: :remove_volumes, t: :timeout]
      )

    remove_volumes = Keyword.get(opts, :remove_volumes, false)
    timeout = Keyword.get(opts, :timeout, 10)

    if remove_volumes do
      confirm_volume_removal()
    end

    Mix.shell().info("Stopping Weaviate...")

    case check_docker_available() do
      :ok -> stop_weaviate(remove_volumes, timeout)
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

  defp stop_weaviate(remove_volumes, timeout) do
    cmd_args = ["compose", "down", "--timeout", "#{timeout}"]
    cmd_args = if remove_volumes, do: cmd_args ++ ["-v"], else: cmd_args

    case System.cmd("docker", cmd_args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_, 0} ->
        if remove_volumes do
          Mix.shell().info("\n✓ Weaviate stopped and all data volumes removed")
        else
          Mix.shell().info("\n✓ Weaviate stopped successfully")
          Mix.shell().info("  (Data persisted in volumes)")
        end

        :ok

      {_, exit_code} ->
        Mix.raise("Failed to stop Weaviate (exit code: #{exit_code})")
    end
  end
end
