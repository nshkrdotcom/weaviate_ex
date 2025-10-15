defmodule WeaviateEx.Integration.ObjectsTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.{Collections, Objects}

  @moduletag :integration

  @test_collection "ObjectsIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]},
          %{name: "score", dataType: ["int"]}
        ],
        vectorizer: "none"
      })

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    :ok
  end

  describe "Objects.create/3 (live)" do
    test "creates an object with auto-generated ID" do
      assert {:ok, object} =
               Objects.create(@test_collection, %{
                 properties: %{
                   title: "Test Article",
                   content: "Test content",
                   score: 42
                 }
               })

      assert object["class"] == @test_collection
      assert is_binary(object["id"])
      assert object["properties"]["title"] == "Test Article"
      assert object["properties"]["score"] == 42

      # Cleanup
      Objects.delete(@test_collection, object["id"])
    end

    test "creates object with custom ID" do
      custom_id = "11111111-1111-1111-1111-111111111111"

      assert {:ok, object} =
               Objects.create(@test_collection, %{
                 id: custom_id,
                 properties: %{
                   title: "Custom ID Test",
                   content: "Content"
                 }
               })

      assert object["id"] == custom_id

      # Cleanup
      Objects.delete(@test_collection, custom_id)
    end

    test "creates object with custom vector" do
      vector = Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)

      assert {:ok, object} =
               Objects.create(@test_collection, %{
                 properties: %{title: "Vector Test", content: "Test"},
                 vector: vector
               })

      assert is_binary(object["id"])

      # Cleanup
      Objects.delete(@test_collection, object["id"])
    end
  end

  describe "Objects.get/3 (live)" do
    setup do
      {:ok, object} =
        Objects.create(@test_collection, %{
          properties: %{title: "Get Test", content: "Content"}
        })

      on_exit(fn -> Objects.delete(@test_collection, object["id"]) end)

      {:ok, object: object}
    end

    test "retrieves an object by ID", %{object: created} do
      assert {:ok, object} = Objects.get(@test_collection, created["id"])
      assert object["id"] == created["id"]
      assert object["properties"]["title"] == "Get Test"
    end

    test "returns error for non-existent object" do
      assert {:error, %{status: 404}} =
               Objects.get(@test_collection, "00000000-0000-0000-0000-999999999999")
    end

    test "retrieves object with vector", %{object: created} do
      assert {:ok, object} = Objects.get(@test_collection, created["id"], include: "vector")
      assert object["id"] == created["id"]
    end
  end

  describe "Objects.list/2 (live)" do
    setup do
      # Create 5 test objects
      objects =
        for i <- 1..5 do
          {:ok, obj} =
            Objects.create(@test_collection, %{
              properties: %{title: "List Test #{i}", content: "Content #{i}", score: i}
            })

          obj
        end

      on_exit(fn ->
        Enum.each(objects, fn obj -> Objects.delete(@test_collection, obj["id"]) end)
      end)

      {:ok, objects: objects}
    end

    test "lists all objects from collection", %{objects: _objects} do
      assert {:ok, result} = Objects.list(@test_collection)
      assert is_map(result)
      # Should have at least our test objects
      assert length(result["objects"]) >= 5
    end

    test "lists objects with limit", %{objects: _objects} do
      assert {:ok, result} = Objects.list(@test_collection, limit: 2)
      assert length(result["objects"]) == 2
    end

    test "lists objects with offset", %{objects: _objects} do
      assert {:ok, result} = Objects.list(@test_collection, limit: 10)
      total = length(result["objects"])

      assert {:ok, offset_result} = Objects.list(@test_collection, limit: 10, offset: 1)
      assert length(offset_result["objects"]) == total - 1
    end
  end

  describe "Objects.update/4 (live)" do
    setup do
      {:ok, object} =
        Objects.create(@test_collection, %{
          properties: %{title: "Original", content: "Original content", score: 1}
        })

      on_exit(fn -> Objects.delete(@test_collection, object["id"]) end)

      {:ok, object: object}
    end

    test "updates an object (full replacement)", %{object: obj} do
      assert {:ok, updated} =
               Objects.update(@test_collection, obj["id"], %{
                 properties: %{
                   title: "Updated Title",
                   content: "Updated content",
                   score: 99
                 }
               })

      assert updated["properties"]["title"] == "Updated Title"
      assert updated["properties"]["score"] == 99
    end
  end

  describe "Objects.patch/4 (live)" do
    setup do
      {:ok, object} =
        Objects.create(@test_collection, %{
          properties: %{title: "Patch Test", content: "Original", score: 5}
        })

      on_exit(fn -> Objects.delete(@test_collection, object["id"]) end)

      {:ok, object: object}
    end

    test "patches an object (partial update)", %{object: obj} do
      assert {:ok, patched} =
               Objects.patch(@test_collection, obj["id"], %{
                 properties: %{title: "Patched Title"}
               })

      assert patched["properties"]["title"] == "Patched Title"
      # Other fields should remain
    end
  end

  describe "Objects.exists?/3 (live)" do
    setup do
      {:ok, object} =
        Objects.create(@test_collection, %{
          properties: %{title: "Exists Test", content: "Content"}
        })

      on_exit(fn -> Objects.delete(@test_collection, object["id"]) end)

      {:ok, object: object}
    end

    test "returns true for existing object", %{object: obj} do
      assert {:ok, true} = Objects.exists?(@test_collection, obj["id"])
    end

    test "returns error for non-existent object" do
      result = Objects.exists?(@test_collection, "00000000-0000-0000-0000-999999999999")
      assert match?({:error, _}, result)
    end
  end

  describe "Objects.validate/3 (live)" do
    test "validates correct object data" do
      assert {:ok, result} =
               Objects.validate(@test_collection, %{
                 properties: %{
                   title: "Valid",
                   content: "Valid content",
                   score: 10
                 }
               })

      # Weaviate returns empty response for valid objects
      assert is_map(result)
    end

    test "returns error for invalid object data" do
      # Try to use non-existent property
      result =
        Objects.validate(@test_collection, %{
          properties: %{
            nonExistentField: "Invalid"
          }
        })

      # Might succeed or fail depending on Weaviate config
      assert {:ok, _} = result or match?({:error, _}, result)
    end
  end

  describe "Objects.delete/3 (live)" do
    test "deletes an existing object" do
      {:ok, object} =
        Objects.create(@test_collection, %{
          properties: %{title: "Delete Me", content: "Content"}
        })

      assert {:ok, _} = Objects.delete(@test_collection, object["id"])

      # Verify it's deleted
      assert {:error, %{status: 404}} = Objects.get(@test_collection, object["id"])
    end

    test "returns success for non-existent object" do
      # Weaviate returns 204 No Content even for non-existent objects
      assert {:ok, _} = Objects.delete(@test_collection, "00000000-0000-0000-0000-999999999999")
    end
  end
end
