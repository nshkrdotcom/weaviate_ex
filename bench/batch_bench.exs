# Batch Operations Benchmark
#
# Run with: mix weaviate.bench batch
# Requires: Running Weaviate instance on localhost:8080
#
# Start Weaviate first:
#   mix weaviate.start
#
# Results saved to: bench/output/batch.html

alias WeaviateEx.{Collections, Batch}

IO.puts("Setting up batch benchmark...")

# Connect to Weaviate
config = WeaviateEx.Connect.to_local()
{:ok, client} = WeaviateEx.Client.connect(config)

collection_name = "BenchmarkBatch"

# Cleanup any existing collection
Collections.delete(client, collection_name)

# Create test collection with no vectorizer (fastest for benchmarking)
{:ok, _} =
  Collections.create(client, collection_name, %{
    vectorizer: "none",
    properties: [
      %{name: "index", dataType: ["int"]},
      %{name: "data", dataType: ["text"]}
    ]
  })

IO.puts("Collection created: #{collection_name}")

# Generate test data with pre-computed vectors
generate_objects = fn count ->
  for i <- 1..count do
    %{
      class: collection_name,
      properties: %{index: i, data: "Test data #{i} with some additional content for realism"},
      vector: for(_ <- 1..128, do: :rand.uniform())
    }
  end
end

# Pre-generate test data sets
IO.puts("Generating test data sets...")
objects_100 = generate_objects.(100)
objects_500 = generate_objects.(500)
objects_1000 = generate_objects.(1000)

IO.puts("Starting benchmark...")

Benchee.run(
  %{
    "batch_100_objects" => fn ->
      Batch.create_objects(client, objects_100)
    end,
    "batch_500_objects" => fn ->
      Batch.create_objects(client, objects_500)
    end,
    "batch_1000_objects" => fn ->
      Batch.create_objects(client, objects_1000)
    end
  },
  time: 10,
  memory_time: 2,
  warmup: 2,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/batch.html"},
    Benchee.Formatters.Console
  ],
  before_each: fn input ->
    # Clear collection before each run
    Batch.delete_objects(client, %{
      class: collection_name,
      where: %{operator: "Like", path: ["data"], valueText: "*"}
    })

    # Small delay to ensure cleanup is complete
    Process.sleep(100)
    input
  end
)

# Cleanup
IO.puts("\nCleaning up...")
Collections.delete(client, collection_name)

IO.puts("\nBenchmark complete! See bench/output/batch.html for detailed results.")
