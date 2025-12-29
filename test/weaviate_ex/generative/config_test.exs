defmodule WeaviateEx.Generative.ConfigTest do
  @moduledoc """
  Tests for typed generative provider configurations.
  """

  use ExUnit.Case, async: true

  alias WeaviateEx.Generative.Config

  describe "OpenAI configuration" do
    test "creates with default values" do
      config = Config.openai()

      assert %Config.OpenAI{} = config
      assert config.model == nil
      assert config.temperature == nil
      assert config.is_azure == false
    end

    test "creates with all parameters" do
      config =
        Config.openai(
          model: "gpt-4",
          temperature: 0.7,
          max_tokens: 500,
          top_p: 0.9,
          frequency_penalty: 0.5,
          presence_penalty: 0.3,
          stop: ["\n\n"],
          base_url: "https://api.openai.com/v1",
          reasoning_effort: :high,
          verbosity: :medium
        )

      assert config.model == "gpt-4"
      assert config.temperature == 0.7
      assert config.max_tokens == 500
      assert config.top_p == 0.9
      assert config.frequency_penalty == 0.5
      assert config.presence_penalty == 0.3
      assert config.stop == ["\n\n"]
      assert config.base_url == "https://api.openai.com/v1"
      assert config.reasoning_effort == :high
      assert config.verbosity == :medium
    end

    test "converts to graphql params" do
      config =
        Config.openai(
          model: "gpt-4",
          temperature: 0.7,
          max_tokens: 500,
          frequency_penalty: 0.5
        )

      params = Config.to_graphql_params(config)

      assert params[:model] == "gpt-4"
      assert params[:temperature] == 0.7
      assert params[:maxTokens] == 500
      assert params[:frequencyPenalty] == 0.5
    end
  end

  describe "Azure OpenAI configuration" do
    test "creates azure config with is_azure flag" do
      config =
        Config.azure_openai(
          model: "gpt-4",
          deployment_id: "my-deployment",
          resource_name: "my-resource",
          api_version: "2023-05-15"
        )

      assert config.is_azure == true
      assert config.deployment_id == "my-deployment"
      assert config.resource_name == "my-resource"
      assert config.api_version == "2023-05-15"
    end
  end

  describe "Anthropic configuration" do
    test "creates with all parameters" do
      config =
        Config.anthropic(
          model: "claude-3-5-sonnet-20241022",
          temperature: 0.7,
          max_tokens: 1000,
          top_p: 0.9,
          top_k: 40,
          stop_sequences: ["\n\nHuman:"],
          base_url: "https://api.anthropic.com"
        )

      assert config.model == "claude-3-5-sonnet-20241022"
      assert config.top_k == 40
      assert config.stop_sequences == ["\n\nHuman:"]
    end

    test "converts to graphql params" do
      config =
        Config.anthropic(
          model: "claude-3-5-sonnet-20241022",
          top_k: 40,
          stop_sequences: ["\n\n"]
        )

      params = Config.to_graphql_params(config)

      assert params[:model] == "claude-3-5-sonnet-20241022"
      assert params[:topK] == 40
      assert params[:stopSequences] == ["\n\n"]
    end
  end

  describe "Cohere configuration" do
    test "creates with cohere-specific parameters" do
      config =
        Config.cohere(
          model: "command-r-plus",
          k: 5,
          p: 0.8,
          presence_penalty: 0.5,
          stop_sequences: ["END"]
        )

      assert config.model == "command-r-plus"
      assert config.k == 5
      assert config.p == 0.8
      assert config.presence_penalty == 0.5
    end
  end

  describe "AWS configuration" do
    test "creates bedrock config" do
      config =
        Config.aws_bedrock(
          model: "anthropic.claude-v2",
          region: "us-east-1",
          service: "bedrock",
          target_model: "anthropic.claude-v2",
          top_k: 40,
          stop_sequences: ["\\n\\nHuman:"]
        )

      assert config.model == "anthropic.claude-v2"
      assert config.region == "us-east-1"
      assert config.service == "bedrock"
      assert config.target_model == "anthropic.claude-v2"
    end

    test "creates sagemaker config" do
      config =
        Config.aws_sagemaker(
          model: "my-endpoint",
          region: "us-west-2",
          service: "sagemaker",
          endpoint: "my-endpoint-url"
        )

      assert config.model == "my-endpoint"
      assert config.service == "sagemaker"
      assert config.endpoint == "my-endpoint-url"
    end
  end

  describe "Google configuration" do
    test "creates vertex AI config" do
      config =
        Config.google_vertex(
          model: "gemini-pro",
          project_id: "my-project",
          region: "us-central1",
          api_endpoint: "us-central1-aiplatform.googleapis.com",
          top_k: 40,
          frequency_penalty: 0.5,
          presence_penalty: 0.3
        )

      assert config.model == "gemini-pro"
      assert config.project_id == "my-project"
      assert config.region == "us-central1"
      assert config.top_k == 40
    end

    test "creates gemini config" do
      config =
        Config.google_gemini(
          model: "gemini-1.5-pro",
          api_endpoint: "generativelanguage.googleapis.com"
        )

      assert config.model == "gemini-1.5-pro"
    end
  end

  describe "Mistral configuration" do
    test "creates with base_url" do
      config =
        Config.mistral(
          model: "mistral-large",
          base_url: "https://api.mistral.ai"
        )

      assert config.model == "mistral-large"
      assert config.base_url == "https://api.mistral.ai"
    end
  end

  describe "Ollama configuration" do
    test "creates with api_endpoint" do
      config =
        Config.ollama(
          model: "llama3",
          api_endpoint: "http://localhost:11434"
        )

      assert config.model == "llama3"
      assert config.api_endpoint == "http://localhost:11434"
    end
  end

  describe "XAI configuration" do
    test "creates with base_url" do
      config =
        Config.xai(
          model: "grok-2",
          base_url: "https://api.x.ai",
          temperature: 0.7,
          top_p: 0.9
        )

      assert config.model == "grok-2"
      assert config.base_url == "https://api.x.ai"
    end
  end

  describe "ContextualAI configuration" do
    test "creates with contextual-specific parameters" do
      config =
        Config.contextualai(
          system_prompt: "You are a helpful assistant",
          avoid_commentary: true,
          max_new_tokens: 1024,
          knowledge: ["doc1", "doc2"]
        )

      assert config.system_prompt == "You are a helpful assistant"
      assert config.avoid_commentary == true
      assert config.max_new_tokens == 1024
      assert config.knowledge == ["doc1", "doc2"]
    end
  end

  describe "New providers" do
    test "creates NVIDIA config" do
      config =
        Config.nvidia(
          model: "llama-3.1-405b",
          temperature: 0.7,
          max_tokens: 1000,
          base_url: "https://integrate.api.nvidia.com"
        )

      assert %Config.Nvidia{} = config
      assert config.model == "llama-3.1-405b"
      assert config.base_url == "https://integrate.api.nvidia.com"
    end

    test "creates Databricks config" do
      config =
        Config.databricks(
          model: "databricks-dbrx-instruct",
          endpoint: "https://my-workspace.cloud.databricks.com",
          temperature: 0.7
        )

      assert %Config.Databricks{} = config
      assert config.model == "databricks-dbrx-instruct"
      assert config.endpoint == "https://my-workspace.cloud.databricks.com"
    end

    test "creates FriendliAI config" do
      config =
        Config.friendliai(
          model: "meta-llama-3.1-70b-instruct",
          base_url: "https://inference.friendli.ai",
          temperature: 0.7
        )

      assert %Config.FriendliAI{} = config
      assert config.model == "meta-llama-3.1-70b-instruct"
    end
  end

  describe "provider_name/1" do
    test "returns correct provider name for each config type" do
      assert Config.provider_name(%Config.OpenAI{}) == :openai
      assert Config.provider_name(%Config.OpenAI{is_azure: true}) == :azure_openai
      assert Config.provider_name(%Config.Anthropic{}) == :anthropic
      assert Config.provider_name(%Config.Cohere{}) == :cohere
      assert Config.provider_name(%Config.AWS{service: "bedrock"}) == :aws_bedrock
      assert Config.provider_name(%Config.AWS{service: "sagemaker"}) == :aws_sagemaker
      assert Config.provider_name(%Config.Google{}) == :google
      assert Config.provider_name(%Config.Mistral{}) == :mistral
      assert Config.provider_name(%Config.Ollama{}) == :ollama
      assert Config.provider_name(%Config.XAI{}) == :xai
      assert Config.provider_name(%Config.ContextualAI{}) == :contextualai
      assert Config.provider_name(%Config.Nvidia{}) == :nvidia
      assert Config.provider_name(%Config.Databricks{}) == :databricks
      assert Config.provider_name(%Config.FriendliAI{}) == :friendliai
    end
  end
end
