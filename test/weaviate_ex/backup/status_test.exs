defmodule WeaviateEx.Backup.StatusTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Status

  describe "all/0" do
    test "returns all status values" do
      statuses = Status.all()

      assert length(statuses) == 6
      assert :started in statuses
      assert :transferring in statuses
      assert :transferred in statuses
      assert :success in statuses
      assert :failed in statuses
      assert :canceled in statuses
    end
  end

  describe "to_api/1" do
    test "converts started to STARTED" do
      assert Status.to_api(:started) == "STARTED"
    end

    test "converts transferring to TRANSFERRING" do
      assert Status.to_api(:transferring) == "TRANSFERRING"
    end

    test "converts transferred to TRANSFERRED" do
      assert Status.to_api(:transferred) == "TRANSFERRED"
    end

    test "converts success to SUCCESS" do
      assert Status.to_api(:success) == "SUCCESS"
    end

    test "converts failed to FAILED" do
      assert Status.to_api(:failed) == "FAILED"
    end

    test "converts canceled to CANCELED" do
      assert Status.to_api(:canceled) == "CANCELED"
    end
  end

  describe "from_api/1" do
    test "parses STARTED string" do
      assert Status.from_api("STARTED") == :started
    end

    test "parses TRANSFERRING string" do
      assert Status.from_api("TRANSFERRING") == :transferring
    end

    test "parses TRANSFERRED string" do
      assert Status.from_api("TRANSFERRED") == :transferred
    end

    test "parses SUCCESS string" do
      assert Status.from_api("SUCCESS") == :success
    end

    test "parses FAILED string" do
      assert Status.from_api("FAILED") == :failed
    end

    test "parses CANCELED string" do
      assert Status.from_api("CANCELED") == :canceled
    end
  end

  describe "completed?/1" do
    test "returns true for success" do
      assert Status.completed?(:success) == true
    end

    test "returns true for failed" do
      assert Status.completed?(:failed) == true
    end

    test "returns true for canceled" do
      assert Status.completed?(:canceled) == true
    end

    test "returns false for started" do
      assert Status.completed?(:started) == false
    end

    test "returns false for transferring" do
      assert Status.completed?(:transferring) == false
    end

    test "returns false for transferred" do
      assert Status.completed?(:transferred) == false
    end
  end

  describe "success?/1" do
    test "returns true only for success" do
      assert Status.success?(:success) == true
    end

    test "returns false for failed" do
      assert Status.success?(:failed) == false
    end

    test "returns false for canceled" do
      assert Status.success?(:canceled) == false
    end

    test "returns false for in-progress states" do
      assert Status.success?(:started) == false
      assert Status.success?(:transferring) == false
      assert Status.success?(:transferred) == false
    end
  end

  describe "in_progress?/1" do
    test "returns true for started" do
      assert Status.in_progress?(:started) == true
    end

    test "returns true for transferring" do
      assert Status.in_progress?(:transferring) == true
    end

    test "returns true for transferred" do
      assert Status.in_progress?(:transferred) == true
    end

    test "returns false for terminal states" do
      assert Status.in_progress?(:success) == false
      assert Status.in_progress?(:failed) == false
      assert Status.in_progress?(:canceled) == false
    end
  end

  describe "CreateResponse struct" do
    test "has expected fields" do
      response = %Status.CreateResponse{
        id: "backup-1",
        backend: :filesystem,
        status: :success,
        path: "/backups/backup-1",
        collections: ["Article", "Author"],
        error: nil
      }

      assert response.id == "backup-1"
      assert response.backend == :filesystem
      assert response.status == :success
      assert response.path == "/backups/backup-1"
      assert response.collections == ["Article", "Author"]
      assert response.error == nil
    end

    test "defaults error to nil" do
      response = %Status.CreateResponse{
        id: "test",
        backend: :s3,
        status: :started,
        path: nil,
        collections: []
      }

      assert response.error == nil
    end
  end

  describe "RestoreResponse struct" do
    test "has expected fields" do
      response = %Status.RestoreResponse{
        id: "backup-1",
        backend: :gcs,
        status: :success,
        path: "/backups/backup-1",
        collections: ["Article"],
        error: nil
      }

      assert response.id == "backup-1"
      assert response.backend == :gcs
      assert response.status == :success
      assert response.path == "/backups/backup-1"
      assert response.collections == ["Article"]
      assert response.error == nil
    end
  end

  describe "BackupInfo struct" do
    test "has expected fields" do
      info = %Status.BackupInfo{
        id: "backup-1",
        backend: :azure,
        status: :success,
        path: "/backups/backup-1",
        collections: ["Article", "Author"]
      }

      assert info.id == "backup-1"
      assert info.backend == :azure
      assert info.status == :success
      assert info.path == "/backups/backup-1"
      assert info.collections == ["Article", "Author"]
    end
  end

  describe "create_response_from_api/1" do
    test "parses full response" do
      api_response = %{
        "id" => "backup-123",
        "backend" => "s3",
        "status" => "SUCCESS",
        "path" => "/backups/backup-123",
        "classes" => ["Article", "Author"],
        "error" => nil
      }

      {:ok, response} = Status.create_response_from_api(api_response)

      assert response.id == "backup-123"
      assert response.backend == :s3
      assert response.status == :success
      assert response.path == "/backups/backup-123"
      assert response.collections == ["Article", "Author"]
      assert response.error == nil
    end

    test "handles error field" do
      api_response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "FAILED",
        "path" => nil,
        "classes" => ["Article"],
        "error" => "Backup failed: disk full"
      }

      {:ok, response} = Status.create_response_from_api(api_response)

      assert response.status == :failed
      assert response.error == "Backup failed: disk full"
    end

    test "handles missing optional fields" do
      api_response = %{
        "id" => "backup-123",
        "backend" => "filesystem",
        "status" => "STARTED"
      }

      {:ok, response} = Status.create_response_from_api(api_response)

      assert response.id == "backup-123"
      assert response.path == nil
      assert response.collections == []
      assert response.error == nil
    end
  end

  describe "restore_response_from_api/1" do
    test "parses full response" do
      api_response = %{
        "id" => "backup-123",
        "backend" => "gcs",
        "status" => "SUCCESS",
        "path" => "/backups/backup-123",
        "classes" => ["Article"],
        "error" => nil
      }

      {:ok, response} = Status.restore_response_from_api(api_response)

      assert response.id == "backup-123"
      assert response.backend == :gcs
      assert response.status == :success
      assert response.collections == ["Article"]
    end
  end

  describe "backup_info_from_api/1" do
    test "parses backup metadata" do
      api_response = %{
        "id" => "backup-123",
        "backend" => "azure",
        "status" => "SUCCESS",
        "path" => "/backups/backup-123",
        "classes" => ["Article", "Author"]
      }

      {:ok, info} = Status.backup_info_from_api(api_response)

      assert info.id == "backup-123"
      assert info.backend == :azure
      assert info.status == :success
      assert info.path == "/backups/backup-123"
      assert info.collections == ["Article", "Author"]
    end
  end
end
