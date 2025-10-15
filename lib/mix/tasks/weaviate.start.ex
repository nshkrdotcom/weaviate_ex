defmodule Mix.Tasks.Weaviate.Start do
  @moduledoc """
  Starts the local Weaviate Docker container.

  ## Usage

      mix weaviate.start

  This task will:
  - Start Weaviate using docker compose
  - Wait for the health check to pass
  - Display connection information

  ## Options

      --detach     - Start in detached mode (default: true)
      --no-wait    - Don't wait for health check
      --timeout    - Health check timeout in seconds (default: 60)

  ## Examples

      # Start Weaviate and wait for it to be healthy
      mix weaviate.start

      # Start without waiting for health check
      mix weaviate.start --no-wait
  """

  use Mix.Task
  require Logger

  @shortdoc "Start local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [detach: :boolean, wait: :boolean, timeout: :integer],
        aliases: [d: :detach, w: :wait, t: :timeout]
      )

    detach = Keyword.get(opts, :detach, true)
    wait = Keyword.get(opts, :wait, true)
    timeout = Keyword.get(opts, :timeout, 60)

    Mix.shell().info("Starting Weaviate...")

    case check_docker_available() do
      :ok -> start_weaviate(detach, wait, timeout)
      {:error, reason} -> Mix.raise(reason)
    end
  end

  defp check_docker_available do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        {:error,
         """
         Docker Compose is not available.

         Please install Docker and Docker Compose:
         https://docs.docker.com/get-docker/
         """}
    end
  end

  defp start_weaviate(detach, wait, timeout) do
    # Check if docker-compose.yml exists
    unless File.exists?("docker-compose.yml") do
      Mix.raise("""
      docker-compose.yml not found in current directory.

      Make sure you're running this command from the project root.
      """)
    end

    # Start docker compose
    cmd_args = ["compose", "up"]
    cmd_args = if detach, do: cmd_args ++ ["-d"], else: cmd_args

    case System.cmd("docker", cmd_args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_, 0} ->
        if wait and detach do
          wait_for_health(timeout)
        else
          Mix.shell().info("Weaviate started successfully")
        end

        :ok

      {_, exit_code} ->
        Mix.raise("Failed to start Weaviate (exit code: #{exit_code})")
    end
  end

  defp wait_for_health(timeout) do
    Mix.shell().info("\nWaiting for Weaviate to become healthy (timeout: #{timeout}s)...")

    start_time = System.system_time(:second)
    wait_loop(start_time, timeout)
  end

  defp wait_loop(start_time, timeout) do
    elapsed = System.system_time(:second) - start_time

    if elapsed >= timeout do
      Mix.shell().error("""

      Weaviate did not become healthy within #{timeout} seconds.

      Check the logs with: mix weaviate.logs
      """)

      :timeout
    else
      case check_health() do
        :healthy ->
          display_success_message()
          :ok

        :unhealthy ->
          Mix.shell().info(".")
          Process.sleep(2000)
          wait_loop(start_time, timeout)
      end
    end
  end

  defp check_health do
    case System.cmd("docker", ["compose", "ps", "--format", "json"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "healthy") do
          :healthy
        else
          :unhealthy
        end

      _ ->
        :unhealthy
    end
  end

  defp display_success_message do
    url = get_weaviate_url()

    Mix.shell().info("""

    ✓ Weaviate is healthy and ready!

    Connection Info:
      URL: #{url}
      API: #{url}/v1

    Quick test:
      curl #{url}/v1/meta

    Useful commands:
      mix weaviate.status  - Check status
      mix weaviate.logs    - View logs
      mix weaviate.stop    - Stop Weaviate
    """)
  end

  defp get_weaviate_url do
    System.get_env("WEAVIATE_URL", "http://localhost:8080")
  end
end
