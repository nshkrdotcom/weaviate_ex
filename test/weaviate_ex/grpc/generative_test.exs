defmodule WeaviateEx.GRPC.GenerativeTest do
  @moduledoc """
  Tests for gRPC Generative message builder.
  """

  use ExUnit.Case, async: true

  alias Weaviate.V1.{GenerativeProvider, GenerativeSearch}
  alias Weaviate.V1.GenerativeSearch.Single, as: GenerativeSingle
  alias WeaviateEx.GRPC.Generative

  @moduletag :grpc

  describe "build/1" do
    test "returns nil for nil input" do
      assert Generative.build(nil) == nil
    end

    test "builds single prompt generative config" do
      config = %{single_prompt: "Summarize this article"}

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert %GenerativeSingle{} = result.single
      assert result.single.prompt == "Summarize this article"
      assert result.grouped == nil
    end

    test "builds grouped task generative config" do
      config = %{grouped_task: "Write a summary of all articles"}

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert result.grouped != nil
      assert result.grouped.task == "Write a summary of all articles"
      assert result.single == nil
    end

    test "builds grouped task with properties" do
      config = %{
        grouped_task: "Synthesize the key themes",
        grouped_properties: ["title", "content"]
      }

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert result.grouped != nil
      assert result.grouped.task == "Synthesize the key themes"
      assert result.grouped.properties.values == ["title", "content"]
    end

    test "builds combined single + grouped config" do
      config = %{
        single_prompt: "Summarize: {title}",
        grouped_task: "Overall summary",
        grouped_properties: ["title"]
      }

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      assert result.single.prompt == "Summarize: {title}"
      assert result.grouped.task == "Overall summary"
      assert result.grouped.properties.values == ["title"]
    end

    test "uses deprecated fields when new fields not provided" do
      # For backward compatibility, also support the deprecated field format
      config = %{
        single_response_prompt: "Old style prompt",
        grouped_response_task: "Old style task",
        grouped_properties: ["prop1"]
      }

      result = Generative.build(config)

      assert %GenerativeSearch{} = result
      # Should still work via deprecated fields or be converted
      assert result.single_response_prompt == "Old style prompt" or
               result.single.prompt == "Old style prompt"
    end
  end

  describe "build_with_provider/2" do
    test "builds OpenAI provider config" do
      config = %{
        single_prompt: "Summarize",
        provider: :openai,
        model: "gpt-4",
        temperature: 0.7,
        max_tokens: 500
      }

      result = Generative.build_with_provider(config)

      assert %GenerativeSearch{} = result
      assert result.single.prompt == "Summarize"
      assert length(result.single.queries) == 1

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:openai, openai_config}} = provider
      assert openai_config.model == "gpt-4"
      assert openai_config.temperature == 0.7
      assert openai_config.max_tokens == 500
    end

    test "builds Anthropic provider config" do
      config = %{
        single_prompt: "Explain",
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1000,
        top_k: 40
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:anthropic, anthropic_config}} = provider
      assert anthropic_config.model == "claude-3-5-sonnet-20241022"
      assert anthropic_config.max_tokens == 1000
      assert anthropic_config.top_k == 40
    end

    test "builds Cohere provider config" do
      config = %{
        single_prompt: "Summarize",
        provider: :cohere,
        model: "command-r-plus",
        temperature: 0.5
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:cohere, cohere_config}} = provider
      assert cohere_config.model == "command-r-plus"
      assert cohere_config.temperature == 0.5
    end

    test "builds Mistral provider config" do
      config = %{
        single_prompt: "Translate",
        provider: :mistral,
        model: "mistral-large",
        top_p: 0.9
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:mistral, mistral_config}} = provider
      assert mistral_config.model == "mistral-large"
      assert mistral_config.top_p == 0.9
    end

    test "builds Ollama provider config" do
      config = %{
        single_prompt: "Generate",
        provider: :ollama,
        model: "llama2",
        api_endpoint: "http://localhost:11434"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:ollama, ollama_config}} = provider
      assert ollama_config.model == "llama2"
      assert ollama_config.api_endpoint == "http://localhost:11434"
    end

    test "builds Google provider config" do
      config = %{
        single_prompt: "Analyze",
        provider: :google,
        model: "gemini-pro",
        project_id: "my-project",
        region: "us-central1"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:google, google_config}} = provider
      assert google_config.model == "gemini-pro"
      assert google_config.project_id == "my-project"
      assert google_config.region == "us-central1"
    end

    test "builds AWS provider config" do
      config = %{
        single_prompt: "Process",
        provider: :aws,
        model: "anthropic.claude-v2",
        region: "us-east-1",
        service: "bedrock"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:aws, aws_config}} = provider
      assert aws_config.model == "anthropic.claude-v2"
      assert aws_config.region == "us-east-1"
      assert aws_config.service == "bedrock"
    end

    test "builds Databricks provider config with all options" do
      config = %{
        single_prompt: "Generate",
        provider: :databricks,
        model: "dbrx",
        endpoint: "https://my-databricks.cloud/serving-endpoints",
        frequency_penalty: 0.2,
        presence_penalty: 0.1,
        log_probs: true,
        top_log_probs: 5,
        n: 2
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:databricks, databricks_config}} = provider
      assert databricks_config.model == "dbrx"
      assert databricks_config.endpoint == "https://my-databricks.cloud/serving-endpoints"
      assert databricks_config.frequency_penalty == 0.2
      assert databricks_config.presence_penalty == 0.1
      assert databricks_config.log_probs == true
      assert databricks_config.top_log_probs == 5
      assert databricks_config.n == 2
    end

    test "builds FriendliAI provider config" do
      config = %{
        single_prompt: "Create",
        provider: :friendliai,
        model: "llama-3",
        n: 3,
        base_url: "https://api.friendli.ai"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:friendliai, friendliai_config}} = provider
      assert friendliai_config.model == "llama-3"
      assert friendliai_config.n == 3
      assert friendliai_config.base_url == "https://api.friendli.ai"
    end

    test "builds NVIDIA provider config" do
      config = %{
        single_prompt: "Infer",
        provider: :nvidia,
        model: "mixtral-8x7b",
        base_url: "https://api.nvidia.com"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:nvidia, nvidia_config}} = provider
      assert nvidia_config.model == "mixtral-8x7b"
      assert nvidia_config.base_url == "https://api.nvidia.com"
    end

    test "builds XAI provider config" do
      config = %{
        single_prompt: "Explain",
        provider: :xai,
        model: "grok-2",
        top_p: 0.95
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:xai, xai_config}} = provider
      assert xai_config.model == "grok-2"
      assert xai_config.top_p == 0.95
    end

    test "builds ContextualAI provider config" do
      config = %{
        single_prompt: "Contextualize",
        provider: :contextualai,
        model: "rag-model",
        system_prompt: "You are a helpful assistant",
        avoid_commentary: true,
        max_new_tokens: 1024
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:contextualai, contextualai_config}} = provider
      assert contextualai_config.model == "rag-model"
      assert contextualai_config.system_prompt == "You are a helpful assistant"
      assert contextualai_config.avoid_commentary == true
      assert contextualai_config.max_new_tokens == 1024
    end

    test "builds Anyscale provider config" do
      config = %{
        single_prompt: "Scale",
        provider: :anyscale,
        model: "meta-llama/Llama-2-70b",
        base_url: "https://api.anyscale.com"
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:anyscale, anyscale_config}} = provider
      assert anyscale_config.model == "meta-llama/Llama-2-70b"
      assert anyscale_config.base_url == "https://api.anyscale.com"
    end

    test "builds grouped task with provider" do
      config = %{
        grouped_task: "Summarize all articles",
        grouped_properties: ["title", "content"],
        provider: :openai,
        model: "gpt-4",
        temperature: 0.5
      }

      result = Generative.build_with_provider(config)

      assert result.grouped.task == "Summarize all articles"
      assert result.grouped.properties.values == ["title", "content"]
      assert length(result.grouped.queries) == 1

      [provider] = result.grouped.queries
      assert %GenerativeProvider{kind: {:openai, openai_config}} = provider
      assert openai_config.model == "gpt-4"
      assert openai_config.temperature == 0.5
    end

    test "builds with debug enabled" do
      config = %{
        single_prompt: "Debug me",
        provider: :openai,
        debug: true
      }

      result = Generative.build_with_provider(config)

      assert result.single.debug == true
    end

    test "builds OpenAI with reasoning model parameters" do
      config = %{
        single_prompt: "Reason about this",
        provider: :openai,
        model: "o3",
        verbosity: :medium,
        reasoning_effort: :high
      }

      result = Generative.build_with_provider(config)

      [provider] = result.single.queries
      assert %GenerativeProvider{kind: {:openai, openai_config}} = provider
      assert openai_config.model == "o3"
      assert openai_config.verbosity == :VERBOSITY_MEDIUM
      assert openai_config.reasoning_effort == :REASONING_EFFORT_HIGH
    end
  end

  describe "parse_generative_result/1" do
    test "parses grouped generative result from search reply" do
      reply = %{
        generative_grouped_results: %Weaviate.V1.GenerativeResult{
          values: [
            %Weaviate.V1.GenerativeReply{
              result: "This is the grouped summary"
            }
          ]
        }
      }

      result = Generative.parse_generative_result(reply)

      assert result.grouped_result == "This is the grouped summary"
    end

    test "parses single generative results from search results" do
      results = [
        %{
          generative: %Weaviate.V1.GenerativeResult{
            values: [
              %Weaviate.V1.GenerativeReply{result: "Summary for object 1"}
            ]
          }
        },
        %{
          generative: %Weaviate.V1.GenerativeResult{
            values: [
              %Weaviate.V1.GenerativeReply{result: "Summary for object 2"}
            ]
          }
        }
      ]

      single_results = Generative.extract_single_results(results)

      assert length(single_results) == 2
      assert Enum.at(single_results, 0) == "Summary for object 1"
      assert Enum.at(single_results, 1) == "Summary for object 2"
    end

    test "handles nil generative results" do
      results = [
        %{generative: nil},
        %{generative: nil}
      ]

      single_results = Generative.extract_single_results(results)

      assert single_results == []
    end

    test "handles empty generative values" do
      results = [
        %{
          generative: %Weaviate.V1.GenerativeResult{values: []}
        }
      ]

      single_results = Generative.extract_single_results(results)

      assert single_results == []
    end
  end
end
