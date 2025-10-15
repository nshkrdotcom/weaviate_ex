defmodule WeaviateEx.Integration.BatchTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.{Collections, Batch, Objects}

  @moduletag :integration

  @test_collection "BatchIntegrationTest#{System.system_time(:millisecond)}"

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
          %{name: "category", dataType: ["text"]}
        ],
        vectorizer: "none"
      })

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    :ok
  end

  describe "Batch.create_objects/2 (live)" do
    test "creates multiple objects in batch" do
      objects =
        for i <- 1..10 do
          %{
            class: @test_collection,
            properties: %{
              title: "Batch Article #{i}",
              content: "Content #{i}",
              category: "batch_test"
            },
            vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
          }
        end

      assert {:ok, result} = Batch.create_objects(objects)
      assert is_map(result)
      assert length(result["results"]) == 10

      # Check all succeeded
      successful = Enum.count(result["results"], fn r -> r["result"]["status"] == "SUCCESS" end)
      assert successful == 10

      # Cleanup - batch delete
      Batch.delete_objects(%{
        class: @test_collection,
        where: %{path: ["category"], operator: "Equal", valueText: "batch_test"}
      })
    end

    test "handles objects with custom IDs" do
      objects =
        for i <- 1..3 do
          id = "#{i}0000000-0000-0000-0000-00000000000#{i}"

          %{
            class: @test_collection,
            id: id,
            properties: %{
              title: "Custom ID #{i}",
              content: "Content",
              category: "custom_id_test"
            }
          }
        end

      assert {:ok, result} = Batch.create_objects(objects)
      assert length(result["results"]) == 3

      # Verify IDs
      ids = Enum.map(result["results"], fn r -> r["id"] end)
      assert "10000000-0000-0000-0000-000000000001" in ids
      assert "20000000-0000-0000-0000-000000000002" in ids
      assert "30000000-0000-0000-0000-000000000003" in ids

      # Cleanup
      Batch.delete_objects(%{
        class: @test_collection,
        where: %{path: ["category"], operator: "Equal", valueText: "custom_id_test"}
      })
    end

    test "handles partial failures gracefully" do
      objects = [
        # Valid object
        %{
          class: @test_collection,
          properties: %{title: "Valid", content: "Valid", category: "mixed"}
        },
        # Invalid - missing required field (should still process others)
        %{
          class: @test_collection,
          properties: %{invalidField: "Invalid"}
        },
        # Another valid object
        %{
          class: @test_collection,
          properties: %{title: "Valid 2", content: "Valid", category: "mixed"}
        }
      ]

      assert {:ok, result} = Batch.create_objects(objects)
      assert length(result["results"]) == 3

      # Should have at least some successes
      successes = Enum.count(result["results"], fn r -> r["result"]["status"] == "SUCCESS" end)
      assert successes >= 1

      # Cleanup
      Batch.delete_objects(%{
        class: @test_collection,
        where: %{path: ["category"], operator: "Equal", valueText: "mixed"}
      })
    end
  end

  describe "Batch.delete_objects/2 (live)" do
    setup do
      # Create test objects
      objects =
        for i <- 1..15 do
          %{
            class: @test_collection,
            properties: %{
              title: "Delete Test #{i}",
              content: "Content",
              category: "delete_test_#{rem(i, 3)}"
            }
          }
        end

      {:ok, _} = Batch.create_objects(objects)

      :ok
    end

    test "deletes objects matching criteria" do
      assert {:ok, result} =
               Batch.delete_objects(%{
                 class: @test_collection,
                 where: %{
                   path: ["category"],
                   operator: "Equal",
                   valueText: "delete_test_0"
                 }
               })

      assert is_map(result)
      assert result["results"]["successful"] >= 5
      assert result["results"]["failed"] == 0
    end

    test "deletes with complex where clause" do
      # Delete all remaining test objects
      assert {:ok, result} =
               Batch.delete_objects(%{
                 class: @test_collection,
                 where: %{
                   path: ["title"],
                   operator: "Like",
                   valueText: "Delete Test*"
                 }
               })

      assert result["results"]["successful"] >= 1
    end

    test "returns appropriate result for no matches" do
      result =
        Batch.delete_objects(%{
          class: @test_collection,
          where: %{
            path: ["category"],
            operator: "Equal",
            valueText: "nonexistent_category_999"
          }
        })

      # Should succeed but with 0 matches
      assert {:ok, res} = result
      assert res["results"]["matches"] == 0
    end
  end

  describe "Batch.add_references/2 (live)" do
    test "adds cross-references in batch" do
      # Create two test collections with references
      ref_collection = "RefTest#{System.system_time(:millisecond)}"

      {:ok, _} =
        Collections.create(ref_collection, %{
          properties: [
            %{name: "name", dataType: ["text"]},
            %{name: "articles", dataType: [@test_collection]}
          ],
          vectorizer: "none"
        })

      # Create objects
      {:ok, article} =
        Objects.create(@test_collection, %{
          properties: %{title: "Article", content: "Content", category: "ref"}
        })

      {:ok, author} =
        Objects.create(ref_collection, %{
          properties: %{name: "Test Author"}
        })

      # Add reference
      references = [
        %{
          from: "weaviate://localhost/#{ref_collection}/#{author["id"]}/articles",
          to: "weaviate://localhost/#{@test_collection}/#{article["id"]}"
        }
      ]

      assert {:ok, result} = Batch.add_references(references)
      assert is_map(result)
      assert length(result["results"]) == 1

      # Cleanup
      Objects.delete(@test_collection, article["id"])
      Objects.delete(ref_collection, author["id"])
      Collections.delete(ref_collection)
    end
  end
end
