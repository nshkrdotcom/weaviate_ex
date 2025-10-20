defmodule Mix.Tasks.Weaviate.Start do
  @moduledoc """
  Starts the Weaviate Docker stack using the copied Python client scripts.

  ## Usage

      mix weaviate.start [options]

  This task shells out to `ci/weaviate/start_weaviate.sh`, which will:
  - Stop any existing containers
  - Start every docker-compose profile under `ci/weaviate/`
  - Wait until each exposed port reports `/v1/.well-known/ready`

  ## Options

      --version, -v  - Docker image tag (default: $WEAVIATE_VERSION or "latest")
      --profile, -p  - Which script to run (`full` or `async`, default: `full`)

  ## Examples

      mix weaviate.start --version 1.30.5
      mix weaviate.start --profile async

  The script outputs progress logs directly; this task simply forwards stdout/stderr.
  """

  use Mix.Task
  require Logger

  @shortdoc "Start local Weaviate Docker container"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [version: :string, profile: :string],
        aliases: [v: :version, p: :profile]
      )

    profile =
      opts
      |> Keyword.get(:profile, "full")
      |> String.downcase()
      |> case do
        "async" -> :async
        "full" -> :full
        other -> Mix.raise("Unknown profile #{inspect(other)}. Use \"full\" or \"async\".")
      end

    version = Keyword.get(opts, :version, System.get_env("WEAVIATE_VERSION") || "latest")

    Mix.shell().info("Starting Weaviate (profile: #{profile}, version: #{version})\n")

    ensure_docker!()

    script =
      case profile do
        :async -> "start_weaviate_jt.sh"
        :full -> "start_weaviate.sh"
      end

    {_, status} =
      WeaviateEx.DevSupport.Compose.run_script(script, [version], into: IO.stream(:stdio, :line))

    if status == 0 do
      Mix.shell().info("\n✓ All Weaviate containers are running")
    else
      Mix.raise("""
      Failed to start Weaviate (exit #{status}). Review the output above for details.
      """)
    end
  end

  defp ensure_docker! do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.raise("""
        Docker Compose is not available.

        Please install Docker and Docker Compose:
        https://docs.docker.com/get-docker/
        """)
    end
  end
end
