defmodule WeaviateEx.GRPC.Generative do
  @moduledoc """
  Builds gRPC GenerativeSearch messages from WeaviateEx generative config.

  This module converts the user-friendly generative config into the protobuf
  format expected by Weaviate's gRPC API.

  ## Examples

      # Simple single prompt
      config = %{single_prompt: "Summarize this article"}
      generative = Generative.build(config)

      # With provider configuration
      config = %{
        single_prompt: "Summarize",
        provider: :openai,
        model: "gpt-4",
        temperature: 0.7
      }
      generative = Generative.build_with_provider(config)
  """

  alias Weaviate.V1.GenerativeAnthropic
  alias Weaviate.V1.GenerativeAnyscale
  alias Weaviate.V1.GenerativeAWS
  alias Weaviate.V1.GenerativeCohere
  alias Weaviate.V1.GenerativeContextualAI
  alias Weaviate.V1.GenerativeDatabricks
  alias Weaviate.V1.GenerativeFriendliAI
  alias Weaviate.V1.GenerativeGoogle
  alias Weaviate.V1.GenerativeMistral
  alias Weaviate.V1.GenerativeNvidia
  alias Weaviate.V1.GenerativeOllama
  alias Weaviate.V1.GenerativeOpenAI
  alias Weaviate.V1.GenerativeProvider
  alias Weaviate.V1.GenerativeResult
  alias Weaviate.V1.GenerativeSearch
  alias Weaviate.V1.GenerativeXAI
  alias Weaviate.V1.TextArray

  @type config :: %{
          optional(:single_prompt) => String.t(),
          optional(:grouped_task) => String.t(),
          optional(:grouped_properties) => [String.t()],
          optional(:provider) => atom(),
          optional(:model) => String.t(),
          optional(:temperature) => float(),
          optional(:max_tokens) => integer(),
          optional(:top_p) => float(),
          optional(:top_k) => integer(),
          optional(:debug) => boolean()
        }

  @type generative_result :: %{
          optional(:grouped_result) => String.t() | nil,
          optional(:single_results) => [String.t()]
        }

  @doc """
  Builds a gRPC GenerativeSearch message from a simple config map.

  Returns `nil` for nil input. This is the basic version that uses
  deprecated fields for backward compatibility.
  """
  @spec build(config() | nil) :: struct() | nil
  def build(nil), do: nil

  def build(%{single_response_prompt: prompt} = config)
      when is_binary(prompt) and prompt != "" do
    # Handle deprecated field format
    %GenerativeSearch{
      single_response_prompt: prompt,
      grouped_response_task: config[:grouped_response_task] || "",
      grouped_properties: config[:grouped_properties] || []
    }
  end

  def build(%{single_prompt: prompt} = config) when is_binary(prompt) and prompt != "" do
    single = %GenerativeSearch.Single{
      prompt: prompt,
      debug: config[:debug] || false,
      queries: []
    }

    grouped = build_grouped(config)

    %GenerativeSearch{
      single: single,
      grouped: grouped
    }
  end

  def build(%{grouped_task: task} = config) when is_binary(task) and task != "" do
    %GenerativeSearch{
      single: nil,
      grouped: build_grouped(config)
    }
  end

  def build(_config), do: nil

  @doc """
  Builds a gRPC GenerativeSearch message with provider configuration.

  This version uses the new Single/Grouped message structure with
  provider-specific queries.
  """
  @spec build_with_provider(config() | nil) :: struct() | nil
  def build_with_provider(nil), do: nil

  def build_with_provider(%{single_prompt: prompt, provider: provider} = config)
      when is_binary(prompt) and prompt != "" do
    provider_query = build_provider(provider, config)

    single = %GenerativeSearch.Single{
      prompt: prompt,
      debug: config[:debug] || false,
      queries: if(provider_query, do: [provider_query], else: [])
    }

    grouped = build_grouped_with_provider(config)

    %GenerativeSearch{
      single: single,
      grouped: grouped
    }
  end

  def build_with_provider(%{grouped_task: _task, provider: provider} = config) do
    provider_query = build_provider(provider, config)

    grouped = %GenerativeSearch.Grouped{
      task: config[:grouped_task],
      properties: build_text_array(config[:grouped_properties]),
      debug: config[:debug] || false,
      queries: if(provider_query, do: [provider_query], else: [])
    }

    %GenerativeSearch{
      single: nil,
      grouped: grouped
    }
  end

  def build_with_provider(config), do: build(config)

  @doc """
  Parses a generative result from a gRPC search reply.
  """
  @spec parse_generative_result(map()) :: generative_result()
  def parse_generative_result(%{generative_grouped_results: grouped_result} = _reply)
      when not is_nil(grouped_result) do
    grouped_text = extract_first_result(grouped_result)
    %{grouped_result: grouped_text, single_results: []}
  end

  def parse_generative_result(_reply) do
    %{grouped_result: nil, single_results: []}
  end

  @doc """
  Extracts single generative results from a list of search results.
  """
  @spec extract_single_results([map()]) :: [String.t()]
  def extract_single_results(results) when is_list(results) do
    results
    |> Enum.map(&extract_generative_from_result/1)
    |> Enum.reject(&is_nil/1)
  end

  # Private helpers

  defp build_grouped(%{grouped_task: task} = config) when is_binary(task) and task != "" do
    %GenerativeSearch.Grouped{
      task: task,
      properties: build_text_array(config[:grouped_properties]),
      debug: config[:debug] || false,
      queries: []
    }
  end

  defp build_grouped(_config), do: nil

  defp build_grouped_with_provider(%{grouped_task: task, provider: provider} = config)
       when is_binary(task) and task != "" do
    provider_query = build_provider(provider, config)

    %GenerativeSearch.Grouped{
      task: task,
      properties: build_text_array(config[:grouped_properties]),
      debug: config[:debug] || false,
      queries: if(provider_query, do: [provider_query], else: [])
    }
  end

  defp build_grouped_with_provider(_config), do: nil

  defp build_text_array(nil), do: nil
  defp build_text_array([]), do: nil
  defp build_text_array(props) when is_list(props), do: %TextArray{values: props}

  defp build_provider(:openai, config) do
    openai_config = %GenerativeOpenAI{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      frequency_penalty: config[:frequency_penalty],
      presence_penalty: config[:presence_penalty],
      stop: build_text_array(config[:stop]),
      base_url: config[:base_url],
      api_version: config[:api_version],
      resource_name: config[:resource_name],
      deployment_id: config[:deployment_id],
      is_azure: config[:is_azure],
      verbosity: map_verbosity(config[:verbosity]),
      reasoning_effort: map_reasoning_effort(config[:reasoning_effort])
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:openai, openai_config}
    }
  end

  defp build_provider(:azure_openai, config) do
    build_provider(:openai, Map.put(config, :is_azure, true))
  end

  defp build_provider(:anthropic, config) do
    anthropic_config = %GenerativeAnthropic{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      top_k: config[:top_k],
      stop_sequences: build_text_array(config[:stop_sequences]),
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:anthropic, anthropic_config}
    }
  end

  defp build_provider(:cohere, config) do
    cohere_config = %GenerativeCohere{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      k: config[:k],
      p: config[:p],
      frequency_penalty: config[:frequency_penalty],
      presence_penalty: config[:presence_penalty],
      stop_sequences: build_text_array(config[:stop_sequences]),
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:cohere, cohere_config}
    }
  end

  defp build_provider(:mistral, config) do
    mistral_config = %GenerativeMistral{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:mistral, mistral_config}
    }
  end

  defp build_provider(:ollama, config) do
    ollama_config = %GenerativeOllama{
      model: config[:model],
      temperature: config[:temperature],
      api_endpoint: config[:api_endpoint]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:ollama, ollama_config}
    }
  end

  defp build_provider(:google, config) do
    google_config = %GenerativeGoogle{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      top_k: config[:top_k],
      frequency_penalty: config[:frequency_penalty],
      presence_penalty: config[:presence_penalty],
      stop_sequences: build_text_array(config[:stop_sequences]),
      api_endpoint: config[:api_endpoint],
      project_id: config[:project_id],
      endpoint_id: config[:endpoint_id],
      region: config[:region]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:google, google_config}
    }
  end

  defp build_provider(:aws, config) do
    aws_config = %GenerativeAWS{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      service: config[:service],
      region: config[:region],
      endpoint: config[:endpoint],
      target_model: config[:target_model],
      target_variant: config[:target_variant],
      stop_sequences: build_text_array(config[:stop_sequences])
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:aws, aws_config}
    }
  end

  defp build_provider(:aws_bedrock, config) do
    build_provider(:aws, Map.put(config, :service, "bedrock"))
  end

  defp build_provider(:aws_sagemaker, config) do
    build_provider(:aws, Map.put(config, :service, "sagemaker"))
  end

  defp build_provider(:databricks, config) do
    databricks_config = %GenerativeDatabricks{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      endpoint: config[:endpoint],
      frequency_penalty: config[:frequency_penalty],
      presence_penalty: config[:presence_penalty],
      log_probs: config[:log_probs],
      top_log_probs: config[:top_log_probs],
      n: config[:n],
      stop: build_text_array(config[:stop])
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:databricks, databricks_config}
    }
  end

  defp build_provider(:friendliai, config) do
    friendliai_config = %GenerativeFriendliAI{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      base_url: config[:base_url],
      n: config[:n]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:friendliai, friendliai_config}
    }
  end

  defp build_provider(:nvidia, config) do
    nvidia_config = %GenerativeNvidia{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:nvidia, nvidia_config}
    }
  end

  defp build_provider(:xai, config) do
    xai_config = %GenerativeXAI{
      model: config[:model],
      temperature: config[:temperature],
      max_tokens: config[:max_tokens],
      top_p: config[:top_p],
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:xai, xai_config}
    }
  end

  defp build_provider(:contextualai, config) do
    contextualai_config = %GenerativeContextualAI{
      model: config[:model],
      temperature: config[:temperature],
      top_p: config[:top_p],
      max_new_tokens: config[:max_new_tokens],
      system_prompt: config[:system_prompt],
      avoid_commentary: config[:avoid_commentary],
      knowledge: build_text_array(config[:knowledge])
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:contextualai, contextualai_config}
    }
  end

  defp build_provider(:anyscale, config) do
    anyscale_config = %GenerativeAnyscale{
      model: config[:model],
      temperature: config[:temperature],
      base_url: config[:base_url]
    }

    %GenerativeProvider{
      return_metadata: config[:return_metadata] || false,
      kind: {:anyscale, anyscale_config}
    }
  end

  defp build_provider(_unknown, _config), do: nil

  defp map_verbosity(nil), do: nil
  defp map_verbosity(:low), do: :VERBOSITY_LOW
  defp map_verbosity(:medium), do: :VERBOSITY_MEDIUM
  defp map_verbosity(:high), do: :VERBOSITY_HIGH
  defp map_verbosity("low"), do: :VERBOSITY_LOW
  defp map_verbosity("medium"), do: :VERBOSITY_MEDIUM
  defp map_verbosity("high"), do: :VERBOSITY_HIGH
  defp map_verbosity(_), do: :VERBOSITY_UNSPECIFIED

  defp map_reasoning_effort(nil), do: nil
  defp map_reasoning_effort(:minimal), do: :REASONING_EFFORT_MINIMAL
  defp map_reasoning_effort(:low), do: :REASONING_EFFORT_LOW
  defp map_reasoning_effort(:medium), do: :REASONING_EFFORT_MEDIUM
  defp map_reasoning_effort(:high), do: :REASONING_EFFORT_HIGH
  defp map_reasoning_effort("minimal"), do: :REASONING_EFFORT_MINIMAL
  defp map_reasoning_effort("low"), do: :REASONING_EFFORT_LOW
  defp map_reasoning_effort("medium"), do: :REASONING_EFFORT_MEDIUM
  defp map_reasoning_effort("high"), do: :REASONING_EFFORT_HIGH
  defp map_reasoning_effort(_), do: :REASONING_EFFORT_UNSPECIFIED

  defp extract_first_result(%GenerativeResult{values: [first | _]}) do
    first.result
  end

  defp extract_first_result(_), do: nil

  defp extract_generative_from_result(%{generative: %GenerativeResult{values: [first | _]}}) do
    first.result
  end

  defp extract_generative_from_result(_), do: nil
end
