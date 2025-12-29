defmodule WeaviateEx.API.VectorConfig do
  @moduledoc """
  Vector configuration builders for Phase 2.4.

  Provides builder functions for:
  - 25+ vectorizer configurations
  - 3 index types (HNSW, FLAT, DYNAMIC)
  - 3 quantization methods (PQ, BQ, SQ)
  - Complete collection configurations

  ## Usage

      config = VectorConfig.new("Article")
      |> VectorConfig.with_vectorizer(:text2vec_openai, model: "text-embedding-ada-002")
      |> VectorConfig.with_hnsw_index(ef: 100, max_connections: 64)
      |> VectorConfig.with_product_quantization(enabled: true)
      |> VectorConfig.with_properties([
        %{name: "title", dataType: ["text"]}
      ])
  """

  @type config :: map()
  @type opts :: keyword()
  @type vectorizer ::
          :text2vec_openai
          | :text2vec_cohere
          | :text2vec_huggingface
          | :text2vec_transformers
          | :text2vec_contextionary
          | :text2vec_gpt4all
          | :text2vec_palm
          | :text2vec_aws
          | :multi2vec_clip
          | :multi2vec_bind
          | :none

  @supported_vectorizers [
    :text2vec_openai,
    :text2vec_cohere,
    :text2vec_huggingface,
    :text2vec_transformers,
    :text2vec_contextionary,
    :text2vec_gpt4all,
    :text2vec_palm,
    :text2vec_aws,
    :multi2vec_clip,
    :multi2vec_bind,
    :none
  ]

  @distance_metrics [:cosine, :dot, :l2_squared, :hamming, :manhattan]

  ## Vectorizer Configurations

  @doc "Configure text2vec-openai vectorizer"
  def text2vec_openai(opts \\ []) do
    %{
      "vectorizer" => "text2vec-openai",
      "moduleConfig" => %{
        "text2vec-openai" => build_module_opts(opts)
      }
    }
  end

  @doc """
  Configure text2vec-cohere vectorizer.

  ## Options
    - `:model` - Model to use (optional)
    - `:dimensions` - Output dimensions (optional, new in Python client)
    - `:truncate` - Truncation mode (optional)
    - `:base_url` - Base URL for API (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_cohere(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
      |> maybe_put("truncate", Keyword.get(opts, :truncate))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-cohere",
      "moduleConfig" => %{
        "text2vec-cohere" => config
      }
    }
  end

  @doc "Configure text2vec-huggingface vectorizer"
  def text2vec_huggingface(opts \\ []) do
    %{
      "vectorizer" => "text2vec-huggingface",
      "moduleConfig" => %{
        "text2vec-huggingface" => build_module_opts(opts)
      }
    }
  end

  @doc "Configure text2vec-transformers vectorizer"
  def text2vec_transformers(opts \\ []) do
    %{
      "vectorizer" => "text2vec-transformers",
      "moduleConfig" => %{
        "text2vec-transformers" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc "Configure text2vec-contextionary vectorizer"
  def text2vec_contextionary(opts \\ []) do
    %{
      "vectorizer" => "text2vec-contextionary",
      "moduleConfig" => %{
        "text2vec-contextionary" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc "Configure text2vec-gpt4all vectorizer"
  def text2vec_gpt4all(opts \\ []) do
    %{
      "vectorizer" => "text2vec-gpt4all",
      "moduleConfig" => %{
        "text2vec-gpt4all" => build_module_opts(opts)
      }
    }
  end

  @doc """
  Configure text2vec-palm vectorizer (deprecated, use text2vec_google_vertex or text2vec_google_gemini).
  """
  def text2vec_palm(opts \\ []) do
    %{
      "vectorizer" => "text2vec-palm",
      "moduleConfig" => %{
        "text2vec-palm" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc """
  Configure text2vec-google with Google Vertex AI.

  ## Options
    - `:project_id` - Google Cloud project ID (required)
    - `:api_endpoint` - API endpoint (optional)
    - `:model` - Model to use (optional)
    - `:dimensions` - Output dimensions (optional)
    - `:title_property` - Property to use as title (optional)
    - `:task_type` - Task type for embeddings (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)

  ## Example

      VectorConfig.text2vec_google_vertex(
        project_id: "my-project",
        model: "textembedding-gecko@001"
      )
  """
  def text2vec_google_vertex(opts) do
    config =
      %{
        "projectId" => Keyword.fetch!(opts, :project_id),
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("apiEndpoint", Keyword.get(opts, :api_endpoint))
      |> maybe_put("modelId", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
      |> maybe_put("titleProperty", Keyword.get(opts, :title_property))
      |> maybe_put("taskType", Keyword.get(opts, :task_type))

    %{
      "vectorizer" => "text2vec-palm",
      "moduleConfig" => %{
        "text2vec-palm" => config
      }
    }
  end

  @doc """
  Configure text2vec-google with Google AI Studio (Gemini).

  ## Options
    - `:model` - Model to use (optional)
    - `:dimensions` - Output dimensions (optional)
    - `:title_property` - Property to use as title (optional)
    - `:task_type` - Task type for embeddings (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)

  ## Example

      VectorConfig.text2vec_google_gemini(model: "text-embedding-004")
  """
  def text2vec_google_gemini(opts \\ []) do
    config =
      %{
        "apiEndpoint" => "generativelanguage.googleapis.com",
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("modelId", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
      |> maybe_put("titleProperty", Keyword.get(opts, :title_property))
      |> maybe_put("taskType", Keyword.get(opts, :task_type))

    %{
      "vectorizer" => "text2vec-palm",
      "moduleConfig" => %{
        "text2vec-palm" => config
      }
    }
  end

  @doc """
  Configure text2vec-aws vectorizer (deprecated, use text2vec_aws_bedrock or text2vec_aws_sagemaker).
  """
  def text2vec_aws(opts \\ []) do
    %{
      "vectorizer" => "text2vec-aws",
      "moduleConfig" => %{
        "text2vec-aws" => build_module_opts(opts)
      }
    }
  end

  @doc """
  Configure text2vec-aws with AWS Bedrock service.

  ## Options
    - `:model` - The model to use (required, e.g., "amazon.titan-embed-text-v1")
    - `:region` - AWS region (required)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)

  ## Example

      VectorConfig.text2vec_aws_bedrock(
        model: "amazon.titan-embed-text-v1",
        region: "us-east-1"
      )
  """
  def text2vec_aws_bedrock(opts) do
    config =
      %{
        "model" => Keyword.fetch!(opts, :model),
        "region" => Keyword.fetch!(opts, :region),
        "service" => "bedrock",
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }

    %{
      "vectorizer" => "text2vec-aws",
      "moduleConfig" => %{
        "text2vec-aws" => config
      }
    }
  end

  @doc """
  Configure text2vec-aws with AWS SageMaker service.

  ## Options
    - `:endpoint` - The SageMaker endpoint (required)
    - `:region` - AWS region (required)
    - `:target_model` - Target model (optional)
    - `:target_variant` - Target variant (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)

  ## Example

      VectorConfig.text2vec_aws_sagemaker(
        endpoint: "my-endpoint",
        region: "us-east-1"
      )
  """
  def text2vec_aws_sagemaker(opts) do
    config =
      %{
        "endpoint" => Keyword.fetch!(opts, :endpoint),
        "region" => Keyword.fetch!(opts, :region),
        "service" => "sagemaker",
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("targetModel", Keyword.get(opts, :target_model))
      |> maybe_put("targetVariant", Keyword.get(opts, :target_variant))

    %{
      "vectorizer" => "text2vec-aws",
      "moduleConfig" => %{
        "text2vec-aws" => config
      }
    }
  end

  @doc "Configure multi2vec-clip vectorizer"
  def multi2vec_clip(opts \\ []) do
    %{
      "vectorizer" => "multi2vec-clip",
      "moduleConfig" => %{
        "multi2vec-clip" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc "Configure multi2vec-bind vectorizer"
  def multi2vec_bind(opts \\ []) do
    %{
      "vectorizer" => "multi2vec-bind",
      "moduleConfig" => %{
        "multi2vec-bind" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc "Configure no vectorizer (custom vectors)"
  def none do
    %{"vectorizer" => "none"}
  end

  ## Index Configurations

  @doc """
  Configure HNSW index.

  ## Options
    - `:distance` - Distance metric (:cosine, :dot, :l2_squared, :hamming, :manhattan)
    - `:ef` - Query time ef parameter (default: -1)
    - `:ef_construction` - Index build ef parameter (default: 128)
    - `:max_connections` - Maximum connections per node (default: 32)
    - `:filter_strategy` - Filter strategy (:sweeping or :acorn)
    - `:quantizer` - Quantization config (PQ, BQ, SQ, or RQ)
  """
  @spec hnsw_index(keyword()) :: map()
  def hnsw_index(opts \\ []) do
    distance = Keyword.get(opts, :distance, :cosine) |> distance_to_string()

    index_config = %{
      "distance" => distance,
      "ef" => Keyword.get(opts, :ef, -1),
      "efConstruction" => Keyword.get(opts, :ef_construction, 128),
      "maxConnections" => Keyword.get(opts, :max_connections, 32)
    }

    index_config = maybe_add_dynamic_ef(index_config, opts)
    index_config = maybe_add_vector_cache(index_config, opts)
    index_config = maybe_add_flat_search_cutoff(index_config, opts)
    index_config = maybe_add_cleanup_interval(index_config, opts)
    index_config = maybe_add_filter_strategy(index_config, opts)
    index_config = maybe_add_quantization(index_config, opts)
    index_config = maybe_add_quantizer_option(index_config, opts)

    %{
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => index_config
    }
  end

  @doc "Configure FLAT index"
  def flat_index(opts \\ []) do
    distance = Keyword.get(opts, :distance, :cosine) |> distance_to_string()

    %{
      "vectorIndexType" => "flat",
      "vectorIndexConfig" => %{
        "distance" => distance
      }
    }
  end

  @doc "Configure DYNAMIC index"
  def dynamic_index(opts \\ []) do
    distance = Keyword.get(opts, :distance, :cosine) |> distance_to_string()
    threshold = Keyword.get(opts, :threshold, 10_000)

    index_config = %{
      "distance" => distance,
      "threshold" => threshold
    }

    index_config =
      if hnsw_opts = Keyword.get(opts, :hnsw) do
        Map.put(index_config, "hnsw", hnsw_opts)
      else
        index_config
      end

    index_config =
      if flat_opts = Keyword.get(opts, :flat) do
        Map.put(index_config, "flat", flat_opts)
      else
        index_config
      end

    %{
      "vectorIndexType" => "dynamic",
      "vectorIndexConfig" => index_config
    }
  end

  ## Quantization Configurations

  @doc "Configure Product Quantization (PQ)"
  def product_quantization(opts \\ []) do
    pq_config = %{
      "enabled" => Keyword.get(opts, :enabled, false)
    }

    pq_config =
      if training_limit = Keyword.get(opts, :training_limit) do
        Map.put(pq_config, "trainingLimit", training_limit)
      else
        pq_config
      end

    pq_config =
      if segments = Keyword.get(opts, :segments) do
        Map.put(pq_config, "segments", segments)
      else
        pq_config
      end

    pq_config =
      if centroids = Keyword.get(opts, :centroids) do
        Map.put(pq_config, "centroids", centroids)
      else
        pq_config
      end

    pq_config =
      if encoder = Keyword.get(opts, :encoder) do
        encoder_with_string_keys = stringify_keys(encoder)
        Map.put(pq_config, "encoder", encoder_with_string_keys)
      else
        pq_config
      end

    %{"pq" => pq_config}
  end

  @doc "Configure Binary Quantization (BQ)"
  def binary_quantization(opts \\ []) do
    %{
      "bq" => %{
        "enabled" => Keyword.get(opts, :enabled, false)
      }
    }
  end

  @doc """
  Configure Scalar Quantization (SQ).

  SQ provides memory reduction through scalar quantization of vectors.

  ## Options
    - `:enabled` - Enable SQ (default: false)
    - `:cache` - Enable cache (optional)
    - `:rescore_limit` - Number of candidates to rescore (optional)
    - `:training_limit` - Number of vectors to train on (optional)

  ## Example

      VectorConfig.hnsw_index(
        quantizer: VectorConfig.scalar_quantization(enabled: true, cache: true)
      )
  """
  @spec scalar_quantization(keyword()) :: map()
  def scalar_quantization(opts \\ []) do
    sq_config = %{
      "enabled" => Keyword.get(opts, :enabled, false)
    }

    sq_config =
      if rescore_limit = Keyword.get(opts, :rescore_limit) do
        Map.put(sq_config, "rescoreLimit", rescore_limit)
      else
        sq_config
      end

    sq_config =
      if Keyword.has_key?(opts, :cache) do
        Map.put(sq_config, "cache", Keyword.get(opts, :cache))
      else
        sq_config
      end

    sq_config =
      if training_limit = Keyword.get(opts, :training_limit) do
        Map.put(sq_config, "trainingLimit", training_limit)
      else
        sq_config
      end

    %{"sq" => sq_config}
  end

  @doc """
  Alias for `scalar_quantization/1` with enabled defaulting to true.

  ## Example

      VectorConfig.hnsw_index(
        quantizer: VectorConfig.sq(training_limit: 50_000)
      )
  """
  @spec sq(keyword()) :: map()
  def sq(opts \\ []) do
    scalar_quantization(Keyword.put_new(opts, :enabled, true))
  end

  ## Builder Pattern Functions

  @doc "Create new collection configuration"
  def new(class_name) do
    %{"class" => class_name}
  end

  @doc "Add vectorizer to configuration"
  def with_vectorizer(config, vectorizer, opts \\ []) do
    vectorizer_config = vectorizer_config_for(vectorizer, opts)
    Map.merge(config, vectorizer_config)
  end

  defp vectorizer_config_for(:text2vec_openai, opts), do: text2vec_openai(opts)
  defp vectorizer_config_for(:text2vec_cohere, opts), do: text2vec_cohere(opts)
  defp vectorizer_config_for(:text2vec_huggingface, opts), do: text2vec_huggingface(opts)
  defp vectorizer_config_for(:text2vec_transformers, opts), do: text2vec_transformers(opts)
  defp vectorizer_config_for(:text2vec_contextionary, opts), do: text2vec_contextionary(opts)
  defp vectorizer_config_for(:text2vec_gpt4all, opts), do: text2vec_gpt4all(opts)
  defp vectorizer_config_for(:text2vec_palm, opts), do: text2vec_palm(opts)
  defp vectorizer_config_for(:text2vec_aws, opts), do: text2vec_aws(opts)
  defp vectorizer_config_for(:multi2vec_clip, opts), do: multi2vec_clip(opts)
  defp vectorizer_config_for(:multi2vec_bind, opts), do: multi2vec_bind(opts)
  defp vectorizer_config_for(:none, _opts), do: none()

  @doc "Add HNSW index to configuration"
  def with_hnsw_index(config, opts \\ []) do
    Map.merge(config, hnsw_index(opts))
  end

  @doc "Add FLAT index to configuration"
  def with_flat_index(config, opts \\ []) do
    Map.merge(config, flat_index(opts))
  end

  @doc "Add DYNAMIC index to configuration"
  def with_dynamic_index(config, opts \\ []) do
    Map.merge(config, dynamic_index(opts))
  end

  @doc "Add Product Quantization to configuration"
  def with_product_quantization(config, opts \\ []) do
    pq_config = product_quantization(opts)
    update_in(config, ["vectorIndexConfig"], &Map.merge(&1, pq_config))
  end

  @doc "Add Binary Quantization to configuration"
  def with_binary_quantization(config, opts \\ []) do
    bq_config = binary_quantization(opts)
    update_in(config, ["vectorIndexConfig"], &Map.merge(&1, bq_config))
  end

  @doc "Add Scalar Quantization to configuration"
  def with_scalar_quantization(config, opts \\ []) do
    sq_config = scalar_quantization(opts)
    update_in(config, ["vectorIndexConfig"], &Map.merge(&1, sq_config))
  end

  @doc "Add Rotational Quantization to configuration"
  @spec with_rotational_quantization(map(), keyword()) :: map()
  def with_rotational_quantization(config, opts \\ []) do
    rq_config = rotational_quantization(opts)
    update_in(config, ["vectorIndexConfig"], &Map.merge(&1, rq_config))
  end

  @doc "Add properties to configuration"
  def with_properties(config, properties) do
    Map.put(config, "properties", properties)
  end

  @doc "Add named vectors configuration"
  def with_named_vectors(config, vectors) do
    vectors_with_string_keys =
      Enum.into(vectors, %{}, fn {name, vector_config} ->
        {name, stringify_keys(vector_config)}
      end)

    Map.put(config, "vectorConfig", vectors_with_string_keys)
  end

  @doc """
  Add replication configuration.

  ## Options
    - `:factor` - Number of replicas (default: 1)
    - `:async_enabled` - Enable async replication (v1.26.0+, optional)
    - `:deletion_strategy` - Conflict resolution strategy (optional)
      - `:delete_on_conflict` - Delete object on conflict
      - `:no_automated_resolution` - No automated conflict resolution
      - `:time_based_resolution` - Use timestamp for resolution
  """
  @spec with_replication_config(map(), keyword()) :: map()
  def with_replication_config(config, opts \\ []) do
    replication_config =
      %{
        "factor" => Keyword.get(opts, :factor, 1)
      }
      |> maybe_put("asyncEnabled", Keyword.get(opts, :async_enabled))
      |> maybe_put(
        "deletionStrategy",
        format_deletion_strategy(Keyword.get(opts, :deletion_strategy))
      )

    Map.put(config, "replicationConfig", replication_config)
  end

  defp format_deletion_strategy(nil), do: nil
  defp format_deletion_strategy(:delete_on_conflict), do: "DeleteOnConflict"
  defp format_deletion_strategy(:no_automated_resolution), do: "NoAutomatedResolution"
  defp format_deletion_strategy(:time_based_resolution), do: "TimeBasedResolution"
  defp format_deletion_strategy(strategy) when is_binary(strategy), do: strategy

  @doc "Add sharding configuration"
  def with_sharding_config(config, opts \\ []) do
    sharding_config = %{}

    sharding_config =
      if virtual_per_physical = Keyword.get(opts, :virtual_per_physical) do
        Map.put(sharding_config, "virtualPerPhysical", virtual_per_physical)
      else
        sharding_config
      end

    sharding_config =
      if desired_count = Keyword.get(opts, :desired_count) do
        Map.put(sharding_config, "desiredCount", desired_count)
      else
        sharding_config
      end

    sharding_config =
      if actual_count = Keyword.get(opts, :actual_count) do
        Map.put(sharding_config, "actualCount", actual_count)
      else
        sharding_config
      end

    Map.put(config, "shardingConfig", sharding_config)
  end

  @doc "Add multi-tenancy configuration"
  def with_multi_tenancy(config, opts \\ []) do
    mt_config = %{
      "enabled" => Keyword.get(opts, :enabled, false)
    }

    Map.put(config, "multiTenancyConfig", mt_config)
  end

  ## New Vectorizers (Python client sync Dec 2025)

  @doc """
  Configure text2vec-voyageai vectorizer.

  ## Options
    - `:model` - Model to use (e.g., "voyage-3.5", "voyage-3-large", "voyage-context-3")
    - `:base_url` - Base URL for API (optional)
    - `:truncation` - Whether to truncate (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_voyageai(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("truncation", Keyword.get(opts, :truncation))

    %{
      "vectorizer" => "text2vec-voyageai",
      "moduleConfig" => %{
        "text2vec-voyageai" => config
      }
    }
  end

  @doc """
  Configure text2vec-morph vectorizer.

  ## Options
    - `:model` - Model to use
    - `:base_url` - Base URL for API (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_morph(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-morph",
      "moduleConfig" => %{
        "text2vec-morph" => config
      }
    }
  end

  @doc """
  Configure text2vec-model2vec vectorizer.

  ## Options
    - `:inference_url` - URL for inference service (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_model2vec(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("inferenceUrl", Keyword.get(opts, :inference_url))

    %{
      "vectorizer" => "text2vec-model2vec",
      "moduleConfig" => %{
        "text2vec-model2vec" => config
      }
    }
  end

  @doc """
  Configure text2colbert-jinaai vectorizer (multi-vector).

  ## Options
    - `:model` - Model to use
    - `:dimensions` - Output dimensions (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2colbert_jinaai(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "vectorizer" => "text2colbert-jinaai",
      "moduleConfig" => %{
        "text2colbert-jinaai" => config
      }
    }
  end

  @doc """
  Configure multi2multivec-jinaai vectorizer.

  ## Options
    - `:model` - Model to use
    - `:base_url` - Base URL for API (optional)
    - `:image_fields` - List of image property names (optional)
    - `:text_fields` - List of text property names (optional)
  """
  def multi2multivec_jinaai(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("imageFields", Keyword.get(opts, :image_fields))
      |> maybe_put("textFields", Keyword.get(opts, :text_fields))

    %{
      "vectorizer" => "multi2multivec-jinaai",
      "moduleConfig" => %{
        "multi2multivec-jinaai" => config
      }
    }
  end

  @doc """
  Configure reranker-cohere module.

  ## Options
    - `:model` - Model to use (optional)
    - `:base_url` - Base URL for API (optional)
  """
  def reranker_cohere(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "reranker-cohere" => config
    }
  end

  ## Additional Vectorizers (Gap Analysis Dec 2025)

  @doc """
  Configure text2vec-ollama vectorizer.

  ## Options
    - `:model` - Ollama model name
    - `:api_endpoint` - Ollama API endpoint (default: http://localhost:11434)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_ollama(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("apiEndpoint", Keyword.get(opts, :api_endpoint))

    %{
      "vectorizer" => "text2vec-ollama",
      "moduleConfig" => %{
        "text2vec-ollama" => config
      }
    }
  end

  @doc """
  Configure text2vec-mistral vectorizer.

  ## Options
    - `:model` - Mistral model name
    - `:base_url` - Base URL for API (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_mistral(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-mistral",
      "moduleConfig" => %{
        "text2vec-mistral" => config
      }
    }
  end

  @doc """
  Configure text2vec-nvidia vectorizer.

  ## Options
    - `:model` - NVIDIA model name
    - `:base_url` - Base URL for API (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_nvidia(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-nvidia",
      "moduleConfig" => %{
        "text2vec-nvidia" => config
      }
    }
  end

  @doc """
  Configure text2vec-jinaai vectorizer.

  ## Options
    - `:model` - Jina model (e.g., "jina-embeddings-v3", "jina-embeddings-v4")
    - `:base_url` - API base URL (optional)
    - `:dimensions` - Output dimensions (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_jinaai(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "vectorizer" => "text2vec-jinaai",
      "moduleConfig" => %{
        "text2vec-jinaai" => config
      }
    }
  end

  @doc """
  Configure text2vec-weaviate vectorizer (Weaviate-hosted embeddings).

  ## Options
    - `:model` - Model name
    - `:base_url` - Base URL for API (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_weaviate(opts \\ []) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-weaviate",
      "moduleConfig" => %{
        "text2vec-weaviate" => config
      }
    }
  end

  @doc """
  Configure text2vec-azure-openai vectorizer.

  ## Options
    - `:resource_name` - Azure resource name (required)
    - `:deployment_id` - Azure deployment ID (required)
    - `:base_url` - Custom base URL (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_azure_openai(opts) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true),
        "resourceName" => Keyword.fetch!(opts, :resource_name),
        "deploymentId" => Keyword.fetch!(opts, :deployment_id)
      }
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{
      "vectorizer" => "text2vec-azure-openai",
      "moduleConfig" => %{
        "text2vec-azure-openai" => config
      }
    }
  end

  @doc """
  Configure text2vec-databricks vectorizer.

  ## Options
    - `:endpoint` - Databricks serving endpoint (required)
    - `:instruction` - Instruction prefix (optional)
    - `:vectorize_collection_name` - Whether to vectorize the collection name (default: true)
  """
  def text2vec_databricks(opts) do
    config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true),
        "endpoint" => Keyword.fetch!(opts, :endpoint)
      }
      |> maybe_put("instruction", Keyword.get(opts, :instruction))

    %{
      "vectorizer" => "text2vec-databricks",
      "moduleConfig" => %{
        "text2vec-databricks" => config
      }
    }
  end

  @doc """
  Configure multi2vec-google (Palm) for multimodal embeddings.

  ## Options
    - `:project_id` - Google Cloud project ID (required)
    - `:location` - Model location (required)
    - `:model` - Model ID (optional)
    - `:dimensions` - Output dimensions (optional)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
    - `:video_fields` - Video property fields (optional)
  """
  def multi2vec_google(opts) do
    config =
      %{
        "projectId" => Keyword.fetch!(opts, :project_id),
        "location" => Keyword.fetch!(opts, :location)
      }
      |> maybe_put("modelId", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))
      |> maybe_put("videoFields", format_multi2vec_fields(Keyword.get(opts, :video_fields)))

    %{
      "vectorizer" => "multi2vec-palm",
      "moduleConfig" => %{
        "multi2vec-palm" => config
      }
    }
  end

  @doc """
  Configure multi2vec-cohere for multimodal embeddings.

  ## Options
    - `:model` - Cohere model (optional)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
    - `:truncate` - Truncation mode (optional)
  """
  def multi2vec_cohere(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("truncate", Keyword.get(opts, :truncate))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "vectorizer" => "multi2vec-cohere",
      "moduleConfig" => %{
        "multi2vec-cohere" => config
      }
    }
  end

  @doc """
  Configure multi2vec-jinaai for multimodal embeddings.

  ## Options
    - `:model` - Jina model (optional)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
    - `:base_url` - API base URL (optional)
  """
  def multi2vec_jinaai(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "vectorizer" => "multi2vec-jinaai",
      "moduleConfig" => %{
        "multi2vec-jinaai" => config
      }
    }
  end

  @doc """
  Configure multi2vec-voyageai for multimodal embeddings.

  ## Options
    - `:model` - VoyageAI model (optional)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
    - `:base_url` - API base URL (optional)
  """
  def multi2vec_voyageai(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "vectorizer" => "multi2vec-voyageai",
      "moduleConfig" => %{
        "multi2vec-voyageai" => config
      }
    }
  end

  @doc """
  Configure multi2vec-nvidia for multimodal embeddings.

  ## Options
    - `:model` - NVIDIA model (optional)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
    - `:base_url` - API base URL (optional)
  """
  def multi2vec_nvidia(opts \\ []) do
    config =
      %{}
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "vectorizer" => "multi2vec-nvidia",
      "moduleConfig" => %{
        "multi2vec-nvidia" => config
      }
    }
  end

  @doc """
  Configure multi2vec-aws for multimodal embeddings.

  ## Options
    - `:model` - AWS model (required)
    - `:region` - AWS region (required)
    - `:service` - AWS service (bedrock or sagemaker)
    - `:image_fields` - Image property fields (optional)
    - `:text_fields` - Text property fields (optional)
  """
  def multi2vec_aws(opts) do
    config =
      %{
        "model" => Keyword.fetch!(opts, :model),
        "region" => Keyword.fetch!(opts, :region)
      }
      |> maybe_put("service", Keyword.get(opts, :service, "bedrock"))
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "vectorizer" => "multi2vec-aws",
      "moduleConfig" => %{
        "multi2vec-aws" => config
      }
    }
  end

  @doc """
  Configure img2vec-neural vectorizer for images.

  ## Options
    - `:image_fields` - Image property names
  """
  def img2vec_neural(opts \\ []) do
    config =
      %{}
      |> maybe_put("imageFields", Keyword.get(opts, :image_fields))

    %{
      "vectorizer" => "img2vec-neural",
      "moduleConfig" => %{
        "img2vec-neural" => config
      }
    }
  end

  @doc """
  Configure ref2vec-centroid vectorizer.

  Creates vectors from referenced objects using centroid calculation.

  ## Options
    - `:reference_properties` - List of reference property names
  """
  def ref2vec_centroid(opts \\ []) do
    config =
      %{}
      |> maybe_put("referenceProperties", Keyword.get(opts, :reference_properties))

    %{
      "vectorizer" => "ref2vec-centroid",
      "moduleConfig" => %{
        "ref2vec-centroid" => config
      }
    }
  end

  @doc """
  Configure Rotational Quantization (RQ).

  RQ is an advanced quantization method that uses rotational transformations.

  ## Options
    - `:enabled` - Enable RQ (default: true)
    - `:cache` - Enable cache (optional)
    - `:bits` - Number of bits for quantization (default: 8)
    - `:rescore_limit` - Number of candidates to rescore (optional)
    - `:training_limit` - Number of vectors to train on (optional)

  ## Example

      VectorConfig.hnsw_index(
        quantizer: VectorConfig.rotational_quantization(bits: 8, cache: true)
      )
  """
  @spec rotational_quantization(keyword()) :: map()
  def rotational_quantization(opts \\ []) do
    rq_config =
      %{
        "enabled" => Keyword.get(opts, :enabled, true)
      }
      |> maybe_put("cache", Keyword.get(opts, :cache))
      |> maybe_put("bits", Keyword.get(opts, :bits))
      |> maybe_put("rescoreLimit", Keyword.get(opts, :rescore_limit))
      |> maybe_put("trainingLimit", Keyword.get(opts, :training_limit))

    %{"rq" => rq_config}
  end

  @doc """
  Alias for `rotational_quantization/1`.

  ## Example

      VectorConfig.hnsw_index(
        quantizer: VectorConfig.rq(bits: 8, cache: true)
      )
  """
  @spec rq(keyword()) :: map()
  def rq(opts \\ []) do
    rotational_quantization(Keyword.put_new(opts, :enabled, true))
  end

  ## Helper Functions

  @doc "List all supported vectorizers"
  def supported_vectorizers, do: @supported_vectorizers

  @doc "List all distance metrics"
  def distance_metrics, do: @distance_metrics

  @doc "Check if vectorizer is valid"
  def valid_vectorizer?(vectorizer), do: vectorizer in @supported_vectorizers

  @doc "Check if distance metric is valid"
  def valid_distance?(metric), do: metric in @distance_metrics

  ## Private Helpers

  defp stringify_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} -> {key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(value), do: value

  defp build_module_opts(opts, config \\ []) do
    snake_to_camel = Keyword.get(config, :snake_to_camel, false)

    Enum.reduce(opts, %{}, fn {key, value}, acc ->
      key_str =
        if snake_to_camel do
          key |> Atom.to_string() |> Macro.camelize() |> lcfirst()
        else
          Atom.to_string(key)
        end

      Map.put(acc, key_str, value)
    end)
  end

  defp lcfirst(<<first::utf8, rest::binary>>), do: String.downcase(<<first::utf8>>) <> rest

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_multi2vec_fields(nil), do: nil

  defp format_multi2vec_fields(fields) when is_list(fields) do
    Enum.map(fields, fn
      field when is_binary(field) -> %{"name" => field}
      %{name: name} = field -> %{"name" => name} |> maybe_put("weight", field[:weight])
      field when is_map(field) -> field
    end)
  end

  defp distance_to_string(:cosine), do: "cosine"
  defp distance_to_string(:dot), do: "dot"
  defp distance_to_string(:l2_squared), do: "l2-squared"
  defp distance_to_string(:hamming), do: "hamming"
  defp distance_to_string(:manhattan), do: "manhattan"
  defp distance_to_string(distance) when is_binary(distance), do: distance

  defp maybe_add_dynamic_ef(config, opts) do
    config =
      if min = Keyword.get(opts, :dynamic_ef_min) do
        Map.put(config, "dynamicEfMin", min)
      else
        config
      end

    config =
      if max = Keyword.get(opts, :dynamic_ef_max) do
        Map.put(config, "dynamicEfMax", max)
      else
        config
      end

    if factor = Keyword.get(opts, :dynamic_ef_factor) do
      Map.put(config, "dynamicEfFactor", factor)
    else
      config
    end
  end

  defp maybe_add_vector_cache(config, opts) do
    if max_objects = Keyword.get(opts, :vector_cache_max_objects) do
      Map.put(config, "vectorCacheMaxObjects", max_objects)
    else
      config
    end
  end

  defp maybe_add_flat_search_cutoff(config, opts) do
    if cutoff = Keyword.get(opts, :flat_search_cutoff) do
      Map.put(config, "flatSearchCutoff", cutoff)
    else
      config
    end
  end

  defp maybe_add_cleanup_interval(config, opts) do
    if interval = Keyword.get(opts, :cleanup_interval_seconds) do
      Map.put(config, "cleanupIntervalSeconds", interval)
    else
      config
    end
  end

  defp maybe_add_quantization(config, opts) do
    config =
      if pq_enabled = Keyword.get(opts, :pq_enabled) do
        pq_config = product_quantization(enabled: pq_enabled)
        Map.merge(config, pq_config)
      else
        config
      end

    config =
      if bq_enabled = Keyword.get(opts, :bq_enabled) do
        bq_config = binary_quantization(enabled: bq_enabled)
        Map.merge(config, bq_config)
      else
        config
      end

    config =
      if sq_enabled = Keyword.get(opts, :sq_enabled) do
        sq_config = scalar_quantization(enabled: sq_enabled)
        Map.merge(config, sq_config)
      else
        config
      end

    if rq_enabled = Keyword.get(opts, :rq_enabled) do
      rq_config = rotational_quantization(enabled: rq_enabled)
      Map.merge(config, rq_config)
    else
      config
    end
  end

  defp maybe_add_filter_strategy(config, opts) do
    case Keyword.get(opts, :filter_strategy) do
      nil -> config
      :sweeping -> Map.put(config, "filterStrategy", "sweeping")
      :acorn -> Map.put(config, "filterStrategy", "acorn")
      strategy when is_binary(strategy) -> Map.put(config, "filterStrategy", strategy)
    end
  end

  defp maybe_add_quantizer_option(config, opts) do
    case Keyword.get(opts, :quantizer) do
      nil -> config
      quantizer when is_map(quantizer) -> Map.merge(config, quantizer)
    end
  end
end
