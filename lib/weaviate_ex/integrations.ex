defmodule WeaviateEx.Integrations do
  @moduledoc """
  API integration header builders for external AI providers.

  Weaviate uses custom HTTP headers to pass API keys for various
  AI service integrations (vectorizers, generative modules, rerankers).

  ## Examples

      # Single provider
      headers = Integrations.openai(api_key: "sk-...")

      # Multiple providers
      headers = Integrations.merge([
        Integrations.openai(api_key: "sk-..."),
        Integrations.cohere(api_key: "cohere-key"),
        Integrations.huggingface(api_key: "hf-key")
      ])

      # Use with client
      WeaviateEx.Client.new(
        base_url: "http://localhost:8080",
        headers: headers
      )
  """

  @type headers :: [{String.t(), String.t()}]

  @doc """
  OpenAI integration headers.

  ## Options

    - `:api_key` - OpenAI API key (required)
    - `:organization` - OpenAI organization ID (optional)
    - `:requests_per_minute_embeddings` - Rate limit for embedding requests per minute (optional)
    - `:tokens_per_minute_embeddings` - Rate limit for tokens per minute for embeddings (optional)
    - `:base_url` - Custom base URL for the API (optional)

  ## Examples

      Integrations.openai(api_key: "sk-...")
      Integrations.openai(api_key: "sk-...", organization: "org-123")
      Integrations.openai(api_key: "sk-...", requests_per_minute_embeddings: 3000)
  """
  @spec openai(keyword()) :: headers()
  def openai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    [{"X-OpenAI-Api-Key", api_key}]
    |> maybe_add("X-OpenAI-Organization", Keyword.get(opts, :organization))
    |> maybe_add("X-OpenAI-BaseURL", Keyword.get(opts, :base_url))
    |> maybe_add_rate_limit(
      "X-OpenAI-Ratelimit-RequestPM-Embedding",
      Keyword.get(opts, :requests_per_minute_embeddings)
    )
    |> maybe_add_rate_limit(
      "X-OpenAI-Ratelimit-TokenPM-Embedding",
      Keyword.get(opts, :tokens_per_minute_embeddings)
    )
  end

  @doc """
  Cohere integration headers.

  ## Options

    - `:api_key` - Cohere API key (required)
    - `:requests_per_minute_embeddings` - Rate limit for embedding requests per minute (optional)
    - `:base_url` - Custom base URL for the API (optional)

  ## Examples

      Integrations.cohere(api_key: "cohere-key")
      Integrations.cohere(api_key: "cohere-key", requests_per_minute_embeddings: 1000)
  """
  @spec cohere(keyword()) :: headers()
  def cohere(opts) do
    [{"X-Cohere-Api-Key", Keyword.fetch!(opts, :api_key)}]
    |> maybe_add("X-Cohere-BaseURL", Keyword.get(opts, :base_url))
    |> maybe_add_rate_limit(
      "X-Cohere-Ratelimit-RequestPM-Embedding",
      Keyword.get(opts, :requests_per_minute_embeddings)
    )
  end

  @doc """
  HuggingFace integration headers.

  ## Options

    - `:api_key` - HuggingFace API key (required)

  ## Examples

      Integrations.huggingface(api_key: "hf-key")
  """
  @spec huggingface(keyword()) :: headers()
  def huggingface(opts) do
    [{"X-HuggingFace-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  VoyageAI integration headers.

  ## Options

    - `:api_key` - VoyageAI API key (required)

  ## Examples

      Integrations.voyageai(api_key: "voyage-key")
  """
  @spec voyageai(keyword()) :: headers()
  def voyageai(opts) do
    [{"X-VoyageAI-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  JinaAI integration headers.

  ## Options

    - `:api_key` - JinaAI API key (required)

  ## Examples

      Integrations.jinaai(api_key: "jina-key")
  """
  @spec jinaai(keyword()) :: headers()
  def jinaai(opts) do
    [{"X-JinaAI-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  Mistral integration headers.

  ## Options

    - `:api_key` - Mistral API key (required)

  ## Examples

      Integrations.mistral(api_key: "mistral-key")
  """
  @spec mistral(keyword()) :: headers()
  def mistral(opts) do
    [{"X-Mistral-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  Anthropic integration headers.

  ## Options

    - `:api_key` - Anthropic API key (required)

  ## Examples

      Integrations.anthropic(api_key: "anthropic-key")
  """
  @spec anthropic(keyword()) :: headers()
  def anthropic(opts) do
    [{"X-Anthropic-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  Google/Vertex AI integration headers.

  ## Options

    - `:api_key` - Google API key (required)
    - `:vertex` - Set to true for Vertex AI (optional)

  ## Examples

      Integrations.google(api_key: "google-key")
      Integrations.google(api_key: "google-key", vertex: true)
  """
  @spec google(keyword()) :: headers()
  def google(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    [{"X-Google-Api-Key", api_key}]
    |> maybe_add("X-Google-Vertex", if(Keyword.get(opts, :vertex), do: "true"))
  end

  @doc """
  Azure OpenAI integration headers.

  ## Options

    - `:api_key` - Azure OpenAI API key (required)

  ## Examples

      Integrations.azure_openai(api_key: "azure-key")
  """
  @spec azure_openai(keyword()) :: headers()
  def azure_openai(opts) do
    [{"X-Azure-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  AWS integration headers.

  ## Options

    - `:access_key` - AWS access key ID (required)
    - `:secret_key` - AWS secret access key (required)
    - `:session_token` - AWS session token (optional, for temporary credentials)

  ## Examples

      Integrations.aws(access_key: "AKIA...", secret_key: "secret")
      Integrations.aws(access_key: "AKIA...", secret_key: "secret", session_token: "token")
  """
  @spec aws(keyword()) :: headers()
  def aws(opts) do
    [
      {"X-AWS-Access-Key", Keyword.fetch!(opts, :access_key)},
      {"X-AWS-Secret-Key", Keyword.fetch!(opts, :secret_key)}
    ]
    |> maybe_add("X-AWS-Session-Token", Keyword.get(opts, :session_token))
  end

  @doc """
  NVIDIA integration headers.

  ## Options

    - `:api_key` - NVIDIA API key (required)

  ## Examples

      Integrations.nvidia(api_key: "nvidia-key")
  """
  @spec nvidia(keyword()) :: headers()
  def nvidia(opts) do
    [{"X-NVIDIA-Api-Key", Keyword.fetch!(opts, :api_key)}]
  end

  @doc """
  Databricks integration headers.

  ## Options

    - `:token` - Databricks access token (required)

  ## Examples

      Integrations.databricks(token: "dapi...")
  """
  @spec databricks(keyword()) :: headers()
  def databricks(opts) do
    [{"X-Databricks-Token", Keyword.fetch!(opts, :token)}]
  end

  @doc """
  Merge multiple integration header lists.

  ## Examples

      headers = Integrations.merge([
        Integrations.openai(api_key: "sk-..."),
        Integrations.cohere(api_key: "cohere-key")
      ])
  """
  @spec merge([headers()]) :: headers()
  def merge(header_lists) when is_list(header_lists) do
    List.flatten(header_lists)
  end

  # Private helpers

  defp maybe_add(headers, _key, nil), do: headers
  defp maybe_add(headers, key, value), do: headers ++ [{key, value}]

  defp maybe_add_rate_limit(headers, _key, nil), do: headers

  defp maybe_add_rate_limit(headers, key, value) when is_integer(value) do
    headers ++ [{key, Integer.to_string(value)}]
  end
end
