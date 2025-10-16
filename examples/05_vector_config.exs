# Vector Configuration Example
# Run: mix run examples/05_vector_config.exs

Mix.install([{:weaviate_ex, path: "."}])
Code.require_file("example_helper.exs", __DIR__)

alias WeaviateEx.API.{Collections, VectorConfig}
import ExampleHelper

ExampleHelper.check_weaviate!()

section("Vector Configuration - Vectorizers & Indexes")

{:ok, client} = WeaviateEx.Client.new("http://localhost:8080")

# Example 1: text2vec-openai with HNSW
step("Configure with OpenAI vectorizer + HNSW index")

config1 =
  VectorConfig.new("AIArticle")
  |> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-ada-002")
  |> VectorConfig.with_hnsw_index(
    distance: :cosine,
    ef: 100,
    max_connections: 64
  )
  |> VectorConfig.with_properties([
    %{"name" => "title", "dataType" => ["text"]},
    %{"name" => "content", "dataType" => ["text"]}
  ])

command(
  "VectorConfig.new(\"AIArticle\") |> with_vectorizer(:text2vec_openai) |> with_hnsw_index()"
)

result("Config", Map.take(config1, ["class", "vectorizer", "vectorIndexType"]))

{:ok, _} = Collections.create(client, config1)
success("Created AIArticle collection")

# Example 2: HNSW with Product Quantization
step("Configure with PQ compression")

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

command("with_product_quantization(enabled: true, segments: 96)")
result("PQ Config", config2["vectorIndexConfig"]["pq"])

{:ok, _} = Collections.create(client, config2)
success("Created CompressedData with PQ")

# Example 3: Multi-modal with CLIP
step("Configure multi-modal collection")

config3 =
  VectorConfig.new("MultiModal")
  |> VectorConfig.with_vectorizer(:multi2vec_clip,
    image_fields: ["photo"],
    text_fields: ["description"]
  )
  |> VectorConfig.with_flat_index(distance: :dot)
  |> VectorConfig.with_properties([
    %{"name" => "photo", "dataType" => ["blob"]},
    %{"name" => "description", "dataType" => ["text"]}
  ])

command("with_vectorizer(:multi2vec_clip, image_fields: [...], text_fields: [...])")
result("Multi-modal Config", config3["moduleConfig"])

{:ok, _} = Collections.create(client, config3)
success("Created MultiModal with CLIP")

# Cleanup
cleanup(client, "AIArticle")
cleanup(client, "CompressedData")
cleanup(client, "MultiModal")

IO.puts("\n#{green("✓")} Example complete!\n")
