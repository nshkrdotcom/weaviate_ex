defmodule WeaviateEx.BatchTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.TestHelpers
  alias WeaviateEx.{Batch, Fixtures}

  setup :verify_on_exit!
  setup :setup_http_client

  describe "create_objects/2" do
    test "creates multiple objects in batch" do
      objects = Fixtures.batch_objects_fixture("Article", 3)

      response = %{
        "results" => Enum.map(objects, fn obj -> %{"id" => obj["id"], "status" => "SUCCESS"} end)
      }

      expect_http_request_with_body(:post, "/v1/batch/objects", :any, fn ->
        mock_success_response(response)
      end)

      assert {:ok, result} = Batch.create_objects(objects)
      assert length(result["results"]) == 3
      assert Enum.all?(result["results"], fn r -> r["status"] == "SUCCESS" end)
    end

    test "returns partial success with errors" do
      objects = Fixtures.batch_objects_fixture("Article", 2)

      response = %{
        "results" => [
          %{"id" => Enum.at(objects, 0)["id"], "status" => "SUCCESS"},
          %{
            "id" => Enum.at(objects, 1)["id"],
            "status" => "FAILED",
            "errors" => %{"error" => "Invalid property"}
          }
        ]
      }

      expect_http_request_with_body(:post, "/v1/batch/objects", :any, fn ->
        mock_success_response(response)
      end)

      assert {:ok, result} = Batch.create_objects(objects)
      assert Enum.at(result["results"], 0)["status"] == "SUCCESS"
      assert Enum.at(result["results"], 1)["status"] == "FAILED"
    end

    test "handles consistency level option" do
      objects = [Fixtures.object_fixture()]

      response = %{
        "results" => [%{"id" => "00000000-0000-0000-0000-000000000001", "status" => "SUCCESS"}]
      }

      expect_http_request_with_body(
        :post,
        "/v1/batch/objects?consistency_level=QUORUM",
        :any,
        fn ->
          mock_success_response(response)
        end
      )

      assert {:ok, _} = Batch.create_objects(objects, consistency_level: "QUORUM")
    end
  end

  describe "delete_objects/2" do
    test "deletes objects matching criteria" do
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

      expect_http_request_with_body(:delete, "/v1/batch/objects", :any, fn ->
        mock_success_response(response)
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

    test "returns error on invalid criteria" do
      expect_http_request_with_body(:delete, "/v1/batch/objects", :any, fn ->
        mock_error_response(400, "Invalid where clause")
      end)

      assert {:error, %{status: 400}} =
               Batch.delete_objects(%{
                 class: "Article",
                 where: %{}
               })
    end
  end

  describe "add_references/2" do
    test "adds cross-references in batch" do
      references = [
        %{
          from: "weaviate://localhost/Article/00000000-0000-0000-0000-000000000001/hasAuthor",
          to: "weaviate://localhost/Author/00000000-0000-0000-0000-000000000002"
        }
      ]

      response = %{"results" => [%{"status" => "SUCCESS"}]}

      expect_http_request_with_body(:post, "/v1/batch/references", :any, fn ->
        mock_success_response(response)
      end)

      assert {:ok, result} = Batch.add_references(references)
      assert Enum.at(result["results"], 0)["status"] == "SUCCESS"
    end
  end

  describe "integration tests" do
    @tag :integration
    test "batch create and delete workflow" do
      if integration_mode?() do
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
