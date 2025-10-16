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

    test "handles consistency level option", %{client: _client} do
      objects = [Fixtures.object_fixture()]

      response = [%{"id" => "00000000-0000-0000-0000-000000000001", "status" => "SUCCESS"}]

      Mox.expect(Mock, :request, fn _client, :post, path, _body, _opts ->
        assert path =~ "/v1/batch/objects?consistency_level=QUORUM"
        {:ok, response}
      end)

      assert {:ok, _} = Batch.create_objects(objects, consistency_level: "QUORUM")
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
          "limit" => 10000,
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
