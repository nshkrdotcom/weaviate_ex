defmodule WeaviateEx.API.ClusterTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Cluster
  alias WeaviateEx.Cluster.{Node, Replication, Shard}
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "nodes/2" do
    test "returns list of nodes with minimal output", %{client: client} do
      expect_http_success(Mock, :get, "/v1/nodes", %{
        "nodes" => [
          %{"name" => "node-0", "status" => "HEALTHY", "version" => "1.24.0"},
          %{"name" => "node-1", "status" => "HEALTHY", "version" => "1.24.0"}
        ]
      })

      assert {:ok, nodes} = Cluster.nodes(client)
      assert length(nodes) == 2
      assert Enum.all?(nodes, fn n -> %Node{} = n end)
      assert hd(nodes).name == "node-0"
    end

    test "returns nodes with verbose output", %{client: client} do
      expect_http_success(Mock, :get, "/v1/nodes?output=verbose", %{
        "nodes" => [
          %{
            "name" => "node-0",
            "status" => "HEALTHY",
            "stats" => %{"objectCount" => 5000}
          }
        ]
      })

      assert {:ok, [node]} = Cluster.nodes(client, output: :verbose)
      assert node.stats == %{"objectCount" => 5000}
    end

    test "filters by collection", %{client: client} do
      expect_http_success(Mock, :get, "/v1/nodes?class=Article", %{
        "nodes" => [
          %{
            "name" => "node-0",
            "status" => "HEALTHY",
            "shards" => [
              %{"name" => "shard-0", "status" => "READY", "objectCount" => 100}
            ]
          }
        ]
      })

      assert {:ok, [node]} = Cluster.nodes(client, collection: "Article")
      assert length(node.shards) == 1
    end

    test "filters by shard name", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert path == "/v1/nodes?shardName=shard-0"

        {:ok,
         %{
           "nodes" => [
             %{
               "name" => "node-0",
               "status" => "HEALTHY",
               "shards" => [
                 %{"name" => "shard-0", "status" => "READY", "objectCount" => 100}
               ]
             }
           ]
         }}
      end)

      assert {:ok, [node]} = Cluster.nodes(client, shard: "shard-0")
      assert length(node.shards) == 1
    end

    test "filters by collection and shard", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert String.contains?(path, "class=Article")
        assert String.contains?(path, "shardName=shard-0")

        {:ok,
         %{
           "nodes" => [
             %{
               "name" => "node-0",
               "status" => "HEALTHY",
               "shards" => [
                 %{"name" => "shard-0", "status" => "READY", "objectCount" => 100}
               ]
             }
           ]
         }}
      end)

      assert {:ok, [node]} = Cluster.nodes(client, collection: "Article", shard: "shard-0")
      assert length(node.shards) == 1
    end

    test "filters by collection, shard, and verbose output", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert String.contains?(path, "class=Article")
        assert String.contains?(path, "shardName=shard-0")
        assert String.contains?(path, "output=verbose")

        {:ok,
         %{
           "nodes" => [
             %{
               "name" => "node-0",
               "status" => "HEALTHY",
               "stats" => %{"objectCount" => 5000},
               "shards" => [
                 %{"name" => "shard-0", "status" => "READY", "objectCount" => 100}
               ]
             }
           ]
         }}
      end)

      assert {:ok, [node]} =
               Cluster.nodes(client, collection: "Article", shard: "shard-0", output: :verbose)

      assert node.stats == %{"objectCount" => 5000}
    end

    test "handles list response format", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/nodes", nil, _opts ->
        {:ok, [%{"name" => "node-0", "status" => "HEALTHY"}]}
      end)

      assert {:ok, [node]} = Cluster.nodes(client)
      assert node.name == "node-0"
    end

    test "handles connection error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/nodes", :connection_error)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} = Cluster.nodes(client)
    end
  end

  describe "shards/2" do
    test "returns shards for collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/schema/Article/shards", nil, _opts ->
        {:ok,
         [
           %{"name" => "shard-0", "status" => "READY", "objectCount" => 100},
           %{"name" => "shard-1", "status" => "READY", "objectCount" => 200}
         ]}
      end)

      assert {:ok, shards} = Cluster.shards(client, "Article")
      assert length(shards) == 2
      assert Enum.all?(shards, fn s -> %Shard{} = s end)
      assert Enum.all?(shards, fn s -> s.collection == "Article" end)
    end

    test "includes vector_queue_size for indexing status", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/schema/Article/shards", nil, _opts ->
        {:ok,
         [
           %{"name" => "shard-0", "status" => "INDEXING", "vectorQueueSize" => 500}
         ]}
      end)

      assert {:ok, [shard]} = Cluster.shards(client, "Article")
      assert shard.vector_queue_size == 500
      assert shard.status == :indexing
      assert Shard.vectors_indexed?(shard) == false
    end

    test "returns error for non-existent collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, "/v1/schema/NonExistent/shards", nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Collection not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Cluster.shards(client, "NonExistent")
    end
  end

  describe "statistics/1" do
    test "returns cluster statistics map", %{client: client} do
      expect_http_success(Mock, :get, "/v1/cluster/statistics", %{
        "nodes" => 3,
        "shards" => 10,
        "objects" => 50_000
      })

      assert {:ok, stats} = Cluster.statistics(client)
      assert stats["nodes"] == 3
      assert stats["shards"] == 10
    end

    test "handles connection error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/cluster/statistics", :connection_error)

      assert {:error, _} = Cluster.statistics(client)
    end
  end

  describe "replicate/4" do
    test "initiates COPY replication", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/cluster/replications", body, _opts ->
        assert body["type"] == "COPY"
        assert body["collection"] == "Article"
        assert body["shard"] == "shard-0"
        assert body["sourceNode"] == "node-1"
        assert body["targetNode"] == "node-2"

        {:ok,
         %{
           "id" => "uuid-123",
           "collection" => "Article",
           "shard" => "shard-0",
           "status" => "PENDING"
         }}
      end)

      assert {:ok, op} =
               Cluster.replicate(client, "Article", "shard-0",
                 source: "node-1",
                 target: "node-2",
                 type: :copy
               )

      assert %Replication.Operation{} = op
      assert op.id == "uuid-123"
      assert op.status == :pending
    end

    test "initiates MOVE replication", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/cluster/replications", body, _opts ->
        assert body["type"] == "MOVE"
        {:ok, %{"id" => "uuid-456", "status" => "PENDING"}}
      end)

      assert {:ok, _op} =
               Cluster.replicate(client, "Article", "shard-0",
                 source: "node-1",
                 target: "node-2",
                 type: :move
               )
    end

    test "defaults to COPY when type not specified", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/cluster/replications", body, _opts ->
        assert body["type"] == "COPY"
        {:ok, %{"id" => "uuid-789", "status" => "PENDING"}}
      end)

      assert {:ok, _} =
               Cluster.replicate(client, "Article", "shard-0",
                 source: "node-1",
                 target: "node-2"
               )
    end

    test "returns error for invalid request", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/cluster/replications", _body, _opts ->
        {:error, %WeaviateEx.Error{type: :bad_request, message: "Invalid node"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :bad_request}} =
               Cluster.replicate(client, "Article", "shard-0",
                 source: "node-1",
                 target: "invalid-node"
               )
    end
  end

  describe "list_replications/2" do
    test "returns all replication operations", %{client: client} do
      expect_http_success(Mock, :get, "/v1/cluster/replications", [
        %{"id" => "uuid-1", "status" => "RUNNING"},
        %{"id" => "uuid-2", "status" => "COMPLETED"}
      ])

      assert {:ok, ops} = Cluster.list_replications(client)
      assert length(ops) == 2
      assert Enum.all?(ops, fn op -> %Replication.Operation{} = op end)
    end

    test "filters by collection", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :get, "/v1/cluster/replications?collection=Article", nil, _opts ->
          {:ok, [%{"id" => "uuid-1", "collection" => "Article", "status" => "RUNNING"}]}
        end
      )

      assert {:ok, [op]} = Cluster.list_replications(client, collection: "Article")
      assert op.collection == "Article"
    end

    test "filters by target_node", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :get, "/v1/cluster/replications?targetNode=node-2", nil, _opts ->
          {:ok, [%{"id" => "uuid-1", "targetNode" => "node-2", "status" => "PENDING"}]}
        end
      )

      assert {:ok, [op]} = Cluster.list_replications(client, target_node: "node-2")
      assert op.target_node == "node-2"
    end

    test "handles replications wrapper in response", %{client: client} do
      expect_http_success(Mock, :get, "/v1/cluster/replications", %{
        "replications" => [
          %{"id" => "uuid-1", "status" => "RUNNING"}
        ]
      })

      assert {:ok, [_op]} = Cluster.list_replications(client)
    end

    test "returns empty list when no replications", %{client: client} do
      expect_http_success(Mock, :get, "/v1/cluster/replications", %{})

      assert {:ok, []} = Cluster.list_replications(client)
    end
  end

  describe "get_replication/3" do
    test "returns operation details", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/cluster/replications/uuid-123",
                                    nil,
                                    _opts ->
        {:ok,
         %{
           "id" => "uuid-123",
           "collection" => "Article",
           "status" => "RUNNING",
           "progress" => 0.75
         }}
      end)

      assert {:ok, op} = Cluster.get_replication(client, "uuid-123")
      assert op.id == "uuid-123"
      assert op.progress == 0.75
    end

    test "includes history when requested", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :get, "/v1/cluster/replications/uuid-123?includeHistory=true", nil, _opts ->
          {:ok, %{"id" => "uuid-123", "status" => "COMPLETED"}}
        end
      )

      assert {:ok, _op} = Cluster.get_replication(client, "uuid-123", include_history: true)
    end

    test "returns error for non-existent operation", %{client: client} do
      Mox.expect(Mock, :request, fn _client,
                                    :get,
                                    "/v1/cluster/replications/invalid",
                                    nil,
                                    _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Operation not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Cluster.get_replication(client, "invalid")
    end
  end

  describe "cancel_replication/2" do
    test "cancels running operation", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :post, "/v1/cluster/replications/uuid-123/cancel", nil, _opts ->
          {:ok, %{}}
        end
      )

      assert :ok = Cluster.cancel_replication(client, "uuid-123")
    end

    test "returns error for completed operation", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :post, "/v1/cluster/replications/uuid-123/cancel", nil, _opts ->
          {:error, %WeaviateEx.Error{type: :conflict, message: "Operation already completed"}}
        end
      )

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
               Cluster.cancel_replication(client, "uuid-123")
    end
  end

  describe "delete_replication/2" do
    test "deletes completed operation", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :delete, "/v1/cluster/replications/uuid-123", nil, _opts ->
          {:ok, %{}}
        end
      )

      assert :ok = Cluster.delete_replication(client, "uuid-123")
    end

    test "returns error for running operation", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :delete, "/v1/cluster/replications/uuid-123", nil, _opts ->
          {:error, %WeaviateEx.Error{type: :conflict, message: "Cannot delete running operation"}}
        end
      )

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
               Cluster.delete_replication(client, "uuid-123")
    end
  end

  describe "delete_all_replications/1" do
    test "deletes all replication records", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :delete, "/v1/cluster/replications", nil, _opts ->
          {:ok, %{}}
        end
      )

      assert :ok = Cluster.delete_all_replications(client)
    end

    test "returns error on failure", %{client: client} do
      Mox.expect(
        Mock,
        :request,
        fn _client, :delete, "/v1/cluster/replications", nil, _opts ->
          {:error, %WeaviateEx.Error{type: :server_error, message: "Internal error"}}
        end
      )

      assert {:error, %WeaviateEx.Error{type: :server_error}} =
               Cluster.delete_all_replications(client)
    end
  end

  describe "query_sharding_state/3" do
    alias WeaviateEx.Cluster.ShardingState

    test "returns sharding state for collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert String.contains?(path, "collection=Article")

        {:ok,
         %{
           "shardingState" => %{
             "collection" => "Article",
             "shards" => [
               %{"shard" => "shard-0", "replicas" => ["node-0", "node-1"]},
               %{"shard" => "shard-1", "replicas" => ["node-1", "node-2"]}
             ]
           }
         }}
      end)

      assert {:ok, state} = Cluster.query_sharding_state(client, "Article")
      assert %ShardingState{} = state
      assert state.collection == "Article"
      assert length(state.shards) == 2
      assert hd(state.shards).name == "shard-0"
      assert hd(state.shards).replicas == ["node-0", "node-1"]
    end

    test "filters by shard name", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, path, nil, _opts ->
        assert String.contains?(path, "collection=Article")
        assert String.contains?(path, "shard=shard-0")

        {:ok,
         %{
           "shardingState" => %{
             "collection" => "Article",
             "shards" => [
               %{"shard" => "shard-0", "replicas" => ["node-0", "node-1"]}
             ]
           }
         }}
      end)

      assert {:ok, state} = Cluster.query_sharding_state(client, "Article", shard: "shard-0")
      assert length(state.shards) == 1
    end

    test "returns nil for non-existent collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Collection not found"}}
      end)

      assert {:ok, nil} = Cluster.query_sharding_state(client, "NonExistent")
    end

    test "returns nil when response is empty map", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :get, _path, nil, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, nil} = Cluster.query_sharding_state(client, "Article")
    end
  end
end
