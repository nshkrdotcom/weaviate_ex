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

  describe "AWS service-specific methods" do
    test "text2vec_aws_bedrock creates proper config" do
      config =
        VectorConfig.text2vec_aws_bedrock(
          model: "amazon.titan-embed-text-v1",
          region: "us-east-1"
        )

      assert config["vectorizer"] == "text2vec-aws"
      assert config["moduleConfig"]["text2vec-aws"]["model"] == "amazon.titan-embed-text-v1"
      assert config["moduleConfig"]["text2vec-aws"]["region"] == "us-east-1"
      assert config["moduleConfig"]["text2vec-aws"]["service"] == "bedrock"
      assert config["moduleConfig"]["text2vec-aws"]["vectorizeClassName"] == true
    end

    test "text2vec_aws_bedrock raises when model missing" do
      assert_raise KeyError, fn ->
        VectorConfig.text2vec_aws_bedrock(region: "us-east-1")
      end
    end

    test "text2vec_aws_sagemaker creates proper config" do
      config =
        VectorConfig.text2vec_aws_sagemaker(
          endpoint: "my-endpoint",
          region: "us-west-2",
          target_model: "model-v1",
          target_variant: "variant-a"
        )

      assert config["vectorizer"] == "text2vec-aws"
      assert config["moduleConfig"]["text2vec-aws"]["endpoint"] == "my-endpoint"
      assert config["moduleConfig"]["text2vec-aws"]["region"] == "us-west-2"
      assert config["moduleConfig"]["text2vec-aws"]["service"] == "sagemaker"
      assert config["moduleConfig"]["text2vec-aws"]["targetModel"] == "model-v1"
      assert config["moduleConfig"]["text2vec-aws"]["targetVariant"] == "variant-a"
    end
  end

  describe "Google service-specific methods" do
    test "text2vec_google_vertex creates proper config" do
      config =
        VectorConfig.text2vec_google_vertex(
          project_id: "my-project",
          model: "textembedding-gecko@001",
          dimensions: 768
        )

      assert config["vectorizer"] == "text2vec-palm"
      assert config["moduleConfig"]["text2vec-palm"]["projectId"] == "my-project"
      assert config["moduleConfig"]["text2vec-palm"]["modelId"] == "textembedding-gecko@001"
      assert config["moduleConfig"]["text2vec-palm"]["dimensions"] == 768
    end

    test "text2vec_google_gemini creates config with default endpoint" do
      config = VectorConfig.text2vec_google_gemini(model: "text-embedding-004")

      assert config["vectorizer"] == "text2vec-palm"

      assert config["moduleConfig"]["text2vec-palm"]["apiEndpoint"] ==
               "generativelanguage.googleapis.com"

      assert config["moduleConfig"]["text2vec-palm"]["modelId"] == "text-embedding-004"
    end
  end

  describe "new vectorizers Dec 2025" do
    test "text2vec_cohere includes dimensions parameter" do
      config = VectorConfig.text2vec_cohere(model: "embed-english-v3.0", dimensions: 1024)

      assert config["moduleConfig"]["text2vec-cohere"]["dimensions"] == 1024
    end

    test "text2vec_voyageai configuration" do
      config = VectorConfig.text2vec_voyageai(model: "voyage-3.5")

      assert config["vectorizer"] == "text2vec-voyageai"
      assert config["moduleConfig"]["text2vec-voyageai"]["model"] == "voyage-3.5"
    end

    test "text2vec_morph configuration" do
      config = VectorConfig.text2vec_morph(model: "morph-base")

      assert config["vectorizer"] == "text2vec-morph"
      assert config["moduleConfig"]["text2vec-morph"]["model"] == "morph-base"
    end

    test "text2vec_model2vec configuration" do
      config = VectorConfig.text2vec_model2vec(inference_url: "http://localhost:8000")

      assert config["vectorizer"] == "text2vec-model2vec"

      assert config["moduleConfig"]["text2vec-model2vec"]["inferenceUrl"] ==
               "http://localhost:8000"
    end

    test "text2colbert_jinaai configuration" do
      config = VectorConfig.text2colbert_jinaai(model: "jina-colbert-v2", dimensions: 128)

      assert config["vectorizer"] == "text2colbert-jinaai"
      assert config["moduleConfig"]["text2colbert-jinaai"]["model"] == "jina-colbert-v2"
      assert config["moduleConfig"]["text2colbert-jinaai"]["dimensions"] == 128
    end

    test "multi2multivec_jinaai configuration" do
      config =
        VectorConfig.multi2multivec_jinaai(
          model: "jina-clip-v1",
          image_fields: ["image"],
          text_fields: ["title", "description"]
        )

      assert config["vectorizer"] == "multi2multivec-jinaai"
      assert config["moduleConfig"]["multi2multivec-jinaai"]["model"] == "jina-clip-v1"
      assert config["moduleConfig"]["multi2multivec-jinaai"]["imageFields"] == ["image"]

      assert config["moduleConfig"]["multi2multivec-jinaai"]["textFields"] == [
               "title",
               "description"
             ]
    end

    test "reranker_cohere with base_url" do
      config =
        VectorConfig.reranker_cohere(
          model: "rerank-english-v3.0",
          base_url: "https://custom.cohere.ai"
        )

      assert config["reranker-cohere"]["model"] == "rerank-english-v3.0"
      assert config["reranker-cohere"]["baseURL"] == "https://custom.cohere.ai"
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

  describe "scalar quantization (SQ) with all options" do
    test "SQ with training_limit option" do
      config =
        VectorConfig.scalar_quantization(
          enabled: true,
          training_limit: 50_000,
          rescore_limit: 100,
          cache: true
        )

      assert config["sq"]["enabled"] == true
      assert config["sq"]["trainingLimit"] == 50_000
      assert config["sq"]["rescoreLimit"] == 100
      assert config["sq"]["cache"] == true
    end

    test "SQ with default values" do
      config = VectorConfig.scalar_quantization(enabled: true)

      assert config["sq"]["enabled"] == true
      refute Map.has_key?(config["sq"], "trainingLimit")
      refute Map.has_key?(config["sq"], "rescoreLimit")
      refute Map.has_key?(config["sq"], "cache")
    end

    test "sq/1 alias function with all options" do
      config =
        VectorConfig.sq(
          enabled: true,
          training_limit: 100_000,
          rescore_limit: 200,
          cache: false
        )

      assert config["sq"]["enabled"] == true
      assert config["sq"]["trainingLimit"] == 100_000
      assert config["sq"]["rescoreLimit"] == 200
      assert config["sq"]["cache"] == false
    end
  end

  describe "rotational quantization (RQ)" do
    test "RQ with all options" do
      config =
        VectorConfig.rotational_quantization(
          enabled: true,
          cache: true,
          bits: 8,
          rescore_limit: 200
        )

      assert config["rq"]["enabled"] == true
      assert config["rq"]["cache"] == true
      assert config["rq"]["bits"] == 8
      assert config["rq"]["rescoreLimit"] == 200
    end

    test "RQ with default enabled true" do
      config = VectorConfig.rotational_quantization()

      assert config["rq"]["enabled"] == true
    end

    test "RQ with training_limit option" do
      config =
        VectorConfig.rotational_quantization(
          enabled: true,
          training_limit: 75_000
        )

      assert config["rq"]["enabled"] == true
      assert config["rq"]["trainingLimit"] == 75_000
    end

    test "rq/1 alias function" do
      config =
        VectorConfig.rq(
          cache: true,
          bits: 4,
          rescore_limit: 150
        )

      assert config["rq"]["enabled"] == true
      assert config["rq"]["cache"] == true
      assert config["rq"]["bits"] == 4
      assert config["rq"]["rescoreLimit"] == 150
    end

    test "with_rotational_quantization builder function" do
      config =
        VectorConfig.new("TestCollection")
        |> VectorConfig.with_hnsw_index()
        |> VectorConfig.with_rotational_quantization(bits: 8, cache: true)

      assert config["vectorIndexConfig"]["rq"]["enabled"] == true
      assert config["vectorIndexConfig"]["rq"]["bits"] == 8
      assert config["vectorIndexConfig"]["rq"]["cache"] == true
    end
  end

  describe "dynamic vector index with configs" do
    test "dynamic index with HNSW and Flat sub-configs" do
      config =
        VectorConfig.dynamic_index(
          distance: :cosine,
          threshold: 5_000,
          hnsw: %{
            "ef" => 100,
            "efConstruction" => 128,
            "maxConnections" => 64
          },
          flat: %{
            "vectorCacheMaxObjects" => 50_000
          }
        )

      assert config["vectorIndexType"] == "dynamic"
      assert config["vectorIndexConfig"]["distance"] == "cosine"
      assert config["vectorIndexConfig"]["threshold"] == 5_000
      assert config["vectorIndexConfig"]["hnsw"]["ef"] == 100
      assert config["vectorIndexConfig"]["hnsw"]["efConstruction"] == 128
      assert config["vectorIndexConfig"]["hnsw"]["maxConnections"] == 64
      assert config["vectorIndexConfig"]["flat"]["vectorCacheMaxObjects"] == 50_000
    end

    test "dynamic index with only threshold" do
      config = VectorConfig.dynamic_index(threshold: 15_000)

      assert config["vectorIndexType"] == "dynamic"
      assert config["vectorIndexConfig"]["threshold"] == 15_000
      refute Map.has_key?(config["vectorIndexConfig"], "hnsw")
      refute Map.has_key?(config["vectorIndexConfig"], "flat")
    end

    test "dynamic index defaults" do
      config = VectorConfig.dynamic_index()

      assert config["vectorIndexType"] == "dynamic"
      assert config["vectorIndexConfig"]["distance"] == "cosine"
      assert config["vectorIndexConfig"]["threshold"] == 10_000
    end

    test "dynamic index with quantizer" do
      config =
        VectorConfig.dynamic_index(
          threshold: 8_000,
          hnsw: %{
            "ef" => 100,
            "quantizer" => %{"bq" => %{"enabled" => true}}
          }
        )

      assert config["vectorIndexType"] == "dynamic"
      assert config["vectorIndexConfig"]["hnsw"]["quantizer"]["bq"]["enabled"] == true
    end
  end

  describe "HNSW filter_strategy option" do
    test "HNSW with sweeping filter strategy" do
      config = VectorConfig.hnsw_index(filter_strategy: :sweeping)

      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["filterStrategy"] == "sweeping"
    end

    test "HNSW with acorn filter strategy" do
      config = VectorConfig.hnsw_index(filter_strategy: :acorn)

      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["filterStrategy"] == "acorn"
    end

    test "HNSW with filter_strategy and other options" do
      config =
        VectorConfig.hnsw_index(
          ef: 200,
          max_connections: 48,
          filter_strategy: :acorn,
          distance: :dot
        )

      assert config["vectorIndexConfig"]["ef"] == 200
      assert config["vectorIndexConfig"]["maxConnections"] == 48
      assert config["vectorIndexConfig"]["filterStrategy"] == "acorn"
      assert config["vectorIndexConfig"]["distance"] == "dot"
    end

    test "HNSW without filter_strategy uses default" do
      config = VectorConfig.hnsw_index(ef: 100)

      refute Map.has_key?(config["vectorIndexConfig"], "filterStrategy")
    end

    test "HNSW with string filter_strategy value" do
      config = VectorConfig.hnsw_index(filter_strategy: "acorn")

      assert config["vectorIndexConfig"]["filterStrategy"] == "acorn"
    end
  end

  describe "replication config with deletion_strategy" do
    test "replication with delete_on_conflict strategy" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 3,
          deletion_strategy: :delete_on_conflict
        )

      assert config["replicationConfig"]["factor"] == 3
      assert config["replicationConfig"]["deletionStrategy"] == "DeleteOnConflict"
    end

    test "replication with no_automated_resolution strategy" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 2,
          deletion_strategy: :no_automated_resolution
        )

      assert config["replicationConfig"]["factor"] == 2
      assert config["replicationConfig"]["deletionStrategy"] == "NoAutomatedResolution"
    end

    test "replication with time_based_resolution strategy" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 3,
          deletion_strategy: :time_based_resolution
        )

      assert config["replicationConfig"]["factor"] == 3
      assert config["replicationConfig"]["deletionStrategy"] == "TimeBasedResolution"
    end

    test "replication with async_enabled option" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 2,
          async_enabled: true
        )

      assert config["replicationConfig"]["factor"] == 2
      assert config["replicationConfig"]["asyncEnabled"] == true
    end

    test "replication with all options" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 3,
          async_enabled: true,
          deletion_strategy: :time_based_resolution
        )

      assert config["replicationConfig"]["factor"] == 3
      assert config["replicationConfig"]["asyncEnabled"] == true
      assert config["replicationConfig"]["deletionStrategy"] == "TimeBasedResolution"
    end

    test "replication without deletion_strategy uses default" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(factor: 2)

      assert config["replicationConfig"]["factor"] == 2
      refute Map.has_key?(config["replicationConfig"], "deletionStrategy")
    end

    test "replication with string deletion_strategy value" do
      config =
        VectorConfig.new("ReplicatedCollection")
        |> VectorConfig.with_replication_config(
          factor: 3,
          deletion_strategy: "DeleteOnConflict"
        )

      assert config["replicationConfig"]["deletionStrategy"] == "DeleteOnConflict"
    end
  end

  describe "HNSW with quantizer option" do
    test "HNSW with RQ quantizer via quantizer option" do
      config =
        VectorConfig.hnsw_index(
          ef: 100,
          quantizer: VectorConfig.rq(bits: 8, cache: true)
        )

      assert config["vectorIndexConfig"]["rq"]["enabled"] == true
      assert config["vectorIndexConfig"]["rq"]["bits"] == 8
      assert config["vectorIndexConfig"]["rq"]["cache"] == true
    end

    test "HNSW with SQ quantizer via quantizer option" do
      config =
        VectorConfig.hnsw_index(
          ef: 100,
          quantizer: VectorConfig.sq(training_limit: 50_000)
        )

      assert config["vectorIndexConfig"]["sq"]["enabled"] == true
      assert config["vectorIndexConfig"]["sq"]["trainingLimit"] == 50_000
    end

    test "HNSW with PQ quantizer via quantizer option" do
      config =
        VectorConfig.hnsw_index(
          ef: 100,
          quantizer: VectorConfig.product_quantization(enabled: true, segments: 96)
        )

      assert config["vectorIndexConfig"]["pq"]["enabled"] == true
      assert config["vectorIndexConfig"]["pq"]["segments"] == 96
    end

    test "HNSW with BQ quantizer via quantizer option" do
      config =
        VectorConfig.hnsw_index(
          ef: 100,
          quantizer: VectorConfig.binary_quantization(enabled: true)
        )

      assert config["vectorIndexConfig"]["bq"]["enabled"] == true
    end
  end

  describe "reranker configurations" do
    test "reranker_cohere configuration" do
      config = VectorConfig.reranker_cohere(model: "rerank-multilingual-v3.0")

      assert config["reranker-cohere"]["model"] == "rerank-multilingual-v3.0"
    end

    test "reranker_cohere with base_url" do
      config =
        VectorConfig.reranker_cohere(
          model: "rerank-english-v3.0",
          base_url: "https://custom.cohere.ai"
        )

      assert config["reranker-cohere"]["model"] == "rerank-english-v3.0"
      assert config["reranker-cohere"]["baseURL"] == "https://custom.cohere.ai"
    end

    test "reranker_transformers configuration" do
      config = VectorConfig.reranker_transformers()

      assert Map.has_key?(config, "reranker-transformers")
    end

    test "reranker_transformers with inference_url" do
      config = VectorConfig.reranker_transformers(inference_url: "http://localhost:8080")

      assert config["reranker-transformers"]["inferenceUrl"] == "http://localhost:8080"
    end

    test "reranker_voyageai configuration" do
      config = VectorConfig.reranker_voyageai(model: "rerank-2")

      assert config["reranker-voyageai"]["model"] == "rerank-2"
    end

    test "reranker_voyageai with all options" do
      config =
        VectorConfig.reranker_voyageai(
          model: "rerank-lite-1",
          base_url: "https://api.voyageai.com",
          truncate: true
        )

      assert config["reranker-voyageai"]["model"] == "rerank-lite-1"
      assert config["reranker-voyageai"]["baseURL"] == "https://api.voyageai.com"
      assert config["reranker-voyageai"]["truncate"] == true
    end

    test "reranker_jinaai configuration" do
      config = VectorConfig.reranker_jinaai(model: "jina-reranker-v2-base-multilingual")

      assert config["reranker-jinaai"]["model"] == "jina-reranker-v2-base-multilingual"
    end

    test "reranker_jinaai with base_url" do
      config =
        VectorConfig.reranker_jinaai(
          model: "jina-reranker-v1-base-en",
          base_url: "https://api.jina.ai"
        )

      assert config["reranker-jinaai"]["model"] == "jina-reranker-v1-base-en"
      assert config["reranker-jinaai"]["baseURL"] == "https://api.jina.ai"
    end

    test "reranker_nvidia configuration" do
      config = VectorConfig.reranker_nvidia(model: "nvidia/nv-rerankqa-mistral-4b-v3")

      assert config["reranker-nvidia"]["model"] == "nvidia/nv-rerankqa-mistral-4b-v3"
    end

    test "reranker_nvidia with base_url" do
      config =
        VectorConfig.reranker_nvidia(
          model: "nvidia/nv-rerankqa-mistral-4b-v3",
          base_url: "https://api.nvidia.com"
        )

      assert config["reranker-nvidia"]["model"] == "nvidia/nv-rerankqa-mistral-4b-v3"
      assert config["reranker-nvidia"]["baseURL"] == "https://api.nvidia.com"
    end

    test "reranker_contextualai configuration" do
      config = VectorConfig.reranker_contextualai(model: "contextual-rerank-v1")

      assert config["reranker-contextualai"]["model"] == "contextual-rerank-v1"
    end

    test "reranker_contextualai with all options" do
      config =
        VectorConfig.reranker_contextualai(
          model: "contextual-rerank-v1",
          base_url: "https://api.contextual.ai",
          context_source: "document"
        )

      assert config["reranker-contextualai"]["model"] == "contextual-rerank-v1"
      assert config["reranker-contextualai"]["baseURL"] == "https://api.contextual.ai"
      assert config["reranker-contextualai"]["contextSource"] == "document"
    end
  end

  describe "with_reranker builder" do
    test "adds cohere reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_vectorizer(:text2vec_openai)
        |> VectorConfig.with_reranker(:cohere, model: "rerank-multilingual-v3.0")

      assert config["class"] == "Article"
      assert config["moduleConfig"]["reranker-cohere"]["model"] == "rerank-multilingual-v3.0"
    end

    test "adds transformers reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_reranker(:transformers)

      assert Map.has_key?(config["moduleConfig"], "reranker-transformers")
    end

    test "adds voyageai reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_reranker(:voyageai, model: "rerank-2")

      assert config["moduleConfig"]["reranker-voyageai"]["model"] == "rerank-2"
    end

    test "adds jinaai reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_reranker(:jinaai, model: "jina-reranker-v2-base-multilingual")

      assert config["moduleConfig"]["reranker-jinaai"]["model"] ==
               "jina-reranker-v2-base-multilingual"
    end

    test "adds nvidia reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_reranker(:nvidia, model: "nvidia/nv-rerankqa-mistral-4b-v3")

      assert config["moduleConfig"]["reranker-nvidia"]["model"] ==
               "nvidia/nv-rerankqa-mistral-4b-v3"
    end

    test "adds contextualai reranker to collection config" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_reranker(:contextualai, model: "contextual-rerank-v1")

      assert config["moduleConfig"]["reranker-contextualai"]["model"] == "contextual-rerank-v1"
    end

    test "reranker merges with existing moduleConfig" do
      config =
        VectorConfig.new("Article")
        |> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-ada-002")
        |> VectorConfig.with_reranker(:cohere, model: "rerank-multilingual-v3.0")

      # Both vectorizer and reranker should be in moduleConfig
      assert Map.has_key?(config["moduleConfig"], "text2vec-openai")
      assert Map.has_key?(config["moduleConfig"], "reranker-cohere")
      assert config["moduleConfig"]["text2vec-openai"]["model"] == "text-embedding-ada-002"
      assert config["moduleConfig"]["reranker-cohere"]["model"] == "rerank-multilingual-v3.0"
    end

    test "complete collection with vectorizer, index, and reranker" do
      config =
        VectorConfig.new("SearchableArticle")
        |> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-ada-002")
        |> VectorConfig.with_hnsw_index(ef: 100, max_connections: 64)
        |> VectorConfig.with_reranker(:cohere, model: "rerank-multilingual-v3.0")
        |> VectorConfig.with_properties([
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]}
        ])

      assert config["class"] == "SearchableArticle"
      assert config["vectorizer"] == "text2vec-openai"
      assert config["vectorIndexType"] == "hnsw"
      assert config["vectorIndexConfig"]["ef"] == 100
      assert config["moduleConfig"]["reranker-cohere"]["model"] == "rerank-multilingual-v3.0"
      assert length(config["properties"]) == 2
    end
  end
end
