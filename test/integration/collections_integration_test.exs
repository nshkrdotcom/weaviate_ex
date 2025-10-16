defmodule WeaviateEx.Integration.CollectionsTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.Collections

  @moduletag :integration

  setup do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create unique collection name for each test
    collection_name = "TestCol_#{:rand.uniform(999_999_999)}"

    # Clean up after test
    on_exit(fn ->
      Collections.delete(collection_name)
    end)

    {:ok, collection: collection_name}
  end

  describe "Collections.list/1 (live)" do
    test "lists all collections from real Weaviate" do
      assert {:ok, schema} = Collections.list()
      assert is_map(schema)
      assert Map.has_key?(schema, "classes") or is_list(schema)
    end
  end

  describe "Collections.create/3 (live)" do
    test "creates a new collection in Weaviate", %{collection: collection_name} do
      assert {:ok, collection} =
               Collections.create(collection_name, %{
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

      assert collection["class"] == collection_name
      assert is_list(collection["properties"])
      assert length(collection["properties"]) == 3
    end

    test "returns error for duplicate collection", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      # Try to create again - should fail
      assert {:error, error} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      assert error.status_code in [422, 409]
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
    test "retrieves an existing collection", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      assert {:ok, collection} = Collections.get(collection_name)
      assert collection["class"] == collection_name
      assert is_list(collection["properties"])
    end

    test "returns error for non-existent collection" do
      assert {:error, %WeaviateEx.Error{status_code: 404}} =
               Collections.get("NonExistentCollection999")
    end
  end

  describe "Collections.add_property/3 (live)" do
    test "adds a new property to existing collection", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field1", dataType: ["text"]}]
               })

      property = %{
        name: "testField#{System.system_time(:millisecond)}",
        dataType: ["text"],
        description: "Test field added during integration test"
      }

      assert {:ok, result} = Collections.add_property(collection_name, property)
      assert result["name"] == property.name
    end

    test "returns error when adding invalid property", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field1", dataType: ["text"]}]
               })

      assert {:error, error} =
               Collections.add_property(collection_name, %{
                 name: "invalid",
                 dataType: ["invalid_type"]
               })

      assert is_map(error)
    end
  end

  describe "Collections.get_shards/2 (live)" do
    test "retrieves shard information for collection", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      assert {:ok, shards} = Collections.get_shards(collection_name)
      assert is_list(shards) or is_map(shards)
    end
  end

  describe "Collections.delete/2 (live)" do
    test "deletes a collection", %{collection: collection_name} do
      # Create collection first
      assert {:ok, _} =
               Collections.create(collection_name, %{
                 properties: [%{name: "field", dataType: ["text"]}]
               })

      # Delete it
      assert {:ok, _} = Collections.delete(collection_name)

      # Verify it's deleted
      assert {:error, %WeaviateEx.Error{status_code: 404}} = Collections.get(collection_name)
    end

    test "returns success when deleting non-existent collection" do
      # Weaviate returns 204 No Content even for non-existent collections
      assert {:ok, _} = Collections.delete("NonExistent999")
    end
  end
end
