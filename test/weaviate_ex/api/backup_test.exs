defmodule WeaviateEx.API.BackupTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Backup
  alias WeaviateEx.Backup.{Config, Status, Storage}

  # Mock protocol implementation for testing
  defmodule MockProtocol do
    def request(_client, method, path, body, _opts) do
      # Get response from process dictionary
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

  describe "create/4" do
    test "creates backup with minimal options" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "path" => "/backups/backup-123",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      {:ok, result} = Backup.create(client, "backup-123", :filesystem)

      assert result.id == "backup-123"
      assert result.backend == :filesystem
      assert result.status == :started

      [{:post, path, body}] = get_requests()
      assert path == "/v1/backups/filesystem"
      assert body["id"] == "backup-123"
    end

    test "creates backup with include_collections" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => ["Article", "Author"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.create(client, "backup-123", :s3, include_collections: ["Article", "Author"])

      [{:post, _path, body}] = get_requests()
      assert body["include"] == ["Article", "Author"]
    end

    test "creates backup with exclude_collections" do
      response = %{
        "id" => "backup-123",
        "backend" => "gcs",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.create(client, "backup-123", :gcs, exclude_collections: ["Logs"])

      [{:post, _path, body}] = get_requests()
      assert body["exclude"] == ["Logs"]
    end

    test "creates backup with config" do
      response = %{
        "id" => "backup-123",
        "backend" => "azure",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      config = Config.create(cpu_percentage: 50, compression: :best_compression)

      {:ok, _} = Backup.create(client, "backup-123", :azure, config: config)

      [{:post, _path, body}] = get_requests()
      assert body["config"][:CPUPercentage] == 50
      assert body["config"][:CompressionLevel] == "BestCompression"
    end

    test "returns error for invalid backend" do
      client = mock_client([])

      {:error, error} = Backup.create(client, "backup-123", :invalid)

      assert error.type == :bad_request
      assert error.message =~ "Invalid backup backend"
    end

    test "returns error when backup already exists" do
      error_response = %{
        "message" => "backup already exists"
      }

      client = mock_client([{:error, WeaviateEx.Error.from_status_code(409, error_response)}])

      {:error, error} = Backup.create(client, "backup-123", :filesystem)

      assert error.type == :conflict
    end
  end

  describe "get_create_status/3" do
    test "returns status for existing backup" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "SUCCESS",
        "path" => "/backups/backup-123",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, result} = Backup.get_create_status(client, "backup-123", :filesystem)

      assert result.id == "backup-123"
      assert result.status == :success
      assert result.collections == ["Article"]

      [{:get, path, _}] = get_requests()
      assert path == "/v1/backups/filesystem/backup-123"
    end

    test "returns error for non-existent backup" do
      error_response = %{"message" => "backup not found"}
      client = mock_client([{:error, WeaviateEx.Error.from_status_code(404, error_response)}])

      {:error, error} = Backup.get_create_status(client, "nonexistent", :filesystem)

      assert error.type == :not_found
    end

    test "returns correct status enum values" do
      statuses = ["STARTED", "TRANSFERRING", "TRANSFERRED", "SUCCESS", "FAILED", "CANCELED"]

      Enum.each(statuses, fn status_str ->
        response = %{
          "id" => "backup-123",
          "backend" => "filesystem",
          "status" => status_str,
          "classes" => []
        }

        client = mock_client([{:ok, response}])
        {:ok, result} = Backup.get_create_status(client, "backup-123", :filesystem)

        expected = Status.from_api(status_str)
        assert result.status == expected
      end)
    end
  end

  describe "restore/4" do
    test "restores backup with minimal options" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED",
        "path" => "/backups/backup-123",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, result} = Backup.restore(client, "backup-123", :filesystem)

      assert result.id == "backup-123"
      assert result.status == :started

      [{:post, path, _body}] = get_requests()
      assert path == "/v1/backups/filesystem/backup-123/restore"
    end

    test "restores backup with include_collections" do
      response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "STARTED",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.restore(client, "backup-123", :s3, include_collections: ["Article"])

      [{:post, _path, body}] = get_requests()
      assert body["include"] == ["Article"]
    end

    test "restores backup with exclude_collections" do
      response = %{
        "id" => "backup-123",
        "backend" => "gcs",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])

      {:ok, _} =
        Backup.restore(client, "backup-123", :gcs, exclude_collections: ["Logs"])

      [{:post, _path, body}] = get_requests()
      assert body["exclude"] == ["Logs"]
    end

    test "restores backup with config" do
      response = %{
        "id" => "backup-123",
        "backend" => "azure",
        "status" => "STARTED",
        "classes" => []
      }

      client = mock_client([{:ok, response}])
      config = Config.restore(cpu_percentage: 80)

      {:ok, _} = Backup.restore(client, "backup-123", :azure, config: config)

      [{:post, _path, body}] = get_requests()
      assert body["config"][:CPUPercentage] == 80
    end

    test "returns error for non-existent backup" do
      error_response = %{"message" => "backup not found"}
      client = mock_client([{:error, WeaviateEx.Error.from_status_code(404, error_response)}])

      {:error, error} = Backup.restore(client, "nonexistent", :filesystem)

      assert error.type == :not_found
    end
  end

  describe "get_restore_status/3" do
    test "returns status for active restore" do
      response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "TRANSFERRING",
        "path" => "/backups/backup-123",
        "classes" => ["Article"]
      }

      client = mock_client([{:ok, response}])

      {:ok, result} = Backup.get_restore_status(client, "backup-123", :filesystem)

      assert result.id == "backup-123"
      assert result.status == :transferring

      [{:get, path, _}] = get_requests()
      assert path == "/v1/backups/filesystem/backup-123/restore"
    end

    test "returns error when no restore in progress" do
      error_response = %{"message" => "no restore in progress"}
      client = mock_client([{:error, WeaviateEx.Error.from_status_code(404, error_response)}])

      {:error, error} = Backup.get_restore_status(client, "backup-123", :filesystem)

      assert error.type == :not_found
    end
  end

  describe "list/2" do
    test "returns empty list when no backups" do
      client = mock_client([{:ok, []}])

      {:ok, backups} = Backup.list(client, :filesystem)

      assert backups == []

      [{:get, path, _}] = get_requests()
      assert path == "/v1/backups/filesystem"
    end

    test "returns list of BackupInfo structs" do
      response = [
        %{
          "id" => "backup-1",
          "backend" => "filesystem",
          "status" => "SUCCESS",
          "path" => "/backups/backup-1",
          "classes" => ["Article"]
        },
        %{
          "id" => "backup-2",
          "backend" => "filesystem",
          "status" => "SUCCESS",
          "path" => "/backups/backup-2",
          "classes" => ["Author"]
        }
      ]

      client = mock_client([{:ok, response}])

      {:ok, backups} = Backup.list(client, :filesystem)

      assert length(backups) == 2
      assert Enum.at(backups, 0).id == "backup-1"
      assert Enum.at(backups, 1).id == "backup-2"
    end

    test "lists backups for each backend correctly" do
      backends = [:filesystem, :s3, :gcs, :azure]

      Enum.each(backends, fn backend ->
        response = [
          %{
            "id" => "backup-1",
            "backend" => Storage.to_api_path(backend),
            "status" => "SUCCESS",
            "path" => "/backups/backup-1",
            "classes" => []
          }
        ]

        client = mock_client([{:ok, response}])
        {:ok, backups} = Backup.list(client, backend)

        assert length(backups) == 1
        assert hd(backups).backend == backend

        [{:get, path, _}] = get_requests()
        assert path == "/v1/backups/#{Storage.to_api_path(backend)}"
      end)
    end
  end

  describe "cancel/3" do
    test "cancels in-progress backup" do
      client = mock_client([{:ok, %{}}])

      :ok = Backup.cancel(client, "backup-123", :filesystem)

      [{:delete, path, _}] = get_requests()
      assert path == "/v1/backups/filesystem/backup-123"
    end

    test "returns error for completed backup" do
      error_response = %{"message" => "cannot cancel completed backup"}
      client = mock_client([{:error, WeaviateEx.Error.from_status_code(422, error_response)}])

      {:error, error} = Backup.cancel(client, "backup-123", :filesystem)

      assert error.type == :validation_error
    end

    test "returns error for non-existent backup" do
      error_response = %{"message" => "backup not found"}
      client = mock_client([{:error, WeaviateEx.Error.from_status_code(404, error_response)}])

      {:error, error} = Backup.cancel(client, "nonexistent", :filesystem)

      assert error.type == :not_found
    end
  end

  describe "build_create_body/2" do
    test "builds body with all options" do
      config = Config.create(cpu_percentage: 50, compression: :best_speed)

      body =
        Backup.build_create_body("backup-123",
          include_collections: ["Article"],
          exclude_collections: ["Logs"],
          config: config
        )

      assert body["id"] == "backup-123"
      assert body["include"] == ["Article"]
      assert body["exclude"] == ["Logs"]
      assert body["config"][:CPUPercentage] == 50
      assert body["config"][:CompressionLevel] == "BestSpeed"
    end

    test "builds minimal body" do
      body = Backup.build_create_body("backup-123", [])

      assert body["id"] == "backup-123"
      refute Map.has_key?(body, "include")
      refute Map.has_key?(body, "exclude")
      refute Map.has_key?(body, "config")
    end
  end

  describe "build_restore_body/1" do
    test "builds body with all options" do
      config = Config.restore(cpu_percentage: 80)

      body =
        Backup.build_restore_body(
          include_collections: ["Article"],
          exclude_collections: ["Logs"],
          config: config
        )

      assert body["include"] == ["Article"]
      assert body["exclude"] == ["Logs"]
      assert body["config"][:CPUPercentage] == 80
    end

    test "returns empty map for minimal options" do
      body = Backup.build_restore_body([])

      assert body == %{}
    end
  end
end
