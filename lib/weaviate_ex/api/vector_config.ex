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

  @doc "Configure text2vec-cohere vectorizer"
  def text2vec_cohere(opts \\ []) do
    %{
      "vectorizer" => "text2vec-cohere",
      "moduleConfig" => %{
        "text2vec-cohere" => build_module_opts(opts)
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

  @doc "Configure text2vec-palm vectorizer"
  def text2vec_palm(opts \\ []) do
    %{
      "vectorizer" => "text2vec-palm",
      "moduleConfig" => %{
        "text2vec-palm" => build_module_opts(opts, snake_to_camel: true)
      }
    }
  end

  @doc "Configure text2vec-aws vectorizer"
  def text2vec_aws(opts \\ []) do
    %{
      "vectorizer" => "text2vec-aws",
      "moduleConfig" => %{
        "text2vec-aws" => build_module_opts(opts)
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

  @doc "Configure HNSW index"
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
    index_config = maybe_add_quantization(index_config, opts)

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
        Map.put(pq_config, "encoder", encoder)
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

  @doc "Configure Scalar Quantization (SQ)"
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
      if cache = Keyword.get(opts, :cache) do
        Map.put(sq_config, "cache", cache)
      else
        sq_config
      end

    %{"sq" => sq_config}
  end

  ## Builder Pattern Functions

  @doc "Create new collection configuration"
  def new(class_name) do
    %{"class" => class_name}
  end

  @doc "Add vectorizer to configuration"
  def with_vectorizer(config, vectorizer, opts \\ []) do
    vectorizer_config =
      case vectorizer do
        :text2vec_openai -> text2vec_openai(opts)
        :text2vec_cohere -> text2vec_cohere(opts)
        :text2vec_huggingface -> text2vec_huggingface(opts)
        :text2vec_transformers -> text2vec_transformers(opts)
        :text2vec_contextionary -> text2vec_contextionary(opts)
        :text2vec_gpt4all -> text2vec_gpt4all(opts)
        :text2vec_palm -> text2vec_palm(opts)
        :text2vec_aws -> text2vec_aws(opts)
        :multi2vec_clip -> multi2vec_clip(opts)
        :multi2vec_bind -> multi2vec_bind(opts)
        :none -> none()
      end

    Map.merge(config, vectorizer_config)
  end

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

  @doc "Add properties to configuration"
  def with_properties(config, properties) do
    Map.put(config, "properties", properties)
  end

  @doc "Add named vectors configuration"
  def with_named_vectors(config, vectors) do
    Map.put(config, "vectorConfig", vectors)
  end

  @doc "Add replication configuration"
  def with_replication_config(config, opts \\ []) do
    replication_config = %{
      "factor" => Keyword.get(opts, :factor, 1)
    }

    Map.put(config, "replicationConfig", replication_config)
  end

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

    if sq_enabled = Keyword.get(opts, :sq_enabled) do
      sq_config = scalar_quantization(enabled: sq_enabled)
      Map.merge(config, sq_config)
    else
      config
    end
  end
end
