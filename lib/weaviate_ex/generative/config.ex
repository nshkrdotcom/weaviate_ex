defmodule WeaviateEx.Generative.Config do
  @moduledoc """
  Typed configuration structs for each generative AI provider.

  Each provider has its own struct with provider-specific parameters.
  Use the factory functions to create configurations:

  ## Examples

      # OpenAI with all options
      config = Config.openai(
        model: "gpt-4",
        temperature: 0.7,
        max_tokens: 500,
        frequency_penalty: 0.5
      )

      # Azure OpenAI
      config = Config.azure_openai(
        model: "gpt-4",
        deployment_id: "my-deployment",
        resource_name: "my-resource"
      )

      # Anthropic Claude
      config = Config.anthropic(
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1000,
        top_k: 40
      )

      # Use with generative query
      Generative.single_prompt(client, "Article", "Summarize {title}",
        provider_config: config
      )
  """

  # OpenAI Configuration
  defmodule OpenAI do
    @moduledoc "OpenAI/Azure OpenAI generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :frequency_penalty,
      :presence_penalty,
      :stop,
      :base_url,
      :api_version,
      :deployment_id,
      :resource_name,
      :verbosity,
      :reasoning_effort,
      is_azure: false
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            frequency_penalty: float() | nil,
            presence_penalty: float() | nil,
            stop: [String.t()] | nil,
            base_url: String.t() | nil,
            api_version: String.t() | nil,
            deployment_id: String.t() | nil,
            resource_name: String.t() | nil,
            is_azure: boolean(),
            verbosity: :low | :medium | :high | nil,
            reasoning_effort: :minimal | :low | :medium | :high | nil
          }
  end

  # Anthropic Configuration
  defmodule Anthropic do
    @moduledoc "Anthropic Claude generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :top_k,
      :stop_sequences,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            stop_sequences: [String.t()] | nil,
            base_url: String.t() | nil
          }
  end

  # Cohere Configuration
  defmodule Cohere do
    @moduledoc "Cohere generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :k,
      :p,
      :presence_penalty,
      :stop_sequences,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            k: integer() | nil,
            p: float() | nil,
            presence_penalty: float() | nil,
            stop_sequences: [String.t()] | nil,
            base_url: String.t() | nil
          }
  end

  # AWS (Bedrock/SageMaker) Configuration
  defmodule AWS do
    @moduledoc "AWS Bedrock/SageMaker generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :top_k,
      :region,
      :endpoint,
      :service,
      :target_model,
      :target_variant,
      :stop_sequences
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            region: String.t() | nil,
            endpoint: String.t() | nil,
            service: String.t() | nil,
            target_model: String.t() | nil,
            target_variant: String.t() | nil,
            stop_sequences: [String.t()] | nil
          }
  end

  # Google (Vertex AI/Gemini) Configuration
  defmodule Google do
    @moduledoc "Google Vertex AI/Gemini generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :top_k,
      :api_endpoint,
      :endpoint_id,
      :frequency_penalty,
      :presence_penalty,
      :project_id,
      :region,
      :stop_sequences
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            api_endpoint: String.t() | nil,
            endpoint_id: String.t() | nil,
            frequency_penalty: float() | nil,
            presence_penalty: float() | nil,
            project_id: String.t() | nil,
            region: String.t() | nil,
            stop_sequences: [String.t()] | nil
          }
  end

  # Mistral Configuration
  defmodule Mistral do
    @moduledoc "Mistral generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            base_url: String.t() | nil
          }
  end

  # Ollama Configuration
  defmodule Ollama do
    @moduledoc "Ollama (local) generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :api_endpoint
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            api_endpoint: String.t() | nil
          }
  end

  # XAI (Grok) Configuration
  defmodule XAI do
    @moduledoc "XAI (Grok) generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            base_url: String.t() | nil
          }
  end

  # ContextualAI Configuration
  defmodule ContextualAI do
    @moduledoc "ContextualAI generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :system_prompt,
      :avoid_commentary,
      :max_new_tokens,
      :knowledge
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            system_prompt: String.t() | nil,
            avoid_commentary: boolean() | nil,
            max_new_tokens: integer() | nil,
            knowledge: [String.t()] | nil
          }
  end

  # NVIDIA Configuration (new provider)
  defmodule Nvidia do
    @moduledoc "NVIDIA NIM generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            base_url: String.t() | nil
          }
  end

  # Databricks Configuration (new provider)
  defmodule Databricks do
    @moduledoc "Databricks generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :endpoint
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            endpoint: String.t() | nil
          }
  end

  # FriendliAI Configuration (new provider)
  defmodule FriendliAI do
    @moduledoc "FriendliAI generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            base_url: String.t() | nil
          }
  end

  # Anyscale Configuration
  defmodule Anyscale do
    @moduledoc "Anyscale generative configuration"

    defstruct [
      :model,
      :temperature,
      :max_tokens,
      :top_p,
      :base_url
    ]

    @type t :: %__MODULE__{
            model: String.t() | nil,
            temperature: float() | nil,
            max_tokens: integer() | nil,
            top_p: float() | nil,
            base_url: String.t() | nil
          }
  end

  # Type for any provider config
  @type config ::
          OpenAI.t()
          | Anthropic.t()
          | Cohere.t()
          | AWS.t()
          | Google.t()
          | Mistral.t()
          | Ollama.t()
          | XAI.t()
          | ContextualAI.t()
          | Nvidia.t()
          | Databricks.t()
          | FriendliAI.t()
          | Anyscale.t()

  # Factory functions

  @doc "Create OpenAI configuration"
  @spec openai(keyword()) :: OpenAI.t()
  def openai(opts \\ []), do: struct(OpenAI, opts)

  @doc "Create Azure OpenAI configuration"
  @spec azure_openai(keyword()) :: OpenAI.t()
  def azure_openai(opts \\ []) do
    opts
    |> Keyword.put(:is_azure, true)
    |> then(&struct(OpenAI, &1))
  end

  @doc "Create Anthropic configuration"
  @spec anthropic(keyword()) :: Anthropic.t()
  def anthropic(opts \\ []), do: struct(Anthropic, opts)

  @doc "Create Cohere configuration"
  @spec cohere(keyword()) :: Cohere.t()
  def cohere(opts \\ []), do: struct(Cohere, opts)

  @doc "Create AWS Bedrock configuration"
  @spec aws_bedrock(keyword()) :: AWS.t()
  def aws_bedrock(opts \\ []) do
    opts
    |> Keyword.put_new(:service, "bedrock")
    |> then(&struct(AWS, &1))
  end

  @doc "Create AWS SageMaker configuration"
  @spec aws_sagemaker(keyword()) :: AWS.t()
  def aws_sagemaker(opts \\ []) do
    opts
    |> Keyword.put_new(:service, "sagemaker")
    |> then(&struct(AWS, &1))
  end

  @doc "Create Google Vertex AI configuration"
  @spec google_vertex(keyword()) :: Google.t()
  def google_vertex(opts \\ []), do: struct(Google, opts)

  @doc "Create Google Gemini configuration"
  @spec google_gemini(keyword()) :: Google.t()
  def google_gemini(opts \\ []), do: struct(Google, opts)

  @doc "Create Mistral configuration"
  @spec mistral(keyword()) :: Mistral.t()
  def mistral(opts \\ []), do: struct(Mistral, opts)

  @doc "Create Ollama configuration"
  @spec ollama(keyword()) :: Ollama.t()
  def ollama(opts \\ []), do: struct(Ollama, opts)

  @doc "Create XAI (Grok) configuration"
  @spec xai(keyword()) :: XAI.t()
  def xai(opts \\ []), do: struct(XAI, opts)

  @doc "Create ContextualAI configuration"
  @spec contextualai(keyword()) :: ContextualAI.t()
  def contextualai(opts \\ []), do: struct(ContextualAI, opts)

  @doc "Create NVIDIA configuration"
  @spec nvidia(keyword()) :: Nvidia.t()
  def nvidia(opts \\ []), do: struct(Nvidia, opts)

  @doc "Create Databricks configuration"
  @spec databricks(keyword()) :: Databricks.t()
  def databricks(opts \\ []), do: struct(Databricks, opts)

  @doc "Create FriendliAI configuration"
  @spec friendliai(keyword()) :: FriendliAI.t()
  def friendliai(opts \\ []), do: struct(FriendliAI, opts)

  @doc "Create Anyscale configuration"
  @spec anyscale(keyword()) :: Anyscale.t()
  def anyscale(opts \\ []), do: struct(Anyscale, opts)

  @doc "Get provider name from config struct"
  @spec provider_name(config()) :: atom()
  def provider_name(%OpenAI{is_azure: true}), do: :azure_openai
  def provider_name(%OpenAI{}), do: :openai
  def provider_name(%Anthropic{}), do: :anthropic
  def provider_name(%Cohere{}), do: :cohere
  def provider_name(%AWS{service: "bedrock"}), do: :aws_bedrock
  def provider_name(%AWS{service: "sagemaker"}), do: :aws_sagemaker
  def provider_name(%AWS{}), do: :aws_bedrock
  def provider_name(%Google{}), do: :google
  def provider_name(%Mistral{}), do: :mistral
  def provider_name(%Ollama{}), do: :ollama
  def provider_name(%XAI{}), do: :xai
  def provider_name(%ContextualAI{}), do: :contextualai
  def provider_name(%Nvidia{}), do: :nvidia
  def provider_name(%Databricks{}), do: :databricks
  def provider_name(%FriendliAI{}), do: :friendliai
  def provider_name(%Anyscale{}), do: :anyscale

  @doc "Convert config to GraphQL parameters map"
  @spec to_graphql_params(config()) :: map()
  def to_graphql_params(%OpenAI{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:frequencyPenalty, config.frequency_penalty)
    |> maybe_add(:presencePenalty, config.presence_penalty)
    |> maybe_add(:stop, config.stop)
    |> maybe_add(:baseUrl, config.base_url)
    |> maybe_add(:apiVersion, config.api_version)
    |> maybe_add(:deploymentId, config.deployment_id)
    |> maybe_add(:resourceName, config.resource_name)
    |> maybe_add(:verbosity, config.verbosity)
    |> maybe_add(:reasoningEffort, config.reasoning_effort)
  end

  def to_graphql_params(%Anthropic{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:topK, config.top_k)
    |> maybe_add(:stopSequences, config.stop_sequences)
    |> maybe_add(:baseUrl, config.base_url)
  end

  def to_graphql_params(%Cohere{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:k, config.k)
    |> maybe_add(:p, config.p)
    |> maybe_add(:presencePenalty, config.presence_penalty)
    |> maybe_add(:stopSequences, config.stop_sequences)
    |> maybe_add(:baseUrl, config.base_url)
  end

  def to_graphql_params(%AWS{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:topK, config.top_k)
    |> maybe_add(:region, config.region)
    |> maybe_add(:endpoint, config.endpoint)
    |> maybe_add(:service, config.service)
    |> maybe_add(:targetModel, config.target_model)
    |> maybe_add(:targetVariant, config.target_variant)
    |> maybe_add(:stopSequences, config.stop_sequences)
  end

  def to_graphql_params(%Google{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:topK, config.top_k)
    |> maybe_add(:apiEndpoint, config.api_endpoint)
    |> maybe_add(:endpointId, config.endpoint_id)
    |> maybe_add(:frequencyPenalty, config.frequency_penalty)
    |> maybe_add(:presencePenalty, config.presence_penalty)
    |> maybe_add(:projectId, config.project_id)
    |> maybe_add(:region, config.region)
    |> maybe_add(:stopSequences, config.stop_sequences)
  end

  def to_graphql_params(%ContextualAI{} = config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:systemPrompt, config.system_prompt)
    |> maybe_add(:avoidCommentary, config.avoid_commentary)
    |> maybe_add(:maxNewTokens, config.max_new_tokens)
    |> maybe_add(:knowledge, config.knowledge)
  end

  def to_graphql_params(config) do
    config
    |> Map.from_struct()
    |> convert_common_params()
    |> maybe_add(:baseUrl, Map.get(config, :base_url))
    |> maybe_add(:apiEndpoint, Map.get(config, :api_endpoint))
    |> maybe_add(:endpoint, Map.get(config, :endpoint))
  end

  # Private helpers

  defp convert_common_params(map) do
    %{}
    |> maybe_add(:model, map[:model])
    |> maybe_add(:temperature, map[:temperature])
    |> maybe_add(:maxTokens, map[:max_tokens])
    |> maybe_add(:topP, map[:top_p])
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
