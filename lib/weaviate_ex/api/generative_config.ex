defmodule WeaviateEx.API.GenerativeConfig do
  @moduledoc """
  Configuration builders for Weaviate generative search (RAG) providers.

  This module provides helper functions to configure generative AI modules
  for collection schema definitions. These configurations enable RAG
  (Retrieval Augmented Generation) capabilities on collections.

  ## Supported Providers

  - **OpenAI** - GPT-4, GPT-3.5, O1/O3 models
  - **Azure OpenAI** - Azure-hosted OpenAI models
  - **Anthropic** - Claude 3.5 Sonnet, Claude 3 Opus/Haiku
  - **Cohere** - Command R/R+ models
  - **Mistral** - Mistral Large, Medium models
  - **Google** - Gemini Pro, PaLM models
  - **AWS** - Bedrock/SageMaker hosted models
  - **Ollama** - Self-hosted models
  - **Databricks** - Foundation Model APIs
  - **NVIDIA** - NIM models
  - **FriendliAI** - Serverless inference
  - **XAI** - Grok models
  - **Anyscale** - Endpoints
  - **ContextualAI** - Grounded generation

  ## Examples

      # Configure OpenAI for a collection
      config = GenerativeConfig.openai(model: "gpt-4")
      Collections.create("Article", %{
        properties: [...],
        generative_config: config
      })

      # Configure Anthropic with options
      config = GenerativeConfig.anthropic(
        model: "claude-3-5-sonnet-latest",
        temperature: 0.7,
        max_tokens: 4096
      )

      # Configure Ollama for local inference
      config = GenerativeConfig.ollama(
        model: "llama3",
        api_endpoint: "http://localhost:11434"
      )
  """

  @type provider ::
          :openai
          | :anthropic
          | :cohere
          | :mistral
          | :google
          | :aws
          | :ollama
          | :databricks
          | :nvidia
          | :friendliai
          | :xai
          | :anyscale
          | :contextualai

  @type config :: %{String.t() => map()}

  @providers [
    :openai,
    :anthropic,
    :cohere,
    :mistral,
    :google,
    :aws,
    :ollama,
    :databricks,
    :nvidia,
    :friendliai,
    :xai,
    :anyscale,
    :contextualai
  ]

  @provider_modules %{
    openai: "generative-openai",
    anthropic: "generative-anthropic",
    cohere: "generative-cohere",
    mistral: "generative-mistral",
    google: "generative-palm",
    aws: "generative-aws",
    ollama: "generative-ollama",
    databricks: "generative-databricks",
    nvidia: "generative-nvidia",
    friendliai: "generative-friendliai",
    xai: "generative-xai",
    anyscale: "generative-anyscale",
    contextualai: "generative-contextualai"
  }

  @doc """
  List all supported generative providers.

  ## Examples

      GenerativeConfig.providers()
      # => [:openai, :anthropic, :cohere, ...]
  """
  @spec providers() :: [provider()]
  def providers, do: @providers

  @doc """
  Get the Weaviate module name for a provider.

  ## Examples

      GenerativeConfig.provider_module(:openai)
      # => "generative-openai"

      GenerativeConfig.provider_module(:google)
      # => "generative-palm"
  """
  @spec provider_module(provider()) :: String.t()
  def provider_module(provider) when provider in @providers do
    @provider_modules[provider]
  end

  @doc """
  Create OpenAI generative configuration.

  ## Options

  - `:model` - Model name (e.g., "gpt-4", "gpt-3.5-turbo")
  - `:temperature` - Sampling temperature (0.0-2.0)
  - `:max_tokens` - Maximum tokens to generate
  - `:base_url` - Custom API endpoint URL

  ## Examples

      GenerativeConfig.openai(model: "gpt-4")

      GenerativeConfig.openai(
        model: "gpt-4-turbo",
        temperature: 0.7,
        max_tokens: 1000
      )
  """
  @spec openai(keyword()) :: config()
  def openai(opts \\ []) do
    build_config("generative-openai", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:base_url, :baseURL}
    ])
  end

  @doc """
  Create Azure OpenAI generative configuration.

  ## Options

  - `:resource_name` - Azure resource name (required)
  - `:deployment_id` - Deployment ID (required)
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate

  ## Examples

      GenerativeConfig.azure_openai(
        resource_name: "my-resource",
        deployment_id: "gpt-4-deployment"
      )
  """
  @spec azure_openai(keyword()) :: config()
  def azure_openai(opts \\ []) do
    build_config("generative-openai", opts, [
      {:resource_name, :resourceName},
      {:deployment_id, :deploymentId},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens}
    ])
  end

  @doc """
  Create Cohere generative configuration.

  ## Options

  - `:model` - Model name (e.g., "command-r-plus", "command-r")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:k` - Top-k sampling parameter
  - `:p` - Top-p (nucleus) sampling parameter

  ## Examples

      GenerativeConfig.cohere(model: "command-r-plus")

      GenerativeConfig.cohere(
        model: "command-r",
        temperature: 0.8,
        k: 5
      )
  """
  @spec cohere(keyword()) :: config()
  def cohere(opts \\ []) do
    build_config("generative-cohere", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:k, :k},
      {:p, :p}
    ])
  end

  @doc """
  Create Anthropic generative configuration.

  ## Options

  - `:model` - Model name (e.g., "claude-3-5-sonnet-latest")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:top_k` - Top-k sampling parameter
  - `:top_p` - Top-p (nucleus) sampling parameter

  ## Examples

      GenerativeConfig.anthropic(model: "claude-3-5-sonnet-latest")

      GenerativeConfig.anthropic(
        model: "claude-3-opus-20240229",
        temperature: 0.7,
        max_tokens: 4096
      )
  """
  @spec anthropic(keyword()) :: config()
  def anthropic(opts \\ []) do
    build_config("generative-anthropic", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:top_k, :topK},
      {:top_p, :topP}
    ])
  end

  @doc """
  Create Mistral generative configuration.

  ## Options

  - `:model` - Model name (e.g., "mistral-large-latest")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:base_url` - Custom API endpoint URL

  ## Examples

      GenerativeConfig.mistral(model: "mistral-large-latest")
  """
  @spec mistral(keyword()) :: config()
  def mistral(opts \\ []) do
    build_config("generative-mistral", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:base_url, :baseURL}
    ])
  end

  @doc """
  Create Google (Gemini/PaLM) generative configuration.

  ## Options

  - `:model` - Model name (e.g., "gemini-pro", "gemini-1.5-pro")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:project_id` - GCP project ID

  ## Examples

      GenerativeConfig.google(model: "gemini-1.5-pro")

      GenerativeConfig.google(
        model: "gemini-pro",
        project_id: "my-gcp-project"
      )
  """
  @spec google(keyword()) :: config()
  def google(opts \\ []) do
    build_config("generative-palm", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:project_id, :projectId}
    ])
  end

  @doc """
  Create AWS (Bedrock/SageMaker) generative configuration.

  ## Options

  - `:model` - Model ID (e.g., "anthropic.claude-v2")
  - `:region` - AWS region
  - `:service` - AWS service ("bedrock" or "sagemaker")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate

  ## Examples

      GenerativeConfig.aws(
        model: "anthropic.claude-v2",
        region: "us-east-1"
      )

      GenerativeConfig.aws(
        model: "anthropic.claude-v2",
        region: "us-west-2",
        service: "bedrock"
      )
  """
  @spec aws(keyword()) :: config()
  def aws(opts \\ []) do
    build_config("generative-aws", opts, [
      {:model, :model},
      {:region, :region},
      {:service, :service},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens}
    ])
  end

  @doc """
  Create Ollama generative configuration.

  ## Options

  - `:model` - Model name (e.g., "llama3", "mistral")
  - `:api_endpoint` - Ollama API endpoint URL
  - `:temperature` - Sampling temperature

  ## Examples

      GenerativeConfig.ollama(model: "llama3")

      GenerativeConfig.ollama(
        model: "llama3:70b",
        api_endpoint: "http://localhost:11434"
      )
  """
  @spec ollama(keyword()) :: config()
  def ollama(opts \\ []) do
    build_config("generative-ollama", opts, [
      {:model, :model},
      {:api_endpoint, :apiEndpoint},
      {:temperature, :temperature}
    ])
  end

  @doc """
  Create Databricks generative configuration.

  ## Options

  - `:endpoint` - Databricks serving endpoint URL (required)
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:top_k` - Top-k sampling parameter
  - `:top_p` - Top-p (nucleus) sampling parameter

  ## Examples

      GenerativeConfig.databricks(
        endpoint: "https://my-workspace.cloud.databricks.com"
      )
  """
  @spec databricks(keyword()) :: config()
  def databricks(opts \\ []) do
    build_config("generative-databricks", opts, [
      {:endpoint, :endpoint},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:top_k, :topK},
      {:top_p, :topP}
    ])
  end

  @doc """
  Create NVIDIA NIM generative configuration.

  ## Options

  - `:model` - Model name (e.g., "meta/llama-3.1-405b-instruct")
  - `:base_url` - Custom API endpoint URL
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate

  ## Examples

      GenerativeConfig.nvidia(model: "meta/llama-3.1-405b-instruct")
  """
  @spec nvidia(keyword()) :: config()
  def nvidia(opts \\ []) do
    build_config("generative-nvidia", opts, [
      {:model, :model},
      {:base_url, :baseURL},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens}
    ])
  end

  @doc """
  Create FriendliAI generative configuration.

  ## Options

  - `:model` - Model name
  - `:base_url` - Custom API endpoint URL
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate

  ## Examples

      GenerativeConfig.friendliai(model: "mixtral-8x7b")
  """
  @spec friendliai(keyword()) :: config()
  def friendliai(opts \\ []) do
    build_config("generative-friendliai", opts, [
      {:model, :model},
      {:base_url, :baseURL},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens}
    ])
  end

  @doc """
  Create XAI (Grok) generative configuration.

  ## Options

  - `:model` - Model name (e.g., "grok-2")
  - `:temperature` - Sampling temperature
  - `:max_tokens` - Maximum tokens to generate
  - `:base_url` - Custom API endpoint URL

  ## Examples

      GenerativeConfig.xai(model: "grok-2")
  """
  @spec xai(keyword()) :: config()
  def xai(opts \\ []) do
    build_config("generative-xai", opts, [
      {:model, :model},
      {:temperature, :temperature},
      {:max_tokens, :maxTokens},
      {:base_url, :baseURL}
    ])
  end

  @doc """
  Create Anyscale generative configuration.

  ## Options

  - `:model` - Model name (e.g., "meta-llama/Llama-3-70b-chat-hf")
  - `:base_url` - Custom API endpoint URL
  - `:temperature` - Sampling temperature

  ## Examples

      GenerativeConfig.anyscale(model: "meta-llama/Llama-3-70b-chat-hf")
  """
  @spec anyscale(keyword()) :: config()
  def anyscale(opts \\ []) do
    build_config("generative-anyscale", opts, [
      {:model, :model},
      {:base_url, :baseURL},
      {:temperature, :temperature}
    ])
  end

  @doc """
  Create ContextualAI generative configuration.

  ## Options

  - `:model` - Model name (optional)

  ## Examples

      GenerativeConfig.contextualai()

      GenerativeConfig.contextualai(model: "grounded-generation")
  """
  @spec contextualai(keyword()) :: config()
  def contextualai(opts \\ []) do
    build_config("generative-contextualai", opts, [
      {:model, :model}
    ])
  end

  # Build configuration map from options and field mappings
  defp build_config(module_name, opts, field_mappings) do
    config =
      field_mappings
      |> Enum.reduce(%{}, fn {opt_key, api_key}, acc ->
        case Keyword.get(opts, opt_key) do
          nil -> acc
          value -> Map.put(acc, api_key, value)
        end
      end)

    %{module_name => config}
  end
end
