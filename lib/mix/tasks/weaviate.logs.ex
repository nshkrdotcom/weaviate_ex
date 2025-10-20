defmodule Mix.Tasks.Weaviate.Logs do
  @moduledoc """
  Shows logs from the Weaviate Docker profiles copied from the Python client.

  ## Usage

      mix weaviate.logs [options]

  ## Options

      -f, --follow      - Follow log output (requires --file)
      -n, --tail        - Number of lines to show from end (default: 100)
      --since           - Show logs since timestamp (e.g. 10m, 2023-01-01T00:00:00)
      --until           - Show logs until timestamp
      --service         - Limit to a specific compose service
      --file            - Restrict to a specific docker-compose file (e.g. docker-compose.yml)

  ## Examples

      # Show last 100 lines
      mix weaviate.logs

      # Follow async profile logs
      mix weaviate.logs --file docker-compose-async.yml --follow
  """

  use Mix.Task
  require Logger

  @shortdoc "Show logs from local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          follow: :boolean,
          tail: :integer,
          since: :string,
          until: :string,
          service: :string,
          file: :string
        ],
        aliases: [f: :follow, n: :tail]
      )

    follow? = Keyword.get(opts, :follow, false)
    tail = Keyword.get(opts, :tail, 100)
    since = Keyword.get(opts, :since)
    until_time = Keyword.get(opts, :until)
    service = Keyword.get(opts, :service)
    file_filter = Keyword.get(opts, :file)

    ensure_docker!()

    files =
      case file_filter do
        nil -> WeaviateEx.DevSupport.Compose.compose_files()
        file -> [file]
      end

    if files == [] do
      Mix.raise("No docker-compose files found under ci/weaviate/")
    end

    if follow? and length(files) > 1 do
      Mix.raise("--follow is only supported with a single --file")
    end

    args =
      ["logs", "--tail", Integer.to_string(tail)]
      |> add_optional("--follow", follow?)
      |> add_option("--since", since)
      |> add_option("--until", until_time)
      |> add_service(service)

    Enum.each(files, fn file ->
      Mix.shell().info("\n== #{file} ==")

      case WeaviateEx.DevSupport.Compose.exec_for_file(file, args, into: IO.stream(:stdio, :line)) do
        {_, 0} ->
          :ok

        {output, 1} ->
          Mix.shell().error("""

          No logs for #{file}? Ensure the services are running.

          #{output}
          """)

        {output, exit_code} ->
          Mix.raise("""
          Failed to fetch logs from #{file} (exit #{exit_code})

          #{output}
          """)
      end
    end)
  end

  defp ensure_docker! do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.raise("Docker Compose is not available")
    end
  end

  defp add_optional(args, _flag, false), do: args
  defp add_optional(args, flag, true), do: args ++ [flag]

  defp add_option(args, _flag, nil), do: args
  defp add_option(args, flag, value), do: args ++ [flag, value]

  defp add_service(args, nil), do: args
  defp add_service(args, service), do: args ++ [service]
end
