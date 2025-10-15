defmodule WeaviateEx.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.TestHelpers
  alias WeaviateEx.{Collections, Fixtures}

  setup :verify_on_exit!
  setup :setup_http_client

  describe "list/1" do
    test "returns all collections" do
      schema = %{
        "classes" => [
          Fixtures.collection_fixture("Article"),
          Fixtures.collection_fixture("Author")
        ]
      }

      expect_http_request(:get, "/v1/schema", fn ->
        mock_success_response(schema)
      end)

      assert {:ok, response} = Collections.list()
      assert length(response["classes"]) == 2
    end

    test "returns error on failure" do
      expect_http_request(:get, "/v1/schema", fn ->
        mock_error_response(500, "Internal server error")
      end)

      assert {:error, %{status: 500}} = Collections.list()
    end
  end

  describe "get/1" do
    test "returns a specific collection" do
      collection = Fixtures.collection_fixture("Article")

      expect_http_request(:get, "/v1/schema/Article", fn ->
        mock_success_response(collection)
      end)

      assert {:ok, result} = Collections.get("Article")
      assert result["class"] == "Article"
    end

    test "returns error when collection not found" do
      expect_http_request(:get, "/v1/schema/NonExistent", fn ->
        mock_error_response(404, "Collection not found")
      end)

      assert {:error, %{status: 404}} = Collections.get("NonExistent")
    end
  end

  describe "create/2" do
    test "creates a new collection" do
      collection = Fixtures.collection_fixture("Article")

      expect_http_request_with_body(:post, "/v1/schema", :any, fn ->
        mock_success_response(collection, 201)
      end)

      assert {:ok, result} =
               Collections.create("Article", %{
                 properties: [
                   %{name: "title", dataType: ["text"]},
                   %{name: "content", dataType: ["text"]}
                 ]
               })

      assert result["class"] == "Article"
    end

    test "returns error on invalid schema" do
      expect_http_request_with_body(:post, "/v1/schema", :any, fn ->
        mock_error_response(422, "Invalid property definition")
      end)

      assert {:error, %{status: 422}} = Collections.create("Article", %{})
    end
  end

  describe "update/2" do
    test "updates an existing collection" do
      collection = Fixtures.collection_fixture("Article")

      expect_http_request_with_body(:put, "/v1/schema/Article", :any, fn ->
        mock_success_response(collection)
      end)

      assert {:ok, result} =
               Collections.update("Article", %{
                 description: "Updated description"
               })

      assert result["class"] == "Article"
    end
  end

  describe "delete/1" do
    test "deletes a collection" do
      expect_http_request(:delete, "/v1/schema/Article", fn ->
        mock_success_response(%{})
      end)

      assert {:ok, _} = Collections.delete("Article")
    end

    test "returns error when collection not found" do
      expect_http_request(:delete, "/v1/schema/NonExistent", fn ->
        mock_error_response(404, "Collection not found")
      end)

      assert {:error, %{status: 404}} = Collections.delete("NonExistent")
    end
  end

  describe "add_property/3" do
    test "adds a property to a collection" do
      property = %{name: "author", dataType: ["text"]}

      expect_http_request_with_body(:post, "/v1/schema/Article/properties", :any, fn ->
        mock_success_response(property, 201)
      end)

      assert {:ok, result} = Collections.add_property("Article", property)
      assert result["name"] == "author"
    end
  end

  describe "integration tests" do
    @tag :integration
    test "full CRUD workflow" do
      if integration_mode?() do
        # Create
        {:ok, _} =
          Collections.create("TestArticle", %{
            properties: [%{name: "title", dataType: ["text"]}]
          })

        # Read
        {:ok, collection} = Collections.get("TestArticle")
        assert collection["class"] == "TestArticle"

        # Delete
        {:ok, _} = Collections.delete("TestArticle")
      else
        assert true
      end
    end
  end
end
