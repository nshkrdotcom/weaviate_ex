Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

alias WeaviateEx.{Collections, Batch, Objects, Query}

# Create test collection
collection_name = "DebugTest#{System.system_time(:millisecond)}"

IO.puts("\n=== Creating collection ===")

{:ok, _} =
  Collections.create(collection_name, %{
    properties: [
      %{name: "title", dataType: ["text"]},
      %{name: "content", dataType: ["text"]}
    ],
    vectorizer: "none"
  })

# Test batch create
IO.puts("\n=== Testing Batch.create_objects ===")

objects = [
  %{
    class: collection_name,
    properties: %{
      title: "Test 1",
      content: "Content 1"
    }
  },
  %{
    class: collection_name,
    properties: %{
      title: "Test 2",
      content: "Content 2"
    }
  }
]

result = Batch.create_objects(objects)
IO.inspect(result, label: "Batch create result", limit: :infinity, pretty: true)

# Test Query
IO.puts("\n=== Testing Query ===")

query_result =
  Query.get(collection_name)
  |> Query.fields(["title"])
  |> Query.limit(5)
  |> Query.execute()

IO.inspect(query_result, label: "Query result", limit: :infinity, pretty: true)

# Test Objects.patch
IO.puts("\n=== Testing Objects.patch ===")

{:ok, obj} =
  Objects.create(collection_name, %{
    properties: %{title: "Original", content: "Content"}
  })

IO.puts("Created object ID: #{obj["id"]}")

patch_result =
  Objects.patch(collection_name, obj["id"], %{
    properties: %{title: "Patched"}
  })

IO.inspect(patch_result, label: "Patch result", limit: :infinity, pretty: true)

# Test Objects.delete non-existent
IO.puts("\n=== Testing Objects.delete (non-existent) ===")
delete_result = Objects.delete(collection_name, "00000000-0000-0000-0000-999999999999")
IO.inspect(delete_result, label: "Delete non-existent result")

# Test Collections.delete non-existent
IO.puts("\n=== Testing Collections.delete (non-existent) ===")
delete_coll_result = Collections.delete("NonExistent999")
IO.inspect(delete_coll_result, label: "Delete non-existent collection result")

# Cleanup
Collections.delete(collection_name)

IO.puts("\n=== Done ===")
