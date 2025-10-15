defmodule Mix.Tasks.Weaviate.Logs do
  @moduledoc """
  Shows logs from the local Weaviate Docker container.

  ## Usage

      mix weaviate.logs [options]

  ## Options

      -f, --follow      - Follow log output (like tail -f)
      -n, --tail        - Number of lines to show from end (default: 100)
      --since           - Show logs since timestamp (e.g. 2023-01-01T00:00:00)
      --until           - Show logs until timestamp

  ## Examples

      # Show last 100 lines
      mix weaviate.logs

      # Show last 50 lines
      mix weaviate.logs -n 50

      # Follow logs in real-time
      mix weaviate.logs --follow

      # Show logs from last 10 minutes
      mix weaviate.logs --since 10m
  """

  use Mix.Task
  require Logger

  @shortdoc "Show logs from local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [follow: :boolean, tail: :integer, since: :string, until: :string],
        aliases: [f: :follow, n: :tail]
      )

    follow = Keyword.get(opts, :follow, false)
    tail = Keyword.get(opts, :tail, 100)
    since = Keyword.get(opts, :since)
    until_time = Keyword.get(opts, :until)

    case check_docker_available() do
      :ok -> show_logs(follow, tail, since, until_time)
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

  defp show_logs(follow, tail, since, until_time) do
    # Build docker compose logs command
    cmd_args = ["compose", "logs", "weaviate", "--tail", "#{tail}"]

    cmd_args =
      if follow do
        cmd_args ++ ["--follow"]
      else
        cmd_args
      end

    cmd_args =
      if since do
        cmd_args ++ ["--since", since]
      else
        cmd_args
      end

    cmd_args =
      if until_time do
        cmd_args ++ ["--until", until_time]
      else
        cmd_args
      end

    # Run the command
    case System.cmd("docker", cmd_args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {_, 1} ->
        Mix.shell().error("""

        No logs found. Is Weaviate running?

        Check status with: mix weaviate.status
        Start with:        mix weaviate.start
        """)

      {_, exit_code} ->
        Mix.raise("Failed to fetch logs (exit code: #{exit_code})")
    end
  end
end
