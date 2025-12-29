defmodule WeaviateEx.Cluster.ShardTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Cluster.Shard

  describe "from_api/1" do
    test "parses complete shard data" do
      api_data = %{
        "name" => "shard-0",
        "class" => "Article",
        "status" => "READY",
        "objectCount" => 1000,
        "vectorQueueSize" => 0,
        "vectorIndexingStatus" => "INDEXED",
        "compressed" => true
      }

      shard = Shard.from_api(api_data)

      assert shard.name == "shard-0"
      assert shard.collection == "Article"
      assert shard.status == :ready
      assert shard.object_count == 1000
      assert shard.vector_queue_size == 0
      assert shard.vector_indexing_status == "INDEXED"
      assert shard.compressed == true
    end

    test "handles minimal shard data with defaults" do
      api_data = %{
        "name" => "shard-1"
      }

      shard = Shard.from_api(api_data)

      assert shard.name == "shard-1"
      assert shard.collection == nil
      assert shard.status == :ready
      assert shard.object_count == 0
      assert shard.vector_queue_size == 0
      assert shard.compressed == false
    end

    test "parses various status values" do
      assert Shard.from_api(%{"name" => "s", "status" => "READY"}).status == :ready
      assert Shard.from_api(%{"name" => "s", "status" => "READONLY"}).status == :readonly
      assert Shard.from_api(%{"name" => "s", "status" => "INDEXING"}).status == :indexing
      assert Shard.from_api(%{"name" => "s", "status" => "LOADING"}).status == :loading
      assert Shard.from_api(%{"name" => "s", "status" => "UNKNOWN"}).status == :ready
    end
  end

  describe "parse_status/1" do
    test "parses known status strings" do
      assert Shard.parse_status("READY") == :ready
      assert Shard.parse_status("READONLY") == :readonly
      assert Shard.parse_status("INDEXING") == :indexing
      assert Shard.parse_status("LOADING") == :loading
    end

    test "defaults to ready for unknown status" do
      assert Shard.parse_status("UNKNOWN") == :ready
      assert Shard.parse_status("") == :ready
    end
  end

  describe "status_to_api/1" do
    test "converts status atoms to API strings" do
      assert Shard.status_to_api(:ready) == "READY"
      assert Shard.status_to_api(:readonly) == "READONLY"
      assert Shard.status_to_api(:indexing) == "INDEXING"
      assert Shard.status_to_api(:loading) == "LOADING"
    end
  end

  describe "ready?/1" do
    test "returns true when status is ready and queue is empty" do
      shard = %Shard{status: :ready, vector_queue_size: 0}
      assert Shard.ready?(shard) == true
    end

    test "returns false when status is ready but queue is not empty" do
      shard = %Shard{status: :ready, vector_queue_size: 100}
      assert Shard.ready?(shard) == false
    end

    test "returns false when status is not ready" do
      assert Shard.ready?(%Shard{status: :indexing, vector_queue_size: 0}) == false
      assert Shard.ready?(%Shard{status: :loading, vector_queue_size: 0}) == false
      assert Shard.ready?(%Shard{status: :readonly, vector_queue_size: 0}) == false
    end
  end

  describe "vectors_indexed?/1" do
    test "returns true when vector queue is empty" do
      shard = %Shard{vector_queue_size: 0}
      assert Shard.vectors_indexed?(shard) == true
    end

    test "returns false when vector queue is not empty" do
      shard = %Shard{vector_queue_size: 50}
      assert Shard.vectors_indexed?(shard) == false
    end

    test "returns true regardless of shard status when queue is empty" do
      assert Shard.vectors_indexed?(%Shard{status: :indexing, vector_queue_size: 0}) == true
      assert Shard.vectors_indexed?(%Shard{status: :loading, vector_queue_size: 0}) == true
    end
  end
end
