defmodule WeaviateEx.API.RerankerConfig do
  @moduledoc """
  Reranker configuration for collections.

  Configure reranking models to improve search result relevance.
  Rerankers re-score search results using more sophisticated models
  to improve ranking quality.

  ## Built-in Providers

    * `cohere/2` - Cohere Rerank
    * `transformers/1` - Local transformers model
    * `voyageai/2` - Voyage AI
    * `jinaai/2` - Jina AI
    * `nvidia/2` - NVIDIA Rerank
    * `contextualai/2` - Contextual AI Rerank

  ## Custom Providers

    * `custom/2` - Any unlisted provider

  ## Examples

      # Cohere reranker
      config = RerankerConfig.cohere("rerank-english-v3.0")
      Collections.create("Article", %{
        properties: [...],
        reranker_config: config
      })

      # Custom reranker
      config = RerankerConfig.custom("my-reranker",
        api_endpoint: "https://reranker.example.com",
        model: "rerank-v1"
      )
  """

  @type config :: %{String.t() => map()}

  @doc """
  Create a Cohere reranker configuration.

  ## Arguments

    - `model` - Cohere model name (default: "rerank-english-v2.0")

  ## Options

    - `:base_url` - Custom API endpoint URL

  ## Examples

      RerankerConfig.cohere()
      RerankerConfig.cohere("rerank-english-v3.0")
      RerankerConfig.cohere("rerank-multilingual-v3.0", base_url: "https://api.cohere.ai")
  """
  @spec cohere(String.t(), keyword()) :: config()
  def cohere(model \\ "rerank-english-v2.0", opts \\ []) do
    config =
      %{"model" => model}
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{"reranker-cohere" => config}
  end

  @doc """
  Create a local transformers reranker configuration.

  Uses a locally deployed transformers model for reranking.

  ## Options

    - `:query_key` - Key for the query in the input
    - `:passage_key` - Key for the passage in the input
    - `:inference_url` - URL of the inference service

  ## Examples

      RerankerConfig.transformers()
      RerankerConfig.transformers(inference_url: "http://localhost:8080")
  """
  @spec transformers(keyword()) :: config()
  def transformers(opts \\ []) do
    config =
      %{}
      |> maybe_put("queryKey", Keyword.get(opts, :query_key))
      |> maybe_put("passageKey", Keyword.get(opts, :passage_key))
      |> maybe_put("inferenceUrl", Keyword.get(opts, :inference_url))

    %{"reranker-transformers" => config}
  end

  @doc """
  Create a Voyage AI reranker configuration.

  ## Arguments

    - `model` - Voyage AI model name

  ## Options

    - `:base_url` - Custom API endpoint URL
    - `:truncation` - Truncation mode

  ## Examples

      RerankerConfig.voyageai("rerank-1")
      RerankerConfig.voyageai("rerank-lite-1", base_url: "https://api.voyageai.com")
  """
  @spec voyageai(String.t(), keyword()) :: config()
  def voyageai(model, opts \\ []) do
    config =
      %{"model" => model}
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("truncation", Keyword.get(opts, :truncation))

    %{"reranker-voyageai" => config}
  end

  @doc """
  Create a Jina AI reranker configuration.

  ## Arguments

    - `model` - Jina AI model name

  ## Options

    - `:base_url` - Custom API endpoint URL

  ## Examples

      RerankerConfig.jinaai("jina-reranker-v1-base-en")
      RerankerConfig.jinaai("jina-reranker-v1-turbo-en")
  """
  @spec jinaai(String.t(), keyword()) :: config()
  def jinaai(model, opts \\ []) do
    config =
      %{"model" => model}
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{"reranker-jinaai" => config}
  end

  @doc """
  Create an NVIDIA reranker configuration.

  ## Arguments

    - `model` - NVIDIA model name (optional)

  ## Options

    - `:base_url` - Custom API endpoint URL

  ## Examples

      RerankerConfig.nvidia()
      RerankerConfig.nvidia("nvidia-nemo-retriever-qa-mistral-4b-instruct")
      RerankerConfig.nvidia("nvidia-rerank", base_url: "https://api.nvidia.com")
  """
  @spec nvidia(String.t() | nil, keyword()) :: config()
  def nvidia(model \\ nil, opts \\ []) do
    config =
      %{}
      |> maybe_put("model", model)
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))

    %{"reranker-nvidia" => config}
  end

  @doc """
  Create a Contextual AI reranker configuration.

  ## Arguments

    - `model` - Contextual AI model name (optional)

  ## Options

    - `:base_url` - Custom API endpoint URL
    - `:instruction` - Instruction for the reranker

  ## Examples

      RerankerConfig.contextualai()
      RerankerConfig.contextualai("ctxai-rerank-v1")
      RerankerConfig.contextualai("ctxai-rerank", base_url: "https://api.contextual.ai", instruction: "Rank by relevance")
  """
  @spec contextualai(String.t() | nil, keyword()) :: config()
  def contextualai(model \\ nil, opts \\ []) do
    config =
      %{}
      |> maybe_put("model", model)
      |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      |> maybe_put("instruction", Keyword.get(opts, :instruction))

    %{"reranker-contextualai" => config}
  end

  @doc """
  Create a custom reranker configuration for unlisted providers.

  All options are passed through with automatic snake_case to camelCase conversion.

  ## Arguments

    - `name` - Identifier for the custom provider
    - `opts` - Provider configuration options

  ## Common Options

    - `:api_endpoint` - API endpoint URL
    - `:model` - Model identifier
    - `:base_url` - Base URL for the API

  ## Examples

      RerankerConfig.custom("my-reranker",
        api_endpoint: "https://reranker.example.com",
        model: "rerank-v1"
      )

      RerankerConfig.custom("local-reranker",
        api_endpoint: "http://localhost:9000",
        max_tokens: 512,
        batch_size: 32
      )
  """
  @spec custom(String.t(), keyword()) :: config()
  def custom(name, opts) when is_binary(name) do
    options =
      opts
      |> Enum.map(fn {k, v} -> {camelize(k), v} end)
      |> Map.new()

    %{"reranker-custom" => Map.put(options, :_custom_name, name)}
  end

  @doc """
  Disable reranking.

  ## Examples

      RerankerConfig.none()
  """
  @spec none() :: config()
  def none do
    %{"none" => %{}}
  end

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp camelize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> camelize_string()
  end

  defp camelize_string(string) do
    [first | rest] = String.split(string, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end
end
