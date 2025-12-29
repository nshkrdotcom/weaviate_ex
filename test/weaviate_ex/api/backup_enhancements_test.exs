defmodule WeaviateEx.API.BackupEnhancementsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Backup
  alias WeaviateEx.Backup.Config
  alias WeaviateEx.Backup.Location

  # Mock protocol implementation for testing
  defmodule MockProtocol do
    def request(_client, method, path, body, _opts) do
      case Process.get(:mock_responses) do
        [response | rest] ->
          Process.put(:mock_responses, rest)

          Process.put(:recorded_requests, [
            {method, path, body} | Process.get(:recorded_requests, [])
          ])

          response

        [] ->
          {:error, :no_response}
      end
    end
  end

  defp mock_client(responses) do
    Process.put(:mock_responses, responses)
    Process.put(:recorded_requests, [])

    %WeaviateEx.Client{
      config: %WeaviateEx.Client.Config{
        base_url: "http://localhost:8080",
        api_key: nil,
        grpc_host: "localhost",
        grpc_port: 50_051,
        grpc_max_message_size: 104_857_600
      },
      grpc_channel: nil,
      protocol_impl: MockProtocol
    }
  end

  defp get_requests do
    Enum.reverse(Process.get(:recorded_requests, []))
  end

  describe "restore/4 with RBAC options" do
    test "restores backup with roles_restore option" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} = Backup.restore(client, "backup-123", :filesystem, roles_restore: :all)

      [{:post, _path, body}] = get_requests()
      assert body["rolesRestore"] == "all"
    end

    test "restores backup with specific roles" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.restore(client, "backup-123", :filesystem, roles_restore: ["admin", "editor"])

      [{:post, _path, body}] = get_requests()
      assert body["rolesRestore"] == ["admin", "editor"]
    end

    test "restores backup with users_restore option" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} = Backup.restore(client, "backup-123", :filesystem, users_restore: :none)

      [{:post, _path, body}] = get_requests()
      assert body["usersRestore"] == "none"
    end

    test "restores backup with overwrite_alias option" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} = Backup.restore(client, "backup-123", :filesystem, overwrite_alias: true)

      [{:post, _path, body}] = get_requests()
      assert body["overwriteAlias"] == true
    end

    test "restores backup with all RBAC options combined" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.restore(client, "backup-123", :s3,
          roles_restore: :all,
          users_restore: ["admin@example.com"],
          overwrite_alias: true,
          include_collections: ["Article"]
        )

      [{:post, _path, body}] = get_requests()
      assert body["rolesRestore"] == "all"
      assert body["usersRestore"] == ["admin@example.com"]
      assert body["overwriteAlias"] == true
      assert body["include"] == ["Article"]
    end
  end

  describe "Config with extended options" do
    test "creates config with chunk_size" do
      config =
        Config.Create.new(
          cpu_percentage: 50,
          chunk_size: 134_217_728,
          compression: :best_compression
        )

      assert config.cpu_percentage == 50
      assert config.chunk_size == 134_217_728
      assert config.compression == :best_compression
    end

    test "config to_api includes chunk_size" do
      config =
        Config.Create.new(
          cpu_percentage: 75,
          chunk_size: 268_435_456
        )

      api_map = Config.Create.to_api(config)

      assert api_map[:CPUPercentage] == 75
      assert api_map[:ChunkSize] == 268_435_456
    end

    test "config defaults are applied" do
      config = Config.Create.new()

      assert config.cpu_percentage == nil
      assert config.chunk_size == nil
      assert config.compression == nil
    end
  end

  describe "create/4 with dynamic Location" do
    test "creates backup with Location.filesystem struct" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      location = Location.filesystem("/var/backups")

      {:ok, _} = Backup.create(client, "backup-123", location)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/filesystem"
      assert body["config"][:path] == "/var/backups"
    end

    test "creates backup with Location.s3 struct" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      location = Location.s3("my-bucket", "/backups", region: "us-west-2")

      {:ok, _} = Backup.create(client, "backup-123", location)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/s3"
      assert body["config"][:bucket] == "my-bucket"
      assert body["config"][:path] == "/backups"
      assert body["config"][:region] == "us-west-2"
    end

    test "creates backup with Location.gcs struct" do
      response = %{
        "id" => "backup-123",
        "backend" => "gcs",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      location = Location.gcs("my-bucket", "/backups", project_id: "my-project")

      {:ok, _} = Backup.create(client, "backup-123", location)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/gcs"
      assert body["config"][:bucket] == "my-bucket"
      assert body["config"][:projectId] == "my-project"
    end

    test "creates backup with Location.azure struct" do
      response = %{
        "id" => "backup-123",
        "backend" => "azure",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      location = Location.azure("my-container", "/backups")

      {:ok, _} = Backup.create(client, "backup-123", location)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/azure"
      assert body["config"][:container] == "my-container"
      assert body["config"][:path] == "/backups"
    end

    test "creates backup with atom backend (backwards compatible)" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])

      {:ok, _} = Backup.create(client, "backup-123", :filesystem)

      [{:post, path, _body}] = get_requests()
      assert path == "/v1/backups/filesystem"
    end
  end

  describe "restore/4 with dynamic Location" do
    test "restores backup with Location.s3 struct" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])
      location = Location.s3("my-bucket", "/backups", region: "eu-west-1")

      {:ok, _} = Backup.restore(client, "backup-123", location)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/s3/backup-123/restore"
      assert body["config"][:bucket] == "my-bucket"
      assert body["config"][:region] == "eu-west-1"
    end
  end

  describe "create/4 with config and location combined" do
    test "creates backup with Location and Config" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      location = Location.s3("my-bucket", "/backups")
      config = Config.Create.new(cpu_percentage: 75, compression: :best_speed)

      {:ok, _} = Backup.create(client, "backup-123", location, config: config)

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/s3"
      # Location config should be merged with backup config
      assert body["config"][:bucket] == "my-bucket"
      assert body["config"][:CPUPercentage] == 75
      assert body["config"][:CompressionLevel] == "BestSpeed"
    end
  end
end
