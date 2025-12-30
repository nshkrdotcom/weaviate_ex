defmodule WeaviateEx.Integration.BackupTest do
  @moduledoc """
  Integration tests for WeaviateEx backup and restore operations.

  These tests require a backup-enabled Weaviate instance running on port 8093.
  Use ci/docker-compose-backup.yml to start the required container.

  Run with: mix test test/integration/backup_integration_test.exs --include backup
  """
  use ExUnit.Case, async: false

  alias WeaviateEx.API.{Backup, Collections}
  alias WeaviateEx.Client

  @moduletag :integration
  @moduletag :backup

  @backup_url "http://localhost:8093"
  @admin_api_key "admin-key"

  setup_all do
    # Ensure we use HTTP protocol for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, @backup_url)

    # Create admin client for setup
    {:ok, client} =
      Client.new(
        base_url: @backup_url,
        api_key: @admin_api_key
      )

    # Clean up any leftover test collections
    cleanup_collections(client)

    on_exit(fn ->
      # Final cleanup
      {:ok, cleanup_client} =
        Client.new(
          base_url: @backup_url,
          api_key: @admin_api_key
        )

      cleanup_collections(cleanup_client)
    end)

    {:ok, client: client}
  end

  defp cleanup_collections(client) do
    with {:ok, collections} when is_list(collections) <- Collections.list(client) do
      collections
      |> Enum.filter(&String.starts_with?(&1, "BackupTest"))
      |> Enum.each(&Collections.delete(client, &1))
    end

    :ok
  end

  describe "Backup.create/3" do
    test "creates a backup to filesystem", %{client: client} do
      # Create a test collection with data
      collection_name = "BackupTestCreate#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]},
            %{"name" => "content", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      # Create backup
      backup_id = "backup-create-test-#{System.system_time(:millisecond)}"

      result =
        Backup.create(client, backup_id, :filesystem, include_collections: [collection_name])

      assert {:ok, status} = result
      assert is_map(status)
      # Status should have relevant fields
      assert Map.has_key?(status, :id) or Map.has_key?(status, :status)

      # Cleanup
      Collections.delete(client, collection_name)
    end

    test "creates a backup with wait_for_completion", %{client: client} do
      # Create a test collection
      collection_name = "BackupTestWait#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      backup_id = "backup-wait-test-#{System.system_time(:millisecond)}"

      result =
        Backup.create(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true,
          timeout: 60_000
        )

      assert {:ok, status} = result
      assert status.status in [:success, :started, :transferring]

      # Cleanup
      Collections.delete(client, collection_name)
    end
  end

  describe "Backup.get_create_status/3" do
    test "gets backup status", %{client: client} do
      # Create a test collection and backup
      collection_name = "BackupTestStatus#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      backup_id = "backup-status-test-#{System.system_time(:millisecond)}"

      # Create backup first
      {:ok, _} =
        Backup.create(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true
        )

      # Get status
      result = Backup.get_create_status(client, backup_id, :filesystem)

      assert {:ok, status} = result
      assert is_map(status)
      assert status.status in [:success, :started, :transferring, :failed]

      # Cleanup
      Collections.delete(client, collection_name)
    end
  end

  describe "Backup.list/2" do
    test "lists backups for filesystem backend", %{client: client} do
      result = Backup.list(client, :filesystem)

      assert {:ok, backups} = result
      assert is_list(backups)
    end
  end

  describe "full backup and restore cycle" do
    test "creates backup, deletes collection, restores, and verifies data", %{client: client} do
      # Step 1: Create a test collection with data
      collection_name = "BackupTestCycle#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "title", "dataType" => ["text"]},
            %{"name" => "content", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      # Add test objects using Objects API
      objects_path = "/v1/objects"

      {:ok, object1} =
        Client.request(
          client,
          :post,
          objects_path,
          %{
            "class" => collection_name,
            "properties" => %{
              "title" => "Test Article 1",
              "content" => "Content for article 1"
            }
          },
          []
        )

      {:ok, object2} =
        Client.request(
          client,
          :post,
          objects_path,
          %{
            "class" => collection_name,
            "properties" => %{
              "title" => "Test Article 2",
              "content" => "Content for article 2"
            }
          },
          []
        )

      object1_id = object1["id"]
      object2_id = object2["id"]

      # Step 2: Create backup
      backup_id = "backup-cycle-#{System.system_time(:millisecond)}"

      {:ok, _backup_status} =
        Backup.create(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true,
          timeout: 60_000
        )

      # Verify backup completed
      {:ok, status} = Backup.get_create_status(client, backup_id, :filesystem)
      assert status.status == :success

      # Step 3: Delete the collection
      {:ok, _} = Collections.delete(client, collection_name)

      # Verify collection is deleted
      assert {:error, _} = Collections.get(client, collection_name)

      # Step 4: Restore the backup
      {:ok, _restore_status} =
        Backup.restore(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true,
          timeout: 60_000
        )

      # Step 5: Verify the collection is restored
      {:ok, restored_collection} = Collections.get(client, collection_name)
      assert restored_collection["class"] == collection_name

      # Verify objects are restored
      {:ok, restored_obj1} =
        Client.request(client, :get, "/v1/objects/#{collection_name}/#{object1_id}", nil, [])

      {:ok, restored_obj2} =
        Client.request(client, :get, "/v1/objects/#{collection_name}/#{object2_id}", nil, [])

      assert restored_obj1["properties"]["title"] == "Test Article 1"
      assert restored_obj2["properties"]["title"] == "Test Article 2"

      # Cleanup
      Collections.delete(client, collection_name)
    end
  end

  describe "Backup.restore/3" do
    test "restores a backup from filesystem", %{client: client} do
      # First create a collection and backup
      collection_name = "BackupTestRestore#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "name", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      backup_id = "backup-restore-test-#{System.system_time(:millisecond)}"

      # Create backup
      {:ok, _} =
        Backup.create(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true
        )

      # Delete collection
      {:ok, _} = Collections.delete(client, collection_name)

      # Restore
      result =
        Backup.restore(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true
        )

      assert {:ok, restore_status} = result
      assert restore_status.status in [:success, :started, :transferring]

      # Verify restoration
      {:ok, collection} = Collections.get(client, collection_name)
      assert collection["class"] == collection_name

      # Cleanup
      Collections.delete(client, collection_name)
    end
  end

  describe "Backup.get_restore_status/3" do
    test "gets restore status after a restore operation", %{client: client} do
      # Create collection and backup
      collection_name = "BackupTestRestoreStatus#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(client, %{
          "class" => collection_name,
          "properties" => [
            %{"name" => "field", "dataType" => ["text"]}
          ],
          "vectorizer" => "none"
        })

      backup_id = "backup-restore-status-#{System.system_time(:millisecond)}"

      {:ok, _} =
        Backup.create(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true
        )

      # Delete and restore
      {:ok, _} = Collections.delete(client, collection_name)

      {:ok, _} =
        Backup.restore(client, backup_id, :filesystem,
          include_collections: [collection_name],
          wait_for_completion: true
        )

      # Get restore status
      result = Backup.get_restore_status(client, backup_id, :filesystem)

      assert {:ok, status} = result
      assert status.status in [:success, :started, :transferring, :failed]

      # Cleanup
      Collections.delete(client, collection_name)
    end
  end
end
