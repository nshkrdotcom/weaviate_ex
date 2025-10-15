defmodule WeaviateEx.Integration.CollectionsTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.Collections

  @moduletag :integration

  # Unique test collection name to avoid conflicts
  @test_collection "WeaviateExTestCollection#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Clean up any existing test collection
    Collections.delete(@test_collection)
    :ok
  end

  describe "Collections.list/1 (live)" do
    test "lists all collections from real Weaviate" do
      assert {:ok, schema} = Collections.list()
      assert is_map(schema)
      assert Map.has_key?(schema, "classes") or is_list(schema)
    end
  end

  describe "Collections.create/3 (live)" do
    test "creates a new collection in Weaviate" do
      assert {:ok, collection} =
               Collections.create(@test_collection, %{
                 description: "Test collection for integration tests",
                 properties: [
                   %{
                     name: "title",
                     dataType: ["text"],
                     description: "The title of the article"
                   },
                   %{
                     name: "content",
                     dataType: ["text"],
                     description: "The content"
                   },
                   %{
                     name: "publishedAt",
                     dataType: ["date"],
                     description: "Publication date"
                   }
                 ],
                 vectorizer: "none"
               })

      assert collection["class"] == @test_collection
      assert is_list(collection["properties"])
      assert length(collection["properties"]) == 3
    end

    test "returns error for duplicate collection" do
      # Collection already exists from previous test
      assert {:error, error} =
               Collections.create(@test_collection, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      assert error[:status] in [422, 409]
    end

    test "returns error for invalid schema" do
      assert {:error, error} =
               Collections.create("Invalid_Class_Name", %{
                 properties: []
               })

      assert is_map(error)
    end
  end

  describe "Collections.get/2 (live)" do
    test "retrieves an existing collection" do
      assert {:ok, collection} = Collections.get(@test_collection)
      assert collection["class"] == @test_collection
      assert is_list(collection["properties"])
    end

    test "returns error for non-existent collection" do
      assert {:error, %{status: 404}} = Collections.get("NonExistentCollection999")
    end
  end

  describe "Collections.add_property/3 (live)" do
    test "adds a new property to existing collection" do
      property = %{
        name: "testField#{System.system_time(:millisecond)}",
        dataType: ["text"],
        description: "Test field added during integration test"
      }

      assert {:ok, result} = Collections.add_property(@test_collection, property)
      assert result["name"] == property.name
    end

    test "returns error when adding invalid property" do
      assert {:error, error} =
               Collections.add_property(@test_collection, %{
                 name: "invalid",
                 dataType: ["invalid_type"]
               })

      assert is_map(error)
    end
  end

  describe "Collections.get_shards/2 (live)" do
    test "retrieves shard information for collection" do
      assert {:ok, shards} = Collections.get_shards(@test_collection)
      assert is_list(shards) or is_map(shards)
    end
  end

  describe "Collections.delete/2 (live)" do
    test "deletes the test collection" do
      # This runs last to clean up
      assert {:ok, _} = Collections.delete(@test_collection)

      # Verify it's deleted
      assert {:error, %{status: 404}} = Collections.get(@test_collection)
    end

    test "returns success when deleting non-existent collection" do
      # Weaviate returns 204 No Content even for non-existent collections
      assert {:ok, _} = Collections.delete("NonExistent999")
    end
  end
end
