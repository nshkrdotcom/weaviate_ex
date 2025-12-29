defmodule WeaviateEx.Cluster.NodeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Cluster.{Node, Shard}

  describe "from_api/1" do
    test "parses complete node data" do
      api_data = %{
        "name" => "node-0",
        "status" => "HEALTHY",
        "version" => "1.24.0",
        "gitHash" => "abc123",
        "stats" => %{"objectCount" => 5000},
        "shards" => [
          %{"name" => "shard-0", "status" => "READY", "objectCount" => 1000}
        ]
      }

      node = Node.from_api(api_data)

      assert node.name == "node-0"
      assert node.status == :healthy
      assert node.version == "1.24.0"
      assert node.git_hash == "abc123"
      assert node.stats == %{"objectCount" => 5000}
      assert length(node.shards) == 1
      assert hd(node.shards).name == "shard-0"
    end

    test "handles minimal node data" do
      api_data = %{
        "name" => "node-1"
      }

      node = Node.from_api(api_data)

      assert node.name == "node-1"
      assert node.status == :healthy
      assert node.version == nil
      assert node.git_hash == nil
      assert node.stats == nil
      assert node.shards == nil
    end

    test "parses various status values" do
      assert Node.from_api(%{"name" => "n", "status" => "HEALTHY"}).status == :healthy
      assert Node.from_api(%{"name" => "n", "status" => "UNHEALTHY"}).status == :unhealthy
      assert Node.from_api(%{"name" => "n", "status" => "UNAVAILABLE"}).status == :unavailable
      assert Node.from_api(%{"name" => "n", "status" => "UNKNOWN"}).status == :unavailable
    end
  end

  describe "parse_status/1" do
    test "parses known status strings" do
      assert Node.parse_status("HEALTHY") == :healthy
      assert Node.parse_status("UNHEALTHY") == :unhealthy
      assert Node.parse_status("UNAVAILABLE") == :unavailable
    end

    test "defaults to unavailable for unknown status" do
      assert Node.parse_status("UNKNOWN") == :unavailable
      assert Node.parse_status("") == :unavailable
    end
  end

  describe "status_to_api/1" do
    test "converts status atoms to API strings" do
      assert Node.status_to_api(:healthy) == "HEALTHY"
      assert Node.status_to_api(:unhealthy) == "UNHEALTHY"
      assert Node.status_to_api(:unavailable) == "UNAVAILABLE"
    end
  end

  describe "healthy?/1" do
    test "returns true for healthy nodes" do
      node = %Node{status: :healthy}
      assert Node.healthy?(node) == true
    end

    test "returns false for unhealthy nodes" do
      assert Node.healthy?(%Node{status: :unhealthy}) == false
      assert Node.healthy?(%Node{status: :unavailable}) == false
    end
  end

  describe "total_object_count/1" do
    test "returns 0 when no shards" do
      node = %Node{shards: nil}
      assert Node.total_object_count(node) == 0
    end

    test "returns 0 for empty shards list" do
      node = %Node{shards: []}
      assert Node.total_object_count(node) == 0
    end

    test "sums object counts across all shards" do
      node = %Node{
        shards: [
          %Shard{object_count: 100},
          %Shard{object_count: 200},
          %Shard{object_count: 150}
        ]
      }

      assert Node.total_object_count(node) == 450
    end
  end

  describe "shards_for_collection/2" do
    test "returns empty list when no shards" do
      node = %Node{shards: nil}
      assert Node.shards_for_collection(node, "Article") == []
    end

    test "filters shards by collection" do
      node = %Node{
        shards: [
          %Shard{name: "s1", collection: "Article"},
          %Shard{name: "s2", collection: "Author"},
          %Shard{name: "s3", collection: "Article"}
        ]
      }

      result = Node.shards_for_collection(node, "Article")

      assert length(result) == 2
      assert Enum.all?(result, fn s -> s.collection == "Article" end)
    end

    test "returns empty list when no matching collection" do
      node = %Node{
        shards: [
          %Shard{name: "s1", collection: "Author"}
        ]
      }

      assert Node.shards_for_collection(node, "Article") == []
    end
  end
end
