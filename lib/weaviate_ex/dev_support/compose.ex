defmodule WeaviateEx.DevSupport.Compose do
  @moduledoc false

  @project_root Path.expand("../../..", __DIR__)
  @compose_dir_rel "ci/weaviate"
  @compose_dir Path.join(@project_root, @compose_dir_rel)

  def project_root, do: @project_root
  def compose_dir, do: @compose_dir
  def compose_dir_rel, do: @compose_dir_rel

  def ensure_compose_dir! do
    unless File.dir?(@compose_dir) do
      raise """
      Could not find #{@compose_dir_rel} directory.

      Expected Docker assets copied from the Python client under #{Path.relative_to_cwd(@compose_dir)}.
      """
    end
  end

  def run_script(script_name, args \\ [], opts \\ []) do
    ensure_compose_dir!()

    script_path = Path.join(@compose_dir, script_name)

    unless File.exists?(script_path) do
      raise "Expected script #{Path.relative_to_cwd(script_path)} to exist"
    end

    args =
      args
      |> List.wrap()
      |> Enum.map(&quote_arg/1)
      |> Enum.join(" ")

    command =
      if args == "" do
        "#{quote_path(script_path)}"
      else
        "#{quote_path(script_path)} #{args}"
      end

    cmd_opts = Keyword.merge([stderr_to_stdout: true], opts)
    System.cmd("bash", ["-lc", "cd #{quote_path(@project_root)} && #{command}"], cmd_opts)
  end

  def exec_all(args, opts \\ []) when is_list(args) do
    ensure_compose_dir!()

    command = """
    set -euo pipefail
    cd #{quote_path(@project_root)}
    for file in $(ls #{@compose_dir_rel} | grep 'docker-compose'); do
      docker compose -f #{@compose_dir_rel}/${file} #{Enum.map_join(args, " ", &quote_string/1)}
    done
    """

    cmd_opts = Keyword.merge([stderr_to_stdout: true], opts)
    System.cmd("bash", ["-lc", command], cmd_opts)
  end

  def exec_for_file(file, args, opts \\ []) do
    ensure_compose_dir!()

    compose_file = Path.join(@compose_dir_rel, file)

    command = """
    set -euo pipefail
    cd #{quote_path(@project_root)}
    docker compose -f #{compose_file} #{Enum.map_join(args, " ", &quote_string/1)}
    """

    cmd_opts = Keyword.merge([stderr_to_stdout: true], opts)
    System.cmd("bash", ["-lc", command], cmd_opts)
  end

  def compose_files do
    ensure_compose_dir!()

    @compose_dir
    |> Path.join("docker-compose*.yml")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&Path.basename/1)
  end

  def all_ports do
    ensure_compose_dir!()

    command = """
    set -euo pipefail
    cd #{quote_path(@project_root)}
    source #{@compose_dir_rel}/compose.sh
    all_weaviate_ports
    """

    case System.cmd("bash", ["-lc", command], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split(~r/[\s\n]+/, trim: true)

      {output, exit_code} ->
        raise "Failed to read ports from compose.sh (exit #{exit_code}): #{output}"
    end
  end

  defp quote_path(path), do: quote_string(path)

  defp quote_arg(arg) do
    arg
    |> to_string()
    |> quote_string()
  end

  defp quote_string(str) do
    escaped =
      str
      |> to_string()
      |> String.replace("'", "'\"'\"'")

    "'#{escaped}'"
  end
end
