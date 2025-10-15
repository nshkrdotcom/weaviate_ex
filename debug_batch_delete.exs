Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

alias WeaviateEx.{Collections, Batch, Objects}

# Create test collection
collection_name = "BatchDeleteTest#{System.system_time(:millisecond)}"

IO.puts("\n=== Creating collection ===")

{:ok, _} =
  Collections.create(collection_name, %{
    properties: [
      %{name: "title", dataType: ["text"]},
      %{name: "category", dataType: ["text"]}
    ],
    vectorizer: "none"
  })

# Create objects
IO.puts("\n=== Creating objects ===")

objects =
  for i <- 1..5 do
    %{
      class: collection_name,
      properties: %{
        title: "Test #{i}",
        category: "test_cat"
      }
    }
  end

{:ok, result} = Batch.create_objects(objects)
IO.puts("Created #{length(result["results"])} objects")

# Try batch delete
IO.puts("\n=== Testing Batch.delete_objects ===")

delete_result =
  Batch.delete_objects(%{
    class: collection_name,
    where: %{
      path: ["category"],
      operator: "Equal",
      valueText: "test_cat"
    }
  })

IO.inspect(delete_result, label: "Delete result", limit: :infinity, pretty: true)

# Cleanup
Collections.delete(collection_name)

IO.puts("\n=== Done ===")
