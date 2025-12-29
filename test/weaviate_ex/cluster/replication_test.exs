defmodule WeaviateEx.Cluster.ReplicationTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Cluster.Replication
  alias WeaviateEx.Cluster.Replication.Operation

  describe "type_to_api/1" do
    test "converts type atoms to API strings" do
      assert Replication.type_to_api(:copy) == "COPY"
      assert Replication.type_to_api(:move) == "MOVE"
    end
  end

  describe "type_from_api/1" do
    test "parses type strings to atoms" do
      assert Replication.type_from_api("COPY") == :copy
      assert Replication.type_from_api("MOVE") == :move
    end

    test "defaults to copy for unknown type" do
      assert Replication.type_from_api("UNKNOWN") == :copy
    end
  end

  describe "status_to_api/1" do
    test "converts status atoms to API strings" do
      assert Replication.status_to_api(:pending) == "PENDING"
      assert Replication.status_to_api(:running) == "RUNNING"
      assert Replication.status_to_api(:completed) == "COMPLETED"
      assert Replication.status_to_api(:failed) == "FAILED"
      assert Replication.status_to_api(:cancelled) == "CANCELLED"
    end
  end

  describe "status_from_api/1" do
    test "parses status strings to atoms" do
      assert Replication.status_from_api("PENDING") == :pending
      assert Replication.status_from_api("RUNNING") == :running
      assert Replication.status_from_api("COMPLETED") == :completed
      assert Replication.status_from_api("FAILED") == :failed
      assert Replication.status_from_api("CANCELLED") == :cancelled
    end

    test "defaults to pending for unknown status" do
      assert Replication.status_from_api("UNKNOWN") == :pending
    end
  end

  describe "Operation.from_api/1" do
    test "parses complete operation data" do
      api_data = %{
        "id" => "uuid-123",
        "collection" => "Article",
        "shard" => "shard-0",
        "sourceNode" => "node-1",
        "targetNode" => "node-2",
        "type" => "COPY",
        "status" => "RUNNING",
        "progress" => 0.45,
        "createdAt" => "2025-01-01T10:00:00Z",
        "completedAt" => nil
      }

      op = Operation.from_api(api_data)

      assert op.id == "uuid-123"
      assert op.collection == "Article"
      assert op.shard == "shard-0"
      assert op.source_node == "node-1"
      assert op.target_node == "node-2"
      assert op.type == :copy
      assert op.status == :running
      assert op.progress == 0.45
      assert op.created_at != nil
      assert op.completed_at == nil
    end

    test "handles class instead of collection key" do
      api_data = %{
        "id" => "uuid-456",
        "class" => "Author",
        "shard" => "shard-1",
        "type" => "MOVE",
        "status" => "COMPLETED"
      }

      op = Operation.from_api(api_data)

      assert op.collection == "Author"
      assert op.type == :move
      assert op.status == :completed
    end

    test "handles minimal operation data" do
      api_data = %{
        "id" => "uuid-789"
      }

      op = Operation.from_api(api_data)

      assert op.id == "uuid-789"
      assert op.type == :copy
      assert op.status == :pending
    end

    test "parses datetime strings" do
      api_data = %{
        "id" => "uuid-123",
        "createdAt" => "2025-01-01T10:00:00Z",
        "completedAt" => "2025-01-01T10:30:00Z"
      }

      op = Operation.from_api(api_data)

      assert op.created_at == ~U[2025-01-01 10:00:00Z]
      assert op.completed_at == ~U[2025-01-01 10:30:00Z]
    end
  end

  describe "Operation.completed?/1" do
    test "returns true for completed operations" do
      assert Operation.completed?(%Operation{status: :completed}) == true
      assert Operation.completed?(%Operation{status: :failed}) == true
      assert Operation.completed?(%Operation{status: :cancelled}) == true
    end

    test "returns false for in-progress operations" do
      assert Operation.completed?(%Operation{status: :pending}) == false
      assert Operation.completed?(%Operation{status: :running}) == false
    end
  end

  describe "Operation.success?/1" do
    test "returns true only for completed status" do
      assert Operation.success?(%Operation{status: :completed}) == true
    end

    test "returns false for other statuses" do
      assert Operation.success?(%Operation{status: :failed}) == false
      assert Operation.success?(%Operation{status: :cancelled}) == false
      assert Operation.success?(%Operation{status: :pending}) == false
      assert Operation.success?(%Operation{status: :running}) == false
    end
  end

  describe "Operation.in_progress?/1" do
    test "returns true for pending and running operations" do
      assert Operation.in_progress?(%Operation{status: :pending}) == true
      assert Operation.in_progress?(%Operation{status: :running}) == true
    end

    test "returns false for completed operations" do
      assert Operation.in_progress?(%Operation{status: :completed}) == false
      assert Operation.in_progress?(%Operation{status: :failed}) == false
      assert Operation.in_progress?(%Operation{status: :cancelled}) == false
    end
  end
end
