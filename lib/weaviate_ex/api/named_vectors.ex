defmodule WeaviateEx.API.NamedVectors do
  @moduledoc """
  Named vectors configuration for multi-vector collections.

  Enables creating collections with multiple named vectors, each with
  its own vectorizer and configuration.

  ## Examples

      # Create collection with multiple named vectors
      vectorizer_config = NamedVectors.build_vectorizer_config([
        NamedVectors.text2vec_openai(
          name: "title_vector",
          source_properties: ["title"],
          model: "text-embedding-3-small"
        ),
        NamedVectors.text2vec_openai(
          name: "content_vector",
          source_properties: ["content"],
          model: "text-embedding-3-large",
          dimensions: 1024
        ),
        NamedVectors.self_provided(name: "custom_vector")
      ])

      WeaviateEx.Collections.create("Article", %{
        vectorConfig: vectorizer_config,
        properties: [...]
      })
  """

  @type opts :: keyword()
  @type config :: map()

  @doc """
  Create a self-provided named vector (no automatic vectorization).

  ## Options

    - `:name` - Vector name (required)
    - `:vector_index_type` - Index type: "hnsw", "flat", "dynamic" (default: "hnsw")
    - `:hnsw_opts` - HNSW index options
    - `:quantizer` - Quantization config

  ## Examples

      NamedVectors.self_provided(name: "custom_vector")
  """
  @spec self_provided(opts()) :: config()
  def self_provided(opts) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"none" => %{}},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
    |> maybe_add_quantizer(opts)
  end

  @doc """
  Create a text2vec-openai named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - OpenAI model name
    - `:dimensions` - Output dimensions
    - `:base_url` - Custom API endpoint
    - `:vectorize_collection_name` - Whether to include collection name (default: true)

  ## Examples

      NamedVectors.text2vec_openai(
        name: "title_vector",
        source_properties: ["title"],
        model: "text-embedding-3-small"
      )
  """
  @spec text2vec_openai(opts()) :: config()
  def text2vec_openai(opts) do
    build_named_vector("text2vec-openai", opts, [:model, :dimensions, :base_url])
  end

  @doc """
  Create a text2vec-cohere named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - Cohere model name
    - `:truncate` - Truncation mode

  ## Examples

      NamedVectors.text2vec_cohere(name: "cohere_vector", model: "embed-v4.0")
  """
  @spec text2vec_cohere(opts()) :: config()
  def text2vec_cohere(opts) do
    build_named_vector("text2vec-cohere", opts, [:model, :truncate, :base_url])
  end

  @doc """
  Create a text2vec-huggingface named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - HuggingFace model name
    - `:passage_model` - Model for passages
    - `:query_model` - Model for queries
    - `:wait_for_model` - Wait for model to load
    - `:use_gpu` - Use GPU inference
    - `:use_cache` - Use caching

  ## Examples

      NamedVectors.text2vec_huggingface(name: "hf_vector")
  """
  @spec text2vec_huggingface(opts()) :: config()
  def text2vec_huggingface(opts) do
    build_named_vector("text2vec-huggingface", opts, [
      :model,
      :passage_model,
      :query_model,
      :wait_for_model,
      :use_gpu,
      :use_cache
    ])
  end

  @doc """
  Create a text2vec-voyageai named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - VoyageAI model name (e.g., "voyage-3", "voyage-3.5")
    - `:truncation` - Truncation mode
    - `:base_url` - Custom API endpoint

  ## Examples

      NamedVectors.text2vec_voyageai(name: "voyage_vector", model: "voyage-3")
  """
  @spec text2vec_voyageai(opts()) :: config()
  def text2vec_voyageai(opts) do
    build_named_vector("text2vec-voyageai", opts, [:model, :truncation, :base_url])
  end

  @doc """
  Create a text2vec-jinaai named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - Jina model name (e.g., "jina-embeddings-v3", "jina-embeddings-v4")
    - `:dimensions` - Output dimensions
    - `:base_url` - Custom API endpoint

  ## Examples

      NamedVectors.text2vec_jinaai(name: "jina_vector", model: "jina-embeddings-v3")
  """
  @spec text2vec_jinaai(opts()) :: config()
  def text2vec_jinaai(opts) do
    build_named_vector("text2vec-jinaai", opts, [:model, :dimensions, :base_url])
  end

  @doc """
  Create a text2vec-ollama named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - Ollama model name
    - `:api_endpoint` - Ollama API endpoint (default: http://localhost:11434)

  ## Examples

      NamedVectors.text2vec_ollama(
        name: "ollama_vector",
        model: "llama2",
        api_endpoint: "http://localhost:11434"
      )
  """
  @spec text2vec_ollama(opts()) :: config()
  def text2vec_ollama(opts) do
    build_named_vector("text2vec-ollama", opts, [:model, :api_endpoint])
  end

  @doc """
  Create a text2vec-mistral named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - Mistral model name

  ## Examples

      NamedVectors.text2vec_mistral(name: "mistral_vector", model: "mistral-embed")
  """
  @spec text2vec_mistral(opts()) :: config()
  def text2vec_mistral(opts) do
    build_named_vector("text2vec-mistral", opts, [:model, :base_url])
  end

  @doc """
  Create a text2vec-nvidia named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - NVIDIA model name
    - `:base_url` - Custom API endpoint

  ## Examples

      NamedVectors.text2vec_nvidia(name: "nvidia_vector")
  """
  @spec text2vec_nvidia(opts()) :: config()
  def text2vec_nvidia(opts) do
    build_named_vector("text2vec-nvidia", opts, [:model, :base_url])
  end

  @doc """
  Create a text2vec-azure-openai named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:resource_name` - Azure resource name (required)
    - `:deployment_id` - Azure deployment ID (required)
    - `:base_url` - Custom API endpoint

  ## Examples

      NamedVectors.text2vec_azure_openai(
        name: "azure_vector",
        resource_name: "my-resource",
        deployment_id: "my-deployment"
      )
  """
  @spec text2vec_azure_openai(opts()) :: config()
  def text2vec_azure_openai(opts) do
    vectorizer_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("resourceName", Keyword.get(opts, :resource_name))
      |> maybe_put("deploymentId", Keyword.get(opts, :deployment_id))
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_add_source_properties(opts)

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"text2vec-azure-openai" => vectorizer_config},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
  end

  @doc """
  Create a text2vec-google (Vertex AI) named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:project_id` - Google Cloud project ID (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - Model name
    - `:api_endpoint` - API endpoint

  ## Examples

      NamedVectors.text2vec_google_vertex(
        name: "vertex_vector",
        project_id: "my-project"
      )
  """
  @spec text2vec_google_vertex(opts()) :: config()
  def text2vec_google_vertex(opts) do
    vectorizer_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true),
        "projectId" => Keyword.fetch!(opts, :project_id)
      }
      |> maybe_put("modelId", Keyword.get(opts, :model))
      |> maybe_put("apiEndpoint", Keyword.get(opts, :api_endpoint))
      |> maybe_add_source_properties(opts)

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"text2vec-palm" => vectorizer_config},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
  end

  @doc """
  Create a multi2vec-clip named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:image_fields` - Image property names
    - `:text_fields` - Text property names

  ## Examples

      NamedVectors.multi2vec_clip(
        name: "clip_vector",
        image_fields: ["image"],
        text_fields: ["caption"]
      )
  """
  @spec multi2vec_clip(opts()) :: config()
  def multi2vec_clip(opts) do
    vectorizer_config =
      %{}
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"multi2vec-clip" => vectorizer_config},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
  end

  @doc """
  Create a multi2vec-bind named vector.

  ## Options

    - `:name` - Vector name (required)
    - `:image_fields` - Image property names
    - `:text_fields` - Text property names
    - `:audio_fields` - Audio property names
    - `:video_fields` - Video property names
    - `:depth_fields` - Depth property names
    - `:thermal_fields` - Thermal property names
    - `:imu_fields` - IMU property names

  ## Examples

      NamedVectors.multi2vec_bind(name: "bind_vector")
  """
  @spec multi2vec_bind(opts()) :: config()
  def multi2vec_bind(opts) do
    vectorizer_config =
      %{}
      |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))
      |> maybe_put("audioFields", format_multi2vec_fields(Keyword.get(opts, :audio_fields)))
      |> maybe_put("videoFields", format_multi2vec_fields(Keyword.get(opts, :video_fields)))
      |> maybe_put("depthFields", format_multi2vec_fields(Keyword.get(opts, :depth_fields)))
      |> maybe_put("thermalFields", format_multi2vec_fields(Keyword.get(opts, :thermal_fields)))
      |> maybe_put("imuFields", format_multi2vec_fields(Keyword.get(opts, :imu_fields)))

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"multi2vec-bind" => vectorizer_config},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
  end

  @doc """
  Build vectorConfig map for collection creation from list of named vector configs.

  ## Examples

      configs = [
        NamedVectors.text2vec_openai(name: "title_vector"),
        NamedVectors.self_provided(name: "custom_vector")
      ]

      NamedVectors.build_vectorizer_config(configs)
  """
  @spec build_vectorizer_config([config()]) :: map()
  def build_vectorizer_config(named_vectors) when is_list(named_vectors) do
    Enum.reduce(named_vectors, %{}, fn config, acc ->
      name = config["name"]
      vector_config = Map.drop(config, ["name"])
      Map.put(acc, name, vector_config)
    end)
  end

  # Private helpers

  defp build_named_vector(vectorizer_name, opts, extra_keys) do
    base_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_add_source_properties(opts)

    vectorizer_config =
      Enum.reduce(extra_keys, base_config, fn key, acc ->
        param_name = key_to_param_name(key)
        maybe_put(acc, param_name, Keyword.get(opts, key))
      end)

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{vectorizer_name => vectorizer_config},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
  end

  defp key_to_param_name(:model), do: "model"
  defp key_to_param_name(:dimensions), do: "dimensions"
  defp key_to_param_name(:base_url), do: "baseURL"
  defp key_to_param_name(:api_endpoint), do: "apiEndpoint"
  defp key_to_param_name(:truncate), do: "truncate"
  defp key_to_param_name(:truncation), do: "truncation"
  defp key_to_param_name(:passage_model), do: "passageModel"
  defp key_to_param_name(:query_model), do: "queryModel"
  defp key_to_param_name(:wait_for_model), do: "waitForModel"
  defp key_to_param_name(:use_gpu), do: "useGPU"
  defp key_to_param_name(:use_cache), do: "useCache"
  defp key_to_param_name(key), do: Atom.to_string(key)

  defp build_vector_index_config(opts) do
    case Keyword.get(opts, :hnsw_opts) do
      nil -> %{}
      hnsw_opts -> %{"hnsw" => hnsw_opts}
    end
  end

  defp maybe_add_quantizer(config, opts) do
    case Keyword.get(opts, :quantizer) do
      nil -> config
      quantizer -> Map.merge(config, quantizer)
    end
  end

  defp maybe_add_source_properties(config, opts) do
    case Keyword.get(opts, :source_properties) do
      nil -> config
      props -> Map.put(config, "properties", props)
    end
  end

  defp format_multi2vec_fields(nil), do: nil

  defp format_multi2vec_fields(fields) when is_list(fields) do
    Enum.map(fields, fn
      field when is_binary(field) -> %{"name" => field}
      %{name: name} = field -> %{"name" => name} |> maybe_put("weight", field[:weight])
      field when is_map(field) -> field
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
