defmodule WeaviateEx.Embedded do
  @moduledoc """
  Manage a local, embedded Weaviate instance by downloading the official binary,
  mirroring the behaviour of the Python client's `connect_to_embedded`.

  This module downloads the requested Weaviate release (once), keeps it in a
  cache directory, spawns the binary with sensible defaults, waits for both HTTP
  and gRPC listeners to become ready, and provides a handle that can be stopped
  when the caller is done.
  """

  alias __MODULE__.Instance

  @default_version "1.30.5"
  @ready_timeout 30_000
  @http_ready_path "/v1/.well-known/ready"

  defmodule Instance do
    @moduledoc "Opaque handle returned by `start/1`."
    @enforce_keys [:options, :executable, :process_port, :os_pid]
    defstruct [:options, :executable, :process_port, :os_pid]
  end

  @typedoc "Options that control the embedded instance lifecycle."
  @type option ::
          {:version, String.t()}
          | {:hostname, String.t()}
          | {:port, non_neg_integer()}
          | {:grpc_port, non_neg_integer()}
          | {:binary_path, String.t()}
          | {:persistence_data_path, String.t()}
          | {:environment_variables, map()}
          | {:ready_timeout, non_neg_integer()}

  @doc """
  Starts an embedded Weaviate process.

  Returns an `%Instance{}` handle that must be stopped with `stop/1` to clean
  up the spawned OS process.
  """
  @spec start([option()]) :: {:ok, Instance.t()} | {:error, term()}
  def start(opts \\ []) do
    with {:ok, options} <- build_options(opts),
         :ok <- ensure_supported_platform(),
         :ok <- ensure_directories(options),
         {:ok, executable, parsed_version} <- ensure_binary(options),
         env <- build_environment(options, parsed_version),
         {:ok, process_port} <- spawn_instance(executable, env, options),
         :ok <-
           wait_until_ready(
             options.hostname,
             options.port,
             options.grpc_port,
             options.ready_timeout
           ) do
      os_pid =
        case Port.info(process_port, :os_pid) do
          {:os_pid, pid} -> pid
          _ -> nil
        end

      instance = %Instance{
        options: options,
        executable: executable,
        process_port: process_port,
        os_pid: os_pid
      }

      {:ok, instance}
    end
  end

  @doc """
  Stops the embedded instance represented by `instance`.
  """
  @spec stop(Instance.t()) :: :ok
  def stop(%Instance{process_port: port}) do
    Port.close(port)
    :ok
  end

  defp build_options(opts) do
    {:ok,
     %{
       version: Keyword.get(opts, :version, @default_version),
       hostname: Keyword.get(opts, :hostname, "127.0.0.1"),
       port: Keyword.get(opts, :port, 8079),
       grpc_port: Keyword.get(opts, :grpc_port, 50060),
       binary_path: Keyword.get(opts, :binary_path, default_binary_path()),
       persistence_data_path:
         Keyword.get(opts, :persistence_data_path, default_persistence_path()),
       environment_variables: Keyword.get(opts, :environment_variables, %{}),
       ready_timeout: Keyword.get(opts, :ready_timeout, @ready_timeout)
     }}
  end

  defp ensure_directories(%{binary_path: binary_path, persistence_data_path: data_path}) do
    with :ok <- File.mkdir_p(binary_path),
         :ok <- File.mkdir_p(data_path) do
      :ok
    end
  end

  defp ensure_supported_platform do
    case :os.type() do
      {:unix, :darwin} -> :ok
      {:unix, :linux} -> :ok
      {:unix, _} -> :ok
      {:win32, _} -> {:error, "Embedded Weaviate is not supported on Windows"}
      other -> {:error, "Unsupported platform #{inspect(other)}"}
    end
  end

  defp ensure_binary(options) do
    {:ok, parsed_version, download_url} = resolve_version(options.version)
    binary_name = hashed_binary_name(parsed_version)
    binary_path = Path.join(options.binary_path, binary_name)

    if File.exists?(binary_path) do
      {:ok, binary_path, parsed_version}
    else
      download_and_extract(download_url, binary_path, options)
    end
  end

  defp resolve_version("latest") do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    url = ~c"https://api.github.com/repos/weaviate/weaviate/releases/latest"
    headers = [{~c"User-Agent", ~c"weaviate_ex"}]

    case :httpc.request(:get, {url, headers}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        with {:ok, decoded} <- Jason.decode(body),
             %{"tag_name" => tag} <- decoded do
          {:ok, tag, download_url(tag)}
        else
          _ -> {:error, "Failed to parse latest release information"}
        end

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, "Failed to query GitHub releases (status #{status}): #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_version(version) when is_binary(version) do
    cond do
      String.starts_with?(version, "http") ->
        {:ok, version_tag_from_url(version), version}

      String.starts_with?(version, "v") ->
        {:ok, version, download_url(version)}

      Regex.match?(~r/^\d\.\d{1,2}\.\d{1,2}([\-\.].*)?$/, version) ->
        tag = "v" <> version
        {:ok, tag, download_url(tag)}

      true ->
        {:error, "Unsupported version format: #{version}"}
    end
  end

  defp download_url(version_tag) do
    {os_name, package_format, machine_type} = platform_package_details()

    "https://github.com/weaviate/weaviate/releases/download/#{version_tag}/weaviate-#{version_tag}-#{os_name}-#{machine_type}.#{package_format}"
  end

  defp platform_package_details do
    case :os.type() do
      {:unix, :darwin} ->
        {"Darwin", "zip", "all"}

      _ ->
        arch_string = to_string(:erlang.system_info(:system_architecture))

        arch =
          cond do
            String.contains?(arch_string, "x86_64") -> "amd64"
            String.contains?(arch_string, "aarch64") -> "arm64"
            true -> raise "Unsupported architecture #{arch_string}"
          end

        {"Linux", "tar.gz", arch}
    end
  end

  defp version_tag_from_url(url) do
    url
    |> String.trim()
    |> String.replace_prefix("https://github.com/weaviate/weaviate/releases/download/", "")
    |> String.split("/", parts: 2)
    |> List.first()
  end

  defp download_and_extract(url, final_path, %{binary_path: binary_dir}) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    tmp_file =
      case Path.extname(url) do
        ".zip" -> Path.join(binary_dir, "tmp_weaviate.zip")
        ".gz" -> Path.join(binary_dir, "tmp_weaviate.tgz")
        other -> raise "Unsupported package extension #{other}"
      end

    headers = [{~c"User-Agent", ~c"weaviate_ex"}]

    case :httpc.request(:get, {String.to_charlist(url), headers}, [],
           stream: String.to_charlist(tmp_file)
         ) do
      {:ok, _} ->
        extract_archive(tmp_file, binary_dir)
        File.rename!(Path.join(binary_dir, "weaviate"), final_path)
        File.chmod!(final_path, 0o755)
        File.rm!(tmp_file)
        {:ok, final_path, version_tag_from_url(url)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_archive(tmp_file, binary_dir) do
    case Path.extname(tmp_file) do
      ".zip" ->
        :zip.extract(String.to_charlist(tmp_file), cwd: String.to_charlist(binary_dir))

      ".tgz" ->
        :erl_tar.extract(String.to_charlist(tmp_file), [
          :compressed,
          cwd: String.to_charlist(binary_dir)
        ])

      other ->
        raise "Unsupported archive format #{other}"
    end
  end

  defp build_environment(options, parsed_version) do
    hostname = "Embedded_at_#{options.port}"
    gossip_port = random_port()
    data_port = gossip_port + 1
    raft_port = data_port + 1
    raft_internal_rpc_port = raft_port + 1

    defaults = %{
      "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED" => "true",
      "QUERY_DEFAULTS_LIMIT" => "20",
      "PERSISTENCE_DATA_PATH" => options.persistence_data_path,
      "PROFILING_PORT" => Integer.to_string(random_port()),
      "CLUSTER_GOSSIP_BIND_PORT" => Integer.to_string(gossip_port),
      "CLUSTER_DATA_BIND_PORT" => Integer.to_string(data_port),
      "GRPC_PORT" => Integer.to_string(options.grpc_port),
      "RAFT_BOOTSTRAP_EXPECT" => "1",
      "CLUSTER_IN_LOCALHOST" => "true",
      "RAFT_PORT" => Integer.to_string(raft_port),
      "RAFT_INTERNAL_RPC_PORT" => Integer.to_string(raft_internal_rpc_port),
      "ENABLE_MODULES" =>
        "text2vec-openai,text2vec-cohere,text2vec-huggingface,ref2vec-centroid,generative-openai,qna-openai,reranker-cohere",
      "CLUSTER_HOSTNAME" => hostname,
      "RAFT_JOIN" => "#{hostname}:#{raft_port}",
      "WEAVIATE_EMBEDDED_VERSION" => parsed_version
    }

    Map.merge(defaults, Map.new(options.environment_variables))
  end

  defp spawn_instance(executable, env, options) do
    args = [
      "--host",
      options.hostname,
      "--port",
      Integer.to_string(options.port),
      "--scheme",
      "http",
      "--read-timeout=600s",
      "--write-timeout=600s"
    ]

    env_list =
      env
      |> Enum.map(fn {key, value} ->
        {String.to_charlist(to_string(key)), String.to_charlist(to_string(value))}
      end)

    port =
      Port.open({:spawn_executable, String.to_charlist(executable)}, [
        :binary,
        :exit_status,
        {:env, env_list},
        {:args, Enum.map(args, &String.to_charlist/1)}
      ])

    {:ok, port}
  end

  defp wait_until_ready(host, port, grpc_port, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    with :ok <- wait_http_ready(host, port, deadline),
         :ok <- wait_tcp_ready(host, grpc_port, deadline) do
      :ok
    end
  end

  defp wait_http_ready(host, port, deadline) do
    url = "http://#{host}:#{port}#{@http_ready_path}"

    case http_get(url) do
      {:ok, 200} ->
        :ok

      _ ->
        if System.monotonic_time(:millisecond) > deadline do
          {:error, "Embedded Weaviate did not become ready on #{url}"}
        else
          Process.sleep(500)
          wait_http_ready(host, port, deadline)
        end
    end
  end

  defp wait_tcp_ready(host, port, deadline) do
    case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 1_000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      _ ->
        if System.monotonic_time(:millisecond) > deadline do
          {:error, "Embedded Weaviate gRPC port #{port} did not become ready"}
        else
          Process.sleep(500)
          wait_tcp_ready(host, port, deadline)
        end
    end
  end

  defp http_get(url) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    case :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary) do
      {:ok, {{_, status, _}, _headers, _body}} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  end

  defp hashed_binary_name(parsed_version) do
    hash =
      parsed_version
      |> :crypto.hash(:sha256)
      |> Base.encode16(case: :lower)

    "weaviate-#{parsed_version}-#{hash}"
  end

  defp random_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, {:packet, 0}, {:active, false}])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp default_binary_path do
    case System.get_env("XDG_CACHE_HOME") do
      nil -> Path.join(System.user_home!(), ".cache/weaviate-embedded")
      cache -> Path.join(cache, "weaviate-embedded")
    end
  end

  defp default_persistence_path do
    case System.get_env("XDG_DATA_HOME") do
      nil -> Path.join(System.user_home!(), ".local/share/weaviate")
      data -> Path.join(data, "weaviate")
    end
  end
end
