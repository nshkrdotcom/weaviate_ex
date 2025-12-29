defmodule WeaviateEx.API.ReferencesTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.References
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
  end

  describe "replace/6" do
    test "replaces all references", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :put, path, body, _opts ->
        assert path == "/v1/objects/Article/source-uuid/references/hasAuthors"
        assert is_list(body)
        assert length(body) == 3
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
  end

  describe "add_many/4" do
    test "adds multiple references in batch", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path == "/v1/batch/references"
        assert is_list(body)
        assert length(body) == 2
        {:ok, %{}}
      end)

      references = [
        %{from_uuid: "article-uuid-1", from_property: "hasAuthor", to_uuid: "author-uuid-1"},
        %{from_uuid: "article-uuid-2", from_property: "hasAuthor", to_uuid: "author-uuid-2"}
      ]

      assert {:ok, _} = References.add_many(client, "Article", references)
    end
  end
end
