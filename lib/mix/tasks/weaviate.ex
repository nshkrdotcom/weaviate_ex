defmodule Mix.Tasks.Weaviate.Start do
  @moduledoc """
  Starts Weaviate Docker containers using the CI scripts.

  ## Usage

      mix weaviate.start [options]

  This task runs `./ci/start_weaviate.sh` which will:
  - Stop any existing Weaviate containers
  - Start all docker-compose configurations
  - Wait until each Weaviate instance reports ready via `/v1/.well-known/ready`

  ## Options

      --version, -v  - Weaviate Docker image version (default: 1.28.14)
      --all, -a      - Start all configurations (default behavior)

  ## Examples

      mix weaviate.start
      mix weaviate.start --version 1.30.5
      mix weaviate.start --all --version 1.28.14

  """

  use Mix.Task

  @shortdoc "Start Weaviate Docker containers"

  @default_version "1.28.14"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [version: :string, all: :boolean],
        aliases: [v: :version, a: :all]
      )

    version = Keyword.get(opts, :version, @default_version)
    _all = Keyword.get(opts, :all, true)

    Mix.shell().info("Starting Weaviate containers (version: #{version})...")

    ensure_docker!()
    ensure_script_exists!("start_weaviate.sh")

    script_path = script_path("start_weaviate.sh")

    case System.cmd("bash", [script_path, version],
           cd: project_root(),
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        Mix.shell().info("\nWeaviate containers started successfully")

      {_, exit_code} ->
        Mix.raise("Failed to start Weaviate (exit code: #{exit_code})")
    end
  end

  defp ensure_docker! do
    case System.cmd("docker", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> Mix.raise("Docker is not available. Please install Docker first.")
    end
  end

  defp ensure_script_exists!(script) do
    path = script_path(script)

    unless File.exists?(path) do
      Mix.raise("Script not found: #{path}")
    end
  end

  defp script_path(script), do: Path.join([project_root(), "ci", script])
  defp project_root, do: Path.expand("../../../..", __DIR__)
end

defmodule Mix.Tasks.Weaviate.Stop do
  @moduledoc """
  Stops Weaviate Docker containers using the CI scripts.

  ## Usage

      mix weaviate.stop [options]

  This task runs `./ci/stop_weaviate.sh` which will:
  - Stop all docker-compose configurations
  - Remove the `weaviate-data` directory (unless --keep-data is specified)

  ## Options

      --keep-data, -k  - Preserve Weaviate data directory after stopping

  ## Examples

      mix weaviate.stop
      mix weaviate.stop --keep-data

  """

  use Mix.Task

  @shortdoc "Stop Weaviate Docker containers"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [keep_data: :boolean],
        aliases: [k: :keep_data]
      )

    keep_data = Keyword.get(opts, :keep_data, false)

    Mix.shell().info("Stopping Weaviate containers...")

    ensure_docker!()
    ensure_script_exists!("stop_weaviate.sh")

    script_path = script_path("stop_weaviate.sh")

    case System.cmd("bash", [script_path],
           cd: project_root(),
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        if keep_data do
          Mix.shell().info("\nWeaviate containers stopped (data preserved)")
        else
          Mix.shell().info("\nWeaviate containers stopped")
        end

      {_, exit_code} ->
        Mix.raise("Failed to stop Weaviate (exit code: #{exit_code})")
    end

    # If keep_data was requested but script already removed data, warn user
    if keep_data do
      Mix.shell().info(
        "Note: The stop script removes weaviate-data by default. " <>
          "To preserve data, modify the script or stop containers manually."
      )
    end
  end

  defp ensure_docker! do
    case System.cmd("docker", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> Mix.raise("Docker is not available. Please install Docker first.")
    end
  end

  defp ensure_script_exists!(script) do
    path = script_path(script)

    unless File.exists?(path) do
      Mix.raise("Script not found: #{path}")
    end
  end

  defp script_path(script), do: Path.join([project_root(), "ci", script])
  defp project_root, do: Path.expand("../../../..", __DIR__)
end

defmodule Mix.Tasks.Weaviate.Status do
  @moduledoc """
  Shows the status of Weaviate Docker containers.

  ## Usage

      mix weaviate.status

  This task displays:
  - Running Weaviate-related Docker containers via `docker ps`
  - Health check status for the primary Weaviate instance

  ## Examples

      mix weaviate.status

  """

  use Mix.Task

  @shortdoc "Show status of Weaviate Docker containers"

  @primary_port 8080
  @health_timeout 5000

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Checking Weaviate container status...\n")

    ensure_docker!()

    # Show docker ps output filtered for weaviate
    Mix.shell().info("=== Docker Containers ===\n")

    case System.cmd(
           "docker",
           [
             "ps",
             "--filter",
             "name=weaviate",
             "--format",
             "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        if String.trim(output) == "" or output =~ ~r/^NAMES\s*$/ do
          Mix.shell().info("No Weaviate containers running.\n")
        else
          Mix.shell().info(output)
        end

      {output, _} ->
        Mix.shell().info("docker ps output:\n#{output}")
    end

    # Also show all containers that might be related
    Mix.shell().info("\n=== All Weaviate-related Containers ===\n")

    {output, _} =
      System.cmd("docker", ["ps", "-a", "--filter", "name=weaviate"], stderr_to_stdout: true)

    Mix.shell().info(output)

    # Health check
    Mix.shell().info("\n=== Health Check ===\n")
    check_health()
  end

  defp ensure_docker! do
    case System.cmd("docker", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> Mix.raise("Docker is not available. Please install Docker first.")
    end
  end

  defp check_health do
    # Ensure inets is started for HTTP requests
    :ok = Application.ensure_started(:inets)
    :ok = Application.ensure_started(:ssl)

    url = ~c"http://localhost:#{@primary_port}/v1/.well-known/ready"

    case :httpc.request(:get, {url, []}, [timeout: @health_timeout], []) do
      {:ok, {{_, 200, _}, _, _}} ->
        Mix.shell().info("Primary instance (localhost:#{@primary_port}): READY")
        fetch_version()

      {:ok, {{_, status, _}, _, _}} ->
        Mix.shell().info(
          "Primary instance (localhost:#{@primary_port}): NOT READY (HTTP #{status})"
        )

      {:error, reason} ->
        Mix.shell().info(
          "Primary instance (localhost:#{@primary_port}): UNREACHABLE (#{inspect(reason)})"
        )
    end
  end

  defp fetch_version do
    url = ~c"http://localhost:#{@primary_port}/v1/meta"

    case :httpc.request(:get, {url, []}, [timeout: @health_timeout], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"version" => version}} ->
            Mix.shell().info("Weaviate version: #{version}")

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end
end

defmodule Mix.Tasks.Weaviate.Test do
  @moduledoc """
  Runs integration tests with Weaviate Docker containers.

  ## Usage

      mix weaviate.test [options]

  This task will:
  1. Start Weaviate containers using `./ci/start_weaviate.sh`
  2. Wait for Weaviate to be ready
  3. Run integration tests with `WEAVIATE_INTEGRATION=true`
  4. Stop Weaviate containers (unless --keep is specified)

  ## Options

      --keep, -k     - Keep Weaviate running after tests complete
      --version, -v  - Weaviate Docker image version (default: 1.28.14)

  ## Examples

      mix weaviate.test
      mix weaviate.test --keep
      mix weaviate.test --version 1.30.5

  """

  use Mix.Task

  @shortdoc "Start Weaviate, run integration tests, stop Weaviate"

  @default_version "1.28.14"
  @primary_port 8080
  @health_timeout 5000
  @max_wait_seconds 60

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [keep: :boolean, version: :string],
        aliases: [k: :keep, v: :version]
      )

    keep = Keyword.get(opts, :keep, false)
    version = Keyword.get(opts, :version, @default_version)

    ensure_docker!()

    # Start Weaviate
    Mix.shell().info("Starting Weaviate containers (version: #{version})...\n")
    start_weaviate(version)

    # Wait for Weaviate to be ready
    Mix.shell().info("\nWaiting for Weaviate to be ready...")
    wait_for_ready()

    # Run integration tests
    Mix.shell().info("\nRunning integration tests...\n")
    test_result = run_integration_tests()

    # Stop Weaviate unless --keep was specified
    if keep do
      Mix.shell().info("\nKeeping Weaviate containers running (--keep specified)")
    else
      Mix.shell().info("\nStopping Weaviate containers...")
      stop_weaviate()
    end

    # Exit with appropriate code based on test result
    case test_result do
      0 ->
        Mix.shell().info("\nIntegration tests passed!")

      exit_code ->
        Mix.raise("Integration tests failed (exit code: #{exit_code})")
    end
  end

  defp ensure_docker! do
    case System.cmd("docker", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> Mix.raise("Docker is not available. Please install Docker first.")
    end
  end

  defp start_weaviate(version) do
    script_path = script_path("start_weaviate.sh")

    unless File.exists?(script_path) do
      Mix.raise("Script not found: #{script_path}")
    end

    case System.cmd("bash", [script_path, version],
           cd: project_root(),
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        :ok

      {_, exit_code} ->
        Mix.raise("Failed to start Weaviate (exit code: #{exit_code})")
    end
  end

  defp wait_for_ready do
    # Ensure inets is started for HTTP requests
    :ok = Application.ensure_started(:inets)
    :ok = Application.ensure_started(:ssl)

    wait_for_ready(0)
  end

  defp wait_for_ready(waited) when waited > @max_wait_seconds do
    Mix.raise("Weaviate did not become ready within #{@max_wait_seconds} seconds")
  end

  defp wait_for_ready(waited) do
    url = ~c"http://localhost:#{@primary_port}/v1/.well-known/ready"

    case :httpc.request(:get, {url, []}, [timeout: @health_timeout], []) do
      {:ok, {{_, 200, _}, _, _}} ->
        Mix.shell().info("Weaviate is ready!")

      _ ->
        Mix.shell().info("Waiting... (#{waited}s)")
        Process.sleep(2000)
        wait_for_ready(waited + 2)
    end
  end

  defp run_integration_tests do
    env = [{"WEAVIATE_INTEGRATION", "true"}]

    case System.cmd("mix", ["test", "--only", "integration"],
           cd: project_root(),
           env: env,
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, exit_code} -> exit_code
    end
  end

  defp stop_weaviate do
    script_path = script_path("stop_weaviate.sh")

    unless File.exists?(script_path) do
      Mix.shell().info("Warning: Stop script not found at #{script_path}")
      return_value(:ok)
    end

    case System.cmd("bash", [script_path],
           cd: project_root(),
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        Mix.shell().info("Weaviate containers stopped")

      {_, exit_code} ->
        Mix.shell().info("Warning: Failed to stop Weaviate (exit code: #{exit_code})")
    end
  end

  defp return_value(value), do: value

  defp script_path(script), do: Path.join([project_root(), "ci", script])
  defp project_root, do: Path.expand("../../../..", __DIR__)
end
