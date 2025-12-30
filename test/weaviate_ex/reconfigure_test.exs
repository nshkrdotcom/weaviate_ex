defmodule WeaviateEx.ReconfigureTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Reconfigure

  describe "inverted_index/1" do
    test "returns empty config when no options" do
      result = Reconfigure.inverted_index()
      assert result == %{"invertedIndexConfig" => %{}}
    end

    test "includes bm25 settings" do
      result = Reconfigure.inverted_index(bm25: [b: 0.75, k1: 1.5])

      assert result["invertedIndexConfig"]["bm25"] == %{"b" => 0.75, "k1" => 1.5}
    end

    test "includes cleanup_interval_seconds" do
      result = Reconfigure.inverted_index(cleanup_interval_seconds: 120)

      assert result["invertedIndexConfig"]["cleanupIntervalSeconds"] == 120
    end

    test "includes index_null_state" do
      result = Reconfigure.inverted_index(index_null_state: true)

      assert result["invertedIndexConfig"]["indexNullState"] == true
    end

    test "includes multiple settings" do
      result =
        Reconfigure.inverted_index(
          bm25: [b: 0.8],
          cleanup_interval_seconds: 60,
          index_null_state: true,
          index_property_length: true
        )

      config = result["invertedIndexConfig"]
      assert config["bm25"] == %{"b" => 0.8}
      assert config["cleanupIntervalSeconds"] == 60
      assert config["indexNullState"] == true
      assert config["indexPropertyLength"] == true
    end
  end

  describe "replication/1" do
    test "returns empty config when no options" do
      result = Reconfigure.replication()
      assert result == %{"replicationConfig" => %{}}
    end

    test "includes factor" do
      result = Reconfigure.replication(factor: 3)

      assert result["replicationConfig"]["factor"] == 3
    end

    test "includes async_enabled" do
      result = Reconfigure.replication(async_enabled: true)

      assert result["replicationConfig"]["asyncEnabled"] == true
    end

    test "includes deletion_strategy as atom" do
      result = Reconfigure.replication(deletion_strategy: :delete_on_conflict)

      assert result["replicationConfig"]["deletionStrategy"] == "DeleteOnConflict"
    end
  end

  describe "vector_index_hnsw/1" do
    test "returns empty config when no options" do
      result = Reconfigure.vector_index_hnsw()
      assert result == %{"vectorIndexConfig" => %{}}
    end

    test "includes ef parameters" do
      result = Reconfigure.vector_index_hnsw(ef: 128, ef_construction: 256)

      assert result["vectorIndexConfig"]["ef"] == 128
      assert result["vectorIndexConfig"]["efConstruction"] == 256
    end

    test "includes max_connections" do
      result = Reconfigure.vector_index_hnsw(max_connections: 64)

      assert result["vectorIndexConfig"]["maxConnections"] == 64
    end

    test "includes filter_strategy" do
      result = Reconfigure.vector_index_hnsw(filter_strategy: :sweeping)

      assert result["vectorIndexConfig"]["filterStrategy"] == "sweeping"
    end
  end

  describe "named_vectors_update/2" do
    test "creates named vector update config" do
      result = Reconfigure.named_vectors_update("title_vector", ef: 128)

      assert result["vectorConfig"]["title_vector"]["vectorIndexConfig"]["ef"] == 128
    end
  end

  describe "multi_tenancy/1" do
    test "includes auto_tenant_creation" do
      result = Reconfigure.multi_tenancy(auto_tenant_creation: true)

      assert result["multiTenancyConfig"]["autoTenantCreation"] == true
    end

    test "includes auto_tenant_activation" do
      result = Reconfigure.multi_tenancy(auto_tenant_activation: true)

      assert result["multiTenancyConfig"]["autoTenantActivation"] == true
    end
  end

  describe "description/1" do
    test "creates description update" do
      result = Reconfigure.description("Updated description")

      assert result == %{"description" => "Updated description"}
    end
  end

  describe "merge/1" do
    test "merges multiple configs" do
      configs = [
        Reconfigure.inverted_index(bm25: [b: 0.8]),
        Reconfigure.replication(factor: 3)
      ]

      result = Reconfigure.merge(configs)

      assert result["invertedIndexConfig"]["bm25"] == %{"b" => 0.8}
      assert result["replicationConfig"]["factor"] == 3
    end
  end
end
