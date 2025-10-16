defmodule WeaviateEx.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.API.Collections
  alias WeaviateEx.Fixtures
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list/1" do
    test "returns all collections", %{client: client} do
      schema = %{
        "classes" => [
          Fixtures.collection_fixture("Article"),
          Fixtures.collection_fixture("Author")
        ]
      }

      expect_http_success(Mock, :get, "/v1/schema", schema)

      assert {:ok, collection_names} = Collections.list(client)
      assert length(collection_names) == 2
      assert "Article" in collection_names
      assert "Author" in collection_names
    end

    test "returns error on failure", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema", :server_error)

      assert {:error, %WeaviateEx.Error{type: :server_error}} = Collections.list(client)
    end
  end

  describe "get/2" do
    test "returns a specific collection", %{client: client} do
      collection = Fixtures.collection_fixture("Article")

      expect_http_success(Mock, :get, "/v1/schema/Article", collection)

      assert {:ok, result} = Collections.get(client, "Article")
      assert result["class"] == "Article"
    end

    test "returns error when collection not found", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Collections.get(client, "NonExistent")
    end
  end

  describe "create/2" do
    test "creates a new collection", %{client: client} do
      config = %{
        "class" => "Article",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]},
          %{"name" => "content", "dataType" => ["text"]}
        ]
      }

      collection = Fixtures.collection_fixture("Article")

      Mox.expect(Mock, :request, fn _client, :post, "/v1/schema", ^config, _opts ->
        {:ok, collection}
      end)

      assert {:ok, result} = Collections.create(client, config)
      assert result["class"] == "Article"
    end

    test "returns error on invalid schema", %{client: client} do
      config = %{"class" => "Article"}

      Mox.expect(Mock, :request, fn _client, :post, "/v1/schema", ^config, _opts ->
        {:error,
         %WeaviateEx.Error{
           type: :validation_error,
           message: "Invalid property definition",
           details: %{},
           status_code: 422
         }}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               Collections.create(client, config)
    end
  end

  describe "update/3" do
    test "updates an existing collection", %{client: client} do
      updates = %{"description" => "Updated description"}
      updated_collection = Fixtures.collection_fixture("Article")

      Mox.expect(Mock, :request, fn _client, :put, "/v1/schema/Article", ^updates, _opts ->
        {:ok, updated_collection}
      end)

      assert {:ok, result} = Collections.update(client, "Article", updates)
      assert result["class"] == "Article"
    end
  end

  describe "delete/2" do
    test "deletes a collection", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :delete, "/v1/schema/Article", nil, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, _} = Collections.delete(client, "Article")
    end

    test "returns error when collection not found", %{client: client} do
      expect_http_error(Mock, :delete, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
               Collections.delete(client, "NonExistent")
    end
  end

  describe "add_property/3" do
    test "adds a property to a collection", %{client: client} do
      property = %{"name" => "author", "dataType" => ["text"]}

      Mox.expect(Mock, :request, fn _client,
                                    :post,
                                    "/v1/schema/Article/properties",
                                    ^property,
                                    _opts ->
        {:ok, property}
      end)

      assert {:ok, result} = Collections.add_property(client, "Article", property)
      assert result["name"] == "author"
    end
  end

  describe "integration tests" do
    @tag :integration
    test "full CRUD workflow" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        {:ok, client} =
          WeaviateEx.Client.new(
            base_url: WeaviateEx.base_url(),
            api_key: WeaviateEx.api_key()
          )

        # Create
        {:ok, _} =
          Collections.create(client, %{
            "class" => "TestArticle",
            "properties" => [%{"name" => "title", "dataType" => ["text"]}]
          })

        # Read
        {:ok, collection} = Collections.get(client, "TestArticle")
        assert collection["class"] == "TestArticle"

        # Delete
        {:ok, _} = Collections.delete(client, "TestArticle")
      else
        assert true
      end
    end
  end
end
