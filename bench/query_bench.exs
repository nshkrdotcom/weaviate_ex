# Query Operations Benchmark
#
# Run with: mix weaviate.bench query
# Requires: Running Weaviate instance on localhost:8080
#
# Start Weaviate first:
#   mix weaviate.start
#
# Results saved to: bench/output/query.html

alias WeaviateEx.{Collections, Batch, Query}

IO.puts("Setting up query benchmark...")

# Connect to Weaviate
config = WeaviateEx.Connect.to_local()
{:ok, client} = WeaviateEx.Client.connect(config)

collection_name = "BenchmarkQuery"

# Cleanup any existing collection
Collections.delete(client, collection_name)

# Create test collection with no vectorizer (we provide vectors)
{:ok, _} =
  Collections.create(client, collection_name, %{
    vectorizer: "none",
    properties: [
      %{name: "title", dataType: ["text"]},
      %{name: "content", dataType: ["text"]},
      %{name: "category", dataType: ["text"]}
    ]
  })

IO.puts("Collection created: #{collection_name}")

# Generate and insert test data
IO.puts("Generating test data...")

categories = ["technology", "science", "business", "sports", "entertainment"]

objects =
  for i <- 1..10_000 do
    %{
      class: collection_name,
      properties: %{
        title: "Document #{i}: Important Information",
        content:
          "This is the content of document number #{i} with searchable text about various topics including machine learning, artificial intelligence, and data science.",
        category: Enum.at(categories, rem(i, 5))
      },
      vector: for(_ <- 1..128, do: :rand.uniform())
    }
  end

IO.puts("Inserting 10,000 objects in batches...")

# Insert in batches of 1000
objects
|> Enum.chunk_every(1000)
|> Enum.each(fn batch ->
  Batch.create_objects(client, batch)
  IO.write(".")
end)

IO.puts("\nData inserted. Waiting for indexing...")
Process.sleep(3000)

# Generate query vector for near_vector searches
query_vector = for(_ <- 1..128, do: :rand.uniform())

IO.puts("Starting benchmark...")

Benchee.run(
  %{
    "near_vector_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.near_vector(query_vector)
      |> Query.fields(["title", "content"])
      |> Query.limit(10)
      |> Query.execute(client)
    end,
    "near_vector_limit_100" => fn ->
      Query.get(collection_name)
      |> Query.near_vector(query_vector)
      |> Query.fields(["title", "content"])
      |> Query.limit(100)
      |> Query.execute(client)
    end,
    "bm25_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.bm25("machine learning artificial intelligence")
      |> Query.fields(["title", "content"])
      |> Query.limit(10)
      |> Query.execute(client)
    end,
    "bm25_limit_100" => fn ->
      Query.get(collection_name)
      |> Query.bm25("machine learning artificial intelligence")
      |> Query.fields(["title", "content"])
      |> Query.limit(100)
      |> Query.execute(client)
    end,
    "hybrid_limit_10" => fn ->
      Query.get(collection_name)
      |> Query.hybrid("document searchable text", alpha: 0.5)
      |> Query.fields(["title", "content"])
      |> Query.limit(10)
      |> Query.execute(client)
    end,
    "filtered_bm25" => fn ->
      Query.get(collection_name)
      |> Query.bm25("document information")
      |> Query.where(%{
        path: ["category"],
        operator: "Equal",
        valueText: "technology"
      })
      |> Query.fields(["title", "category"])
      |> Query.limit(10)
      |> Query.execute(client)
    end
  },
  time: 10,
  memory_time: 2,
  warmup: 2,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/query.html"},
    Benchee.Formatters.Console
  ]
)

# Cleanup
IO.puts("\nCleaning up...")
Collections.delete(client, collection_name)

IO.puts("\nBenchmark complete! See bench/output/query.html for detailed results.")
