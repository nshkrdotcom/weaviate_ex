defmodule WeaviateEx.API.VectorConfigTest do
  @moduledoc """
  Tests for vector configuration builders (Phase 2.4).

  Following TDD approach - tests written first, then stub, then implementation.
  """

  use ExUnit.Case, async: true

  alias WeaviateEx.API.VectorConfig

  describe "vectorizer configurations" do
    test "text2vec-openai configuration" do
      config = VectorConfig.text2vec_openai(model: "text-embedding-ada-002")

      assert config["vectorizer"] == "text2vec-openai"
      assert config["moduleConfig"]["text2vec-openai"]["model"] == "text-embedding-ada-002"
    end

    test "text2vec-cohere configuration" do
      config = VectorConfig.text2vec_cohere(model: "embed-english-v3.0")

      assert config["vectorizer"] == "text2vec-cohere"
      assert config["moduleConfig"]["text2vec-cohere"]["model"] == "embed-english-v3.0"
    end

    test "text2vec-huggingface configuration" do
      config =
        VectorConfig.text2vec_huggingface(
          model: "sentence-transformers/all-MiniLM-L6-v2",
          options: %{"waitForModel" => true}
        )

      assert config["vectorizer"] == "text2vec-huggingface"
      assert config["moduleConfig"]["text2vec-huggingface"]["model"] =~ "sentence-transformers"
    end

    test "text2vec-transformers configuration" do
      config = VectorConfig.text2vec_transformers(pooling_strategy: "masked_mean")

      assert config["vectorizer"] == "text2vec-transformers"

      assert config["moduleConfig"]["text2vec-transformers"]["poolingStrategy"] ==
               "masked_mean"
    end

    test "text2vec-contextionary configuration" do
      config = VectorConfig.text2vec_contextionary(vectorize_class_name: true)

      assert config["vectorizer"] == "text2vec-contextionary"

      assert config["moduleConfig"]["text2vec-contextionary"]["vectorizeClassName"] ==
               true
    end

    test "text2vec-gpt4all configuration" do
      config = VectorConfig.text2vec_gpt4all()

      assert config["vectorizer"] == "text2vec-gpt4all"
    end

    test "text2vec-palm configuration" do
      config = VectorConfig.text2vec_palm(model_id: "textembedding-gecko@001")

      assert config["vectorizer"] == "text2vec-palm"
      assert config["moduleConfig"]["text2vec-palm"]["modelId"] == "textembedding-gecko@001"
    end

    test "text2vec-aws configuration" do
      config = VectorConfig.text2vec_aws(service: "bedrock", region: "us-east-1")

      assert config["vectorizer"] == "text2vec-aws"
      assert config["moduleConfig"]["text2vec-aws"]["service"] == "bedrock"
      assert config["moduleConfig"]["text2vec-aws"]["region"] == "us-east-1"
    end

    test "multi2vec-clip configuration" do
      config = VectorConfig.multi2vec_clip(image_fields: ["image"], text_fields: ["title"])

      assert config["vectorizer"] == "multi2vec-clip"
      assert config["moduleConfig"]["multi2vec-clip"]["imageFields"] == ["image"]
      assert config["moduleConfig"]["multi2vec-clip"]["textFields"] == ["title"]
    end

    test "multi2vec-bind configuration" do
      config =
        VectorConfig.multi2vec_bind(
          image_fields: ["photo"],
          text_fields: ["description"],
          audio_fields: ["audio"]
        )

      assert config["vectorizer"] == "multi2vec-bind"
      assert config["moduleConfig"]["multi2vec-bind"]["imageFields"] == ["photo"]
      assert config["moduleConfig"]["multi2vec-bind"]["audioFields"] == ["audio"]
    end

    test "none vectorizer (custom vectors)" do
      config = VectorConfig.none()

      assert config["vectorizer"] == "none"
      refute Map.has_key?(config, "moduleConfig")
    end
  end

  describe "vector index configurations" do
    test "HNSW index with default settings" do
      config = VectorConfig.hnsw_index()

      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["distance"] == "cosine"
    end

    test "HNSW index with custom settings" do
      config =
        VectorConfig.hnsw_index(
          distance: "dot",
          ef: 100,
          ef_construction: 128,
          max_connections: 64,
          dynamic_ef_min: 50,
          dynamic_ef_max: 500,
          dynamic_ef_factor: 8,
          vector_cache_max_objects: 1_000_000,
          flat_search_cutoff: 40_000,
          cleanup_interval_seconds: 300,
          pq_enabled: true,
          bq_enabled: false,
          sq_enabled: false
        )

      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["distance"] == "dot"
      assert config["vectorIndexConfig"]["ef"] == 100
      assert config["vectorIndexConfig"]["efConstruction"] == 128
      assert config["vectorIndexConfig"]["maxConnections"] == 64
      assert config["vectorIndexConfig"]["dynamicEfMin"] == 50
      assert config["vectorIndexConfig"]["dynamicEfMax"] == 500
      assert config["vectorIndexConfig"]["dynamicEfFactor"] == 8
      assert config["vectorIndexConfig"]["vectorCacheMaxObjects"] == 1_000_000
      assert config["vectorIndexConfig"]["flatSearchCutoff"] == 40_000
      assert config["vectorIndexConfig"]["cleanupIntervalSeconds"] == 300
      assert config["vectorIndexConfig"]["pq"]["enabled"] == true
    end

    test "FLAT index configuration" do
      config = VectorConfig.flat_index(distance: "cosine")

      assert config["vectorIndexType"] == "flat"
      assert config["vectorIndexConfig"]["distance"] == "cosine"
    end

    test "DYNAMIC index configuration" do
      config =
        VectorConfig.dynamic_index(
          distance: "cosine",
          threshold: 10_000,
          hnsw: %{ef: 100},
          flat: %{vectorCacheMaxObjects: 100_000}
        )

      assert config["vectorIndexType"] == "dynamic"
      assert config["vectorIndexConfig"]["distance"] == "cosine"
      assert config["vectorIndexConfig"]["threshold"] == 10_000
    end
  end

  describe "quantization configurations" do
    test "Product Quantization (PQ) enabled" do
      config = VectorConfig.product_quantization(enabled: true, training_limit: 100_000)

      assert config["pq"]["enabled"] == true
      assert config["pq"]["trainingLimit"] == 100_000
    end

    test "PQ with segments and centroids" do
      config =
        VectorConfig.product_quantization(
          enabled: true,
          segments: 96,
          centroids: 256,
          encoder: %{type: "kmeans", distribution: "log-normal"}
        )

      assert config["pq"]["segments"] == 96
      assert config["pq"]["centroids"] == 256
      assert config["pq"]["encoder"]["type"] == "kmeans"
    end

    test "Binary Quantization (BQ) enabled" do
      config = VectorConfig.binary_quantization(enabled: true)

      assert config["bq"]["enabled"] == true
    end

    test "Scalar Quantization (SQ) enabled" do
      config =
        VectorConfig.scalar_quantization(
          enabled: true,
          rescore_limit: 100,
          cache: true
        )

      assert config["sq"]["enabled"] == true
      assert config["sq"]["rescoreLimit"] == 100
      assert config["sq"]["cache"] == true
    end
  end

  describe "complete collection configurations" do
    test "builds complete config with vectorizer and index" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-ada-002")
        |> VectorConfig.with_hnsw_index(ef: 100, max_connections: 64)
        |> VectorConfig.with_properties([
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]}
        ])

      assert config["class"] == "Article"
      assert config["vectorizer"] == "text2vec-openai"
      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["ef"] == 100
      assert length(config["properties"]) == 2
    end

    test "builds config with quantization" do
      config =
        VectorConfig.new("Product")
        |> VectorConfig.with_vectorizer(:text2vec_cohere)
        |> VectorConfig.with_hnsw_index()
        |> VectorConfig.with_product_quantization(enabled: true, segments: 96)

      assert config["class"] == "Product"
      assert config["vectorIndexConfig"]["pq"]["enabled"] == true
      assert config["vectorIndexConfig"]["pq"]["segments"] == 96
    end

    test "builds config with multiple named vectors" do
      config =
        VectorConfig.new("MultiVector")
        |> VectorConfig.with_named_vectors(%{
          "title_vector" => %{
            vectorizer: "text2vec-openai",
            vectorIndexType: "hnsw"
          },
          "image_vector" => %{
            vectorizer: "multi2vec-clip",
            vectorIndexType: "flat"
          }
        })

      assert config["class"] == "MultiVector"
      assert Map.has_key?(config, "vectorConfig")
      assert config["vectorConfig"]["title_vector"]["vectorizer"] == "text2vec-openai"
      assert config["vectorConfig"]["image_vector"]["vectorizer"] == "multi2vec-clip"
    end

    test "builds config with replication" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(factor: 3)

      assert config["class"] == "ReplicatedCollection"
      assert config["replicationConfig"]["factor"] == 3
    end

    test "builds config with sharding" do
      config =
        VectorConfig.new("ShardedCollection")
        |> VectorConfig.with_sharding_config(
          virtual_per_physical: 128,
          desired_count: 3,
          actual_count: 3
        )

      assert config["class"] == "ShardedCollection"
      assert config["shardingConfig"]["virtualPerPhysical"] == 128
      assert config["shardingConfig"]["desiredCount"] == 3
    end

    test "builds config with multi-tenancy" do
      config =
        VectorConfig.new("TenantCollection")
        |> VectorConfig.with_multi_tenancy(enabled: true)

      assert config["class"] == "TenantCollection"
      assert config["multiTenancyConfig"]["enabled"] == true
    end
  end

  describe "helper functions" do
    test "lists all supported vectorizers" do
      vectorizers = VectorConfig.supported_vectorizers()

      assert :text2vec_openai in vectorizers
      assert :text2vec_cohere in vectorizers
      assert :text2vec_huggingface in vectorizers
      assert :multi2vec_clip in vectorizers
      assert :multi2vec_bind in vectorizers
      assert :none in vectorizers
      assert length(vectorizers) >= 11
    end

    test "lists all distance metrics" do
      metrics = VectorConfig.distance_metrics()

      assert :cosine in metrics
      assert :dot in metrics
      assert :l2_squared in metrics
      assert :hamming in metrics
      assert :manhattan in metrics
    end

    test "validates vectorizer name" do
      assert VectorConfig.valid_vectorizer?(:text2vec_openai) == true
      assert VectorConfig.valid_vectorizer?(:invalid) == false
    end

    test "validates distance metric" do
      assert VectorConfig.valid_distance?(:cosine) == true
      assert VectorConfig.valid_distance?(:invalid) == false
    end
  end
end
