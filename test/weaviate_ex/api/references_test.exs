defmodule WeaviateEx.API.ReferencesTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.References
  alias WeaviateEx.Data.ReferenceToMulti
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "add/6" do
    test "adds single reference", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/hasAuthor"
        assert body == %{"beacon" => "weaviate://localhost/target-uuid"}
        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.add(client, "Article", "source-uuid", "hasAuthor", "target-uuid")
    end

    test "adds multi-target reference", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert body == %{"beacon" => "weaviate://localhost/Category/cat-uuid"}
        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.add(client, "Article", "source-uuid", "relatedTo", %{
                 target_collection: "Category",
                 uuids: "cat-uuid"
               })
    end

    test "adds multi-target reference using ReferenceToMulti struct", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert body == %{"beacon" => "weaviate://localhost/Category/cat-uuid"}
        {:ok, %{}}
      end)

      ref = ReferenceToMulti.new("Category", "cat-uuid")

      assert {:ok, _} =
               References.add(client, "Article", "source-uuid", "relatedTo", ref)
    end

    test "adds multi-target reference with multiple UUIDs using ReferenceToMulti", %{
      client: client
    } do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        # When multiple UUIDs, should return first beacon for add operation
        assert body == [
                 %{"beacon" => "weaviate://localhost/Category/uuid1"},
                 %{"beacon" => "weaviate://localhost/Category/uuid2"}
               ]

        {:ok, %{}}
      end)

      ref = ReferenceToMulti.new("Category", ["uuid1", "uuid2"])

      assert {:ok, _} =
               References.add(client, "Article", "source-uuid", "relatedTo", ref)
    end

    test "returns error on server error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :server_error, message: "Internal error"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :server_error}} =
               References.add(client, "Article", "source-uuid", "hasAuthor", "target-uuid")
    end

    test "returns error when object not found", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Object not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               References.add(client, "Article", "invalid-uuid", "hasAuthor", "target-uuid")
    end
  end

  describe "delete/6" do
    test "deletes single reference", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/hasAuthor"
        assert body == %{"beacon" => "weaviate://localhost/target-uuid"}
        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.delete(client, "Article", "source-uuid", "hasAuthor", "target-uuid")
    end

    test "deletes multi-target reference", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert body == %{"beacon" => "weaviate://localhost/Category/cat-uuid"}
        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.delete(client, "Article", "source-uuid", "relatedTo", %{
                 target_collection: "Category",
                 uuids: "cat-uuid"
               })
    end

    test "deletes multi-target reference using ReferenceToMulti struct", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert body == %{"beacon" => "weaviate://localhost/Category/cat-uuid"}
        {:ok, %{}}
      end)

      ref = ReferenceToMulti.new("Category", "cat-uuid")

      assert {:ok, _} =
               References.delete(client, "Article", "source-uuid", "relatedTo", ref)
    end

    test "returns error when reference not found", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Reference not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               References.delete(client, "Article", "source-uuid", "hasAuthor", "non-existent")
    end
  end

  describe "replace/6" do
    test "replaces all references with list of UUIDs", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/hasAuthors"
        assert is_list(body)
        assert length(body) == 3

        # Verify each beacon is correctly formatted
        assert Enum.all?(body, fn ref ->
                 Map.has_key?(ref, "beacon") and
                   String.starts_with?(ref["beacon"], "weaviate://localhost/")
               end)

        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.replace(
                 client,
                 "Article",
                 "source-uuid",
                 "hasAuthors",
                 ["uuid1", "uuid2", "uuid3"]
               )
    end

    test "replaces references with empty list to clear all", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/hasAuthors"
        assert body == []
        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.replace(
                 client,
                 "Article",
                 "source-uuid",
                 "hasAuthors",
                 []
               )
    end

    test "replaces references with multi-target references", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert is_list(body)
        # Multi-target with 2 UUIDs should produce 2 beacons
        assert length(body) == 2

        # Verify beacons include collection name
        assert Enum.all?(body, fn ref ->
                 String.contains?(ref["beacon"], "/Category/")
               end)

        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.replace(
                 client,
                 "Article",
                 "source-uuid",
                 "relatedTo",
                 [
                   %{target_collection: "Category", uuids: ["cat-uuid-1", "cat-uuid-2"]}
                 ]
               )
    end

    test "replaces references using ReferenceToMulti structs", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/relatedTo"
        assert is_list(body)
        # Two ReferenceToMulti each with 1 UUID
        assert length(body) == 2

        # Verify beacons include different collections
        assert Enum.any?(body, &String.contains?(&1["beacon"], "/Person/"))
        assert Enum.any?(body, &String.contains?(&1["beacon"], "/Organization/"))

        {:ok, %{}}
      end)

      assert {:ok, _} =
               References.replace(
                 client,
                 "Article",
                 "source-uuid",
                 "relatedTo",
                 [
                   ReferenceToMulti.new("Person", "person-uuid"),
                   ReferenceToMulti.new("Organization", "org-uuid")
                 ]
               )
    end

    test "returns error when object not found", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :not_found, message: "Object not found"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               References.replace(
                 client,
                 "Article",
                 "invalid-uuid",
                 "hasAuthors",
                 ["uuid1"]
               )
    end
  end

  describe "add_many/4" do
    test "adds multiple references in batch", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/batch/references"
        assert is_list(body)
        assert length(body) == 2

        # Verify batch reference format
        Enum.each(body, fn ref ->
          assert Map.has_key?(ref, "from")
          assert Map.has_key?(ref, "to")
          assert String.starts_with?(ref["from"], "weaviate://localhost/Article/")
          assert String.starts_with?(ref["to"], "weaviate://localhost/")
        end)

        {:ok, %{}}
      end)

      references = [
        %{from_uuid: "article-uuid-1", from_property: "hasAuthor", to_uuid: "author-uuid-1"},
        %{from_uuid: "article-uuid-2", from_property: "hasAuthor", to_uuid: "author-uuid-2"}
      ]

      assert {:ok, _} = References.add_many(client, "Article", references)
    end

    test "adds batch references with multi-target specification", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/batch/references"
        assert is_list(body)
        assert length(body) == 2

        # First ref should be simple, second should include target collection
        [first, second] = body
        assert first["to"] == "weaviate://localhost/author-uuid-1"
        assert second["to"] == "weaviate://localhost/Category/cat-uuid-1"

        {:ok, %{}}
      end)

      references = [
        %{from_uuid: "article-uuid-1", from_property: "hasAuthor", to_uuid: "author-uuid-1"},
        %{
          from_uuid: "article-uuid-2",
          from_property: "relatedTo",
          to_uuid: "cat-uuid-1",
          target_collection: "Category"
        }
      ]

      assert {:ok, _} = References.add_many(client, "Article", references)
    end

    test "handles empty references list", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/batch/references"
        assert body == []
        {:ok, %{}}
      end)

      assert {:ok, _} = References.add_many(client, "Article", [])
    end

    test "returns error on batch failure", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :server_error, message: "Batch failed"}}
      end)

      references = [
        %{from_uuid: "article-1", from_property: "hasAuthor", to_uuid: "author-1"}
      ]

      assert {:error, %WeaviateEx.Error{type: :server_error}} =
               References.add_many(client, "Article", references)
    end

    test "returns partial failure response from server", %{client: client} do
      # Weaviate can return successful HTTP response with partial failures in body
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok,
         [
           %{"result" => %{"status" => "SUCCESS"}},
           %{
             "result" => %{
               "status" => "FAILED",
               "errors" => %{"error" => [%{"message" => "Object not found"}]}
             }
           }
         ]}
      end)

      references = [
        %{from_uuid: "article-1", from_property: "hasAuthor", to_uuid: "author-1"},
        %{from_uuid: "article-2", from_property: "hasAuthor", to_uuid: "invalid-author"}
      ]

      {:ok, result} = References.add_many(client, "Article", references)
      assert is_list(result)
      assert length(result) == 2
    end
  end
end
