# Vector Configuration Example
# Run: mix run examples/05_vector_config.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, VectorConfig}

ExampleHelper.check_weaviate!()

ExampleHelper.section("Vector Configuration - Vectorizers & Indexes")

{:ok, client} = WeaviateEx.Client.new(base_url: "http://localhost:8080")

# Example 1: None vectorizer with HNSW (bring your own vectors)
ExampleHelper.step("Configure with custom vectors + HNSW index")

config1 =
  VectorConfig.new("AIArticle")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_hnsw_index(
    distance: :cosine,
    ef: 100,
    max_connections: 64
  )
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]}
  ])

ExampleHelper.command(
  "VectorConfig.new(\"AIArticle\") |> with_vectorizer(:none) |> with_hnsw_index()"
)

ExampleHelper.result("Config", Map.take(config1, ["class", "vectorizer", "vectorIndexType"]))

{:ok, _} = Collections.create(client, config1)
ExampleHelper.success("Created AIArticle collection")

# Example 2: HNSW with Product Quantization
ExampleHelper.step("Configure with PQ compression")

config2 =
  VectorConfig.new("CompressedData")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_hnsw_index(distance: :cosine)
  |> VectorConfig.with_product_quantization(
    enabled: true,
    segments: 96,
    centroids: 256
  )
  |> VectorConfig.with_properties([
    %{"name" => "data", "dataType" => ["text"]}
  ])

ExampleHelper.command("with_product_quantization(enabled: true, segments: 96)")
ExampleHelper.result("PQ Config", config2["vectorIndexConfig"]["pq"])

{:ok, _} = Collections.create(client, config2)
ExampleHelper.success("Created CompressedData with PQ")

# Example 3: Flat index for exact search
ExampleHelper.step("Configure flat index for exact search")

config3 =
  VectorConfig.new("ExactSearch")
  |> VectorConfig.with_vectorizer(:none)
  |> VectorConfig.with_flat_index(distance: :dot)
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "description", "dataType" => ["text"]}
  ])

ExampleHelper.command("with_vectorizer(:none) |> with_flat_index(distance: :dot)")
ExampleHelper.result("Flat Index Config", Map.take(config3, ["class", "vectorIndexType"]))

{:ok, _} = Collections.create(client, config3)
ExampleHelper.success("Created ExactSearch with flat index")

# Cleanup
ExampleHelper.cleanup(client, "AIArticle")
ExampleHelper.cleanup(client, "CompressedData")
ExampleHelper.cleanup(client, "ExactSearch")

IO.puts("\n#{ExampleHelper.green("✓")} Example complete!\n")
