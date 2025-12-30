defmodule WeaviateEx.BatchTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.{Batch, Fixtures}
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "create_objects/2" do
    test "creates multiple objects in batch", %{client: _client} do
      objects = Fixtures.batch_objects_fixture("Article", 3)

      response = %{
        "results" => Enum.map(objects, fn obj -> %{"id" => obj["id"], "status" => "SUCCESS"} end)
      }

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/objects"
        {:ok, response["results"]}
      end)

      assert {:ok, result} = Batch.create_objects(objects)
      assert length(result["results"]) == 3
      assert Enum.all?(result["results"], fn r -> r["status"] == "SUCCESS" end)
    end

    test "returns partial success with errors", %{client: _client} do
      objects = Fixtures.batch_objects_fixture("Article", 2)

      response = [
        %{"id" => Enum.at(objects, 0)["id"], "status" => "SUCCESS"},
        %{
          "id" => Enum.at(objects, 1)["id"],
          "status" => "FAILED",
          "errors" => %{"error" => "Invalid property"}
        }
      ]

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/objects"
        {:ok, response}
      end)

      assert {:ok, result} = Batch.create_objects(objects)
      assert Enum.at(result["results"], 0)["status"] == "SUCCESS"
      assert Enum.at(result["results"], 1)["status"] == "FAILED"
    end

    test "returns error when all objects fail", %{client: _client} do
      objects = Fixtures.batch_objects_fixture("Article", 2)

      response = [
        %{
          "id" => Enum.at(objects, 0)["id"],
          "status" => "FAILED",
          "result" => %{"errors" => [%{"message" => "Invalid property"}]}
        },
        %{
          "id" => Enum.at(objects, 1)["id"],
          "status" => "FAILED",
          "result" => %{"errors" => [%{"message" => "Invalid property"}]}
        }
      ]

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/objects"
        {:ok, response}
      end)

      assert {:error, %WeaviateEx.Error{type: :batch_all_failed, message: message}} =
               Batch.create_objects(objects)

      assert message =~ "All batch objects failed"
    end

    test "returns error when all objects fail with summary option", %{client: _client} do
      objects = Fixtures.batch_objects_fixture("Article", 1)

      response = %{
        "results" => %{
          "objects" => [
            %{
              "id" => Enum.at(objects, 0)["id"],
              "status" => "FAILED",
              "class" => "Article",
              "result" => %{"errors" => [%{"message" => "Invalid property"}]}
            }
          ]
        }
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/batch/objects", _body, _opts ->
        {:ok, response}
      end)

      assert {:error, %WeaviateEx.Error{type: :batch_all_failed}} =
               Batch.create_objects(objects, return_summary: true)
    end

    test "handles consistency level option", %{client: _client} do
      objects = [Fixtures.object_fixture()]

      response = [%{"id" => "00000000-0000-0000-0000-000000000001", "status" => "SUCCESS"}]

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/objects?consistency_level=QUORUM"
        {:ok, response}
      end)

      assert {:ok, _} = Batch.create_objects(objects, consistency_level: "QUORUM")
    end

    test "returns summary struct when requested", %{client: _client} do
      objects = Fixtures.batch_objects_fixture("Article", 2)

      response = %{
        "results" => %{
          "objects" => [
            %{"id" => Enum.at(objects, 0)["id"], "status" => "SUCCESS", "class" => "Article"},
            %{
              "id" => Enum.at(objects, 1)["id"],
              "status" => "FAILED",
              "class" => "Article",
              "result" => %{
                "errors" => [
                  %{"message" => "invalid property", "path" => "properties.title"}
                ]
              }
            }
          ]
        }
      }

      Mox.expect(Mock, :request, fn _client, :post, "/v1/batch/objects", _body, _opts ->
        {:ok, response}
      end)

      assert {:ok, summary} = Batch.create_objects(objects, return_summary: true)
      assert %WeaviateEx.API.Batch.Result{} = summary
      assert summary.statistics.successful == 1
      assert summary.statistics.failed == 1
      assert Enum.map(summary.errors, & &1.id) == [Enum.at(objects, 1)["id"]]
    end
  end

  describe "delete_objects/2" do
    test "deletes objects matching criteria", %{client: _client} do
      response = %{
        "match" => %{
          "class" => "Article",
          "where" => %{"path" => ["title"], "operator" => "Equal", "valueText" => "Delete Me"}
        },
        "output" => "minimal",
        "results" => %{
          "matches" => 5,
          "limit" => 10_000,
          "successful" => 5,
          "failed" => 0
        }
      }

      Mox.expect(Mock, :request, fn _client, :delete, path, _body, _opts ->
        assert path =~ "/v1/batch/objects"
        {:ok, response}
      end)

      assert {:ok, result} =
               Batch.delete_objects(%{
                 class: "Article",
                 where: %{
                   path: ["title"],
                   operator: "Equal",
                   valueText: "Delete Me"
                 }
               })

      assert result["results"]["successful"] == 5
    end

    test "returns error on invalid criteria", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, _body, _opts ->
        assert path =~ "/v1/batch/objects"

        {:error,
         %WeaviateEx.Error{
           type: :bad_request,
           message: "Invalid where clause",
           details: %{},
           status_code: 400
         }}
      end)

      assert {:error, %WeaviateEx.Error{type: :bad_request}} =
               Batch.delete_objects(%{
                 class: "Article",
                 where: %{}
               })
    end
  end

  describe "add_references/2" do
    test "adds cross-references in batch", %{client: _client} do
      references = [
        %{
          from: "weaviate://localhost/Article/00000000-0000-0000-0000-000000000001/hasAuthor",
          to: "weaviate://localhost/Author/00000000-0000-0000-0000-000000000002"
        }
      ]

      response = [%{"status" => "SUCCESS"}]

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/references"
        {:ok, response}
      end)

      assert {:ok, result} = Batch.add_references(references)
      assert Enum.at(result["results"], 0)["status"] == "SUCCESS"
    end
  end

  describe "Collections.insert_many/3" do
    alias WeaviateEx.Collections

    test "inserts objects with simple property maps", %{client: _client} do
      objects = [
        %{title: "Article 1", content: "Content 1"},
        %{title: "Article 2", content: "Content 2"}
      ]

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        assert length(body["objects"]) == 2
        # Each object should have class added
        assert Enum.all?(body["objects"], fn obj -> obj[:class] == "Article" end)
        # Properties should be wrapped
        assert Enum.at(body["objects"], 0)[:properties] == %{
                 title: "Article 1",
                 content: "Content 1"
               }

        response =
          Enum.map(body["objects"], fn obj ->
            %{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS", "class" => obj[:class]}
          end)

        {:ok, response}
      end)

      assert {:ok, result} = Collections.insert_many("Article", objects)
      assert length(result["results"]) == 2
    end

    test "inserts objects with explicit properties field", %{client: _client} do
      objects = [
        %{properties: %{title: "Article 1"}, uuid: "custom-uuid-1"},
        %{properties: %{title: "Article 2"}}
      ]

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/batch/objects"
        assert length(body["objects"]) == 2
        assert Enum.at(body["objects"], 0)[:id] == "custom-uuid-1"
        assert Enum.at(body["objects"], 0)[:properties] == %{title: "Article 1"}

        response =
          Enum.map(body["objects"], fn obj ->
            %{"id" => obj[:id] || Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, response}
      end)

      assert {:ok, _} = Collections.insert_many("Article", objects)
    end

    test "applies tenant option to all objects", %{client: _client} do
      objects = [
        %{title: "Article 1"},
        %{title: "Article 2"}
      ]

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        # All objects should have tenant set
        assert Enum.all?(body["objects"], fn obj -> obj[:tenant] == "tenant-a" end)

        response =
          Enum.map(body["objects"], fn _ ->
            %{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, response}
      end)

      assert {:ok, _} = Collections.insert_many("Article", objects, tenant: "tenant-a")
    end

    test "preserves per-object tenant when provided", %{client: _client} do
      objects = [
        %{title: "Article 1", tenant: "tenant-specific"},
        %{title: "Article 2"}
      ]

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        obj1 = Enum.at(body["objects"], 0)
        obj2 = Enum.at(body["objects"], 1)
        # First object uses its own tenant
        assert obj1[:tenant] == "tenant-specific"
        # Second object uses option tenant
        assert obj2[:tenant] == "tenant-default"

        response =
          Enum.map(body["objects"], fn _ ->
            %{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}
          end)

        {:ok, response}
      end)

      assert {:ok, _} = Collections.insert_many("Article", objects, tenant: "tenant-default")
    end

    test "includes vector when provided", %{client: _client} do
      objects = [
        %{properties: %{title: "Article 1"}, vector: [0.1, 0.2, 0.3]}
      ]

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        obj = Enum.at(body["objects"], 0)
        assert obj[:vector] == [0.1, 0.2, 0.3]

        {:ok, [%{"id" => Uniq.UUID.uuid4(), "status" => "SUCCESS"}]}
      end)

      assert {:ok, _} = Collections.insert_many("Article", objects)
    end
  end

  describe "integration tests" do
    @tag :integration
    test "batch create and delete workflow" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        # Create multiple objects
        objects = [
          %{class: "TestArticle", properties: %{title: "Batch 1"}},
          %{class: "TestArticle", properties: %{title: "Batch 2"}},
          %{class: "TestArticle", properties: %{title: "Batch 3"}}
        ]

        {:ok, result} = Batch.create_objects(objects)
        assert length(result["results"]) == 3

        # Batch delete
        {:ok, delete_result} =
          Batch.delete_objects(%{
            class: "TestArticle",
            where: %{path: ["title"], operator: "Like", valueText: "Batch*"}
          })

        assert delete_result["results"]["successful"] >= 3
      else
        assert true
      end
    end
  end
end
