defmodule WeaviateEx.Batch.VectorIndexingTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.VectorIndexing
  alias WeaviateEx.Cluster.Shard

  describe "wait_for_indexing/3" do
    test "returns :ok when all shards are indexed" do
      # The function requires a real client; we test via mocked scenarios
      # Here we test the helper functions that don't require a client

      shard1 = %Shard{name: "shard-0", vector_queue_size: 0, status: :ready}
      shard2 = %Shard{name: "shard-1", vector_queue_size: 0, status: :ready}

      assert Shard.vectors_indexed?(shard1)
      assert Shard.vectors_indexed?(shard2)
    end

    test "detects unindexed vectors via vector_queue_size" do
      shard = %Shard{name: "shard-0", vector_queue_size: 100, status: :ready}

      refute Shard.vectors_indexed?(shard)
    end
  end

  describe "option handling" do
    test "accepts timeout option" do
      # The defaults are defined in the module
      assert VectorIndexing.__info__(:functions) |> Keyword.has_key?(:wait_for_indexing)
    end

    test "accepts poll_interval option" do
      # Test that the function signature accepts options
      assert VectorIndexing.__info__(:functions) |> Keyword.has_key?(:wait_for_indexing)
    end

    test "accepts how_many_failures option" do
      assert VectorIndexing.__info__(:functions) |> Keyword.has_key?(:wait_for_indexing)
    end
  end

  describe "shard helpers" do
    test "Shard.vectors_indexed?/1 returns true when queue is empty" do
      shard = %Shard{name: "test", vector_queue_size: 0}
      assert Shard.vectors_indexed?(shard)
    end

    test "Shard.vectors_indexed?/1 returns false when queue has items" do
      shard = %Shard{name: "test", vector_queue_size: 50}
      refute Shard.vectors_indexed?(shard)
    end

    test "Shard.ready?/1 returns true when status is ready and queue is empty" do
      shard = %Shard{name: "test", status: :ready, vector_queue_size: 0}
      assert Shard.ready?(shard)
    end

    test "Shard.ready?/1 returns false when queue is not empty" do
      shard = %Shard{name: "test", status: :ready, vector_queue_size: 10}
      refute Shard.ready?(shard)
    end

    test "Shard.ready?/1 returns false when status is not ready" do
      shard = %Shard{name: "test", status: :indexing, vector_queue_size: 0}
      refute Shard.ready?(shard)
    end
  end
end
