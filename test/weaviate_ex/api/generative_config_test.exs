defmodule WeaviateEx.API.GenerativeConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.GenerativeConfig

  describe "openai/1" do
    test "creates OpenAI config with model" do
      config = GenerativeConfig.openai(model: "gpt-4")

      assert config == %{
               "generative-openai" => %{model: "gpt-4"}
             }
    end

    test "creates OpenAI config with all options" do
      config =
        GenerativeConfig.openai(
          model: "gpt-4",
          temperature: 0.7,
          max_tokens: 500,
          base_url: "https://custom.openai.com"
        )

      assert config["generative-openai"].model == "gpt-4"
      assert config["generative-openai"].temperature == 0.7
      assert config["generative-openai"].maxTokens == 500
      assert config["generative-openai"].baseURL == "https://custom.openai.com"
    end

    test "creates OpenAI config with defaults" do
      config = GenerativeConfig.openai()

      assert config == %{"generative-openai" => %{}}
    end
  end

  describe "azure_openai/1" do
    test "creates Azure OpenAI config with required options" do
      config =
        GenerativeConfig.azure_openai(
          resource_name: "my-resource",
          deployment_id: "gpt-4-deployment"
        )

      assert config["generative-openai"].resourceName == "my-resource"
      assert config["generative-openai"].deploymentId == "gpt-4-deployment"
    end

    test "creates Azure OpenAI config with all options" do
      config =
        GenerativeConfig.azure_openai(
          resource_name: "my-resource",
          deployment_id: "gpt-4-deployment",
          temperature: 0.5,
          max_tokens: 1000
        )

      assert config["generative-openai"].resourceName == "my-resource"
      assert config["generative-openai"].deploymentId == "gpt-4-deployment"
      assert config["generative-openai"].temperature == 0.5
      assert config["generative-openai"].maxTokens == 1000
    end
  end

  describe "cohere/1" do
    test "creates Cohere config with model" do
      config = GenerativeConfig.cohere(model: "command-r-plus")

      assert config == %{
               "generative-cohere" => %{model: "command-r-plus"}
             }
    end

    test "creates Cohere config with all options" do
      config =
        GenerativeConfig.cohere(
          model: "command-r",
          temperature: 0.8,
          max_tokens: 2000,
          k: 5,
          p: 0.9
        )

      assert config["generative-cohere"].model == "command-r"
      assert config["generative-cohere"].temperature == 0.8
      assert config["generative-cohere"].maxTokens == 2000
      assert config["generative-cohere"].k == 5
      assert config["generative-cohere"].p == 0.9
    end
  end

  describe "anthropic/1" do
    test "creates Anthropic config with model" do
      config = GenerativeConfig.anthropic(model: "claude-3-5-sonnet-latest")

      assert config == %{
               "generative-anthropic" => %{model: "claude-3-5-sonnet-latest"}
             }
    end

    test "creates Anthropic config with all options" do
      config =
        GenerativeConfig.anthropic(
          model: "claude-3-opus-20240229",
          temperature: 0.7,
          max_tokens: 4096,
          top_k: 40,
          top_p: 0.95
        )

      assert config["generative-anthropic"].model == "claude-3-opus-20240229"
      assert config["generative-anthropic"].temperature == 0.7
      assert config["generative-anthropic"].maxTokens == 4096
      assert config["generative-anthropic"].topK == 40
      assert config["generative-anthropic"].topP == 0.95
    end
  end

  describe "mistral/1" do
    test "creates Mistral config with model" do
      config = GenerativeConfig.mistral(model: "mistral-large-latest")

      assert config == %{
               "generative-mistral" => %{model: "mistral-large-latest"}
             }
    end

    test "creates Mistral config with all options" do
      config =
        GenerativeConfig.mistral(
          model: "mistral-medium",
          temperature: 0.6,
          max_tokens: 1000,
          base_url: "https://custom.mistral.ai"
        )

      assert config["generative-mistral"].model == "mistral-medium"
      assert config["generative-mistral"].temperature == 0.6
      assert config["generative-mistral"].maxTokens == 1000
      assert config["generative-mistral"].baseURL == "https://custom.mistral.ai"
    end
  end

  describe "google/1" do
    test "creates Google config with model" do
      config = GenerativeConfig.google(model: "gemini-pro")

      assert config == %{
               "generative-palm" => %{model: "gemini-pro"}
             }
    end

    test "creates Google config with all options" do
      config =
        GenerativeConfig.google(
          model: "gemini-1.5-pro",
          temperature: 0.4,
          max_tokens: 8192,
          project_id: "my-gcp-project"
        )

      assert config["generative-palm"].model == "gemini-1.5-pro"
      assert config["generative-palm"].temperature == 0.4
      assert config["generative-palm"].maxTokens == 8192
      assert config["generative-palm"].projectId == "my-gcp-project"
    end
  end

  describe "aws/1" do
    test "creates AWS config with model and region" do
      config = GenerativeConfig.aws(model: "anthropic.claude-v2", region: "us-east-1")

      assert config["generative-aws"].model == "anthropic.claude-v2"
      assert config["generative-aws"].region == "us-east-1"
    end

    test "creates AWS config with service type" do
      config =
        GenerativeConfig.aws(
          model: "anthropic.claude-v2",
          region: "us-west-2",
          service: "bedrock"
        )

      assert config["generative-aws"].service == "bedrock"
    end

    test "creates AWS config with all options" do
      config =
        GenerativeConfig.aws(
          model: "anthropic.claude-v2",
          region: "us-east-1",
          service: "bedrock",
          temperature: 0.5,
          max_tokens: 2000
        )

      assert config["generative-aws"].model == "anthropic.claude-v2"
      assert config["generative-aws"].region == "us-east-1"
      assert config["generative-aws"].service == "bedrock"
      assert config["generative-aws"].temperature == 0.5
      assert config["generative-aws"].maxTokens == 2000
    end
  end

  describe "ollama/1" do
    test "creates Ollama config with model" do
      config = GenerativeConfig.ollama(model: "llama3")

      assert config == %{
               "generative-ollama" => %{model: "llama3"}
             }
    end

    test "creates Ollama config with all options" do
      config =
        GenerativeConfig.ollama(
          model: "llama3:70b",
          api_endpoint: "http://localhost:11434",
          temperature: 0.8
        )

      assert config["generative-ollama"].model == "llama3:70b"
      assert config["generative-ollama"].apiEndpoint == "http://localhost:11434"
      assert config["generative-ollama"].temperature == 0.8
    end
  end

  describe "databricks/1" do
    test "creates Databricks config with endpoint" do
      config = GenerativeConfig.databricks(endpoint: "https://my-workspace.cloud.databricks.com")

      assert config["generative-databricks"].endpoint ==
               "https://my-workspace.cloud.databricks.com"
    end

    test "creates Databricks config with all options" do
      config =
        GenerativeConfig.databricks(
          endpoint: "https://my-workspace.cloud.databricks.com",
          temperature: 0.7,
          max_tokens: 1500,
          top_k: 50,
          top_p: 0.95
        )

      assert config["generative-databricks"].endpoint ==
               "https://my-workspace.cloud.databricks.com"

      assert config["generative-databricks"].temperature == 0.7
      assert config["generative-databricks"].maxTokens == 1500
      assert config["generative-databricks"].topK == 50
      assert config["generative-databricks"].topP == 0.95
    end
  end

  describe "nvidia/1" do
    test "creates NVIDIA config with model" do
      config = GenerativeConfig.nvidia(model: "meta/llama-3.1-405b-instruct")

      assert config["generative-nvidia"].model == "meta/llama-3.1-405b-instruct"
    end

    test "creates NVIDIA config with all options" do
      config =
        GenerativeConfig.nvidia(
          model: "meta/llama-3.1-70b-instruct",
          base_url: "https://api.nvidia.com",
          temperature: 0.6,
          max_tokens: 2000
        )

      assert config["generative-nvidia"].model == "meta/llama-3.1-70b-instruct"
      assert config["generative-nvidia"].baseURL == "https://api.nvidia.com"
      assert config["generative-nvidia"].temperature == 0.6
      assert config["generative-nvidia"].maxTokens == 2000
    end
  end

  describe "friendliai/1" do
    test "creates FriendliAI config with model" do
      config = GenerativeConfig.friendliai(model: "mixtral-8x7b")

      assert config["generative-friendliai"].model == "mixtral-8x7b"
    end

    test "creates FriendliAI config with all options" do
      config =
        GenerativeConfig.friendliai(
          model: "llama-3-70b",
          base_url: "https://api.friendli.ai",
          temperature: 0.7,
          max_tokens: 1000
        )

      assert config["generative-friendliai"].model == "llama-3-70b"
      assert config["generative-friendliai"].baseURL == "https://api.friendli.ai"
      assert config["generative-friendliai"].temperature == 0.7
      assert config["generative-friendliai"].maxTokens == 1000
    end
  end

  describe "xai/1" do
    test "creates XAI config with model" do
      config = GenerativeConfig.xai(model: "grok-2")

      assert config["generative-xai"].model == "grok-2"
    end

    test "creates XAI config with all options" do
      config =
        GenerativeConfig.xai(
          model: "grok-2",
          temperature: 0.8,
          max_tokens: 2000,
          base_url: "https://api.x.ai"
        )

      assert config["generative-xai"].model == "grok-2"
      assert config["generative-xai"].temperature == 0.8
      assert config["generative-xai"].maxTokens == 2000
      assert config["generative-xai"].baseURL == "https://api.x.ai"
    end
  end

  describe "anyscale/1" do
    test "creates Anyscale config with model" do
      config = GenerativeConfig.anyscale(model: "meta-llama/Llama-3-70b-chat-hf")

      assert config["generative-anyscale"].model == "meta-llama/Llama-3-70b-chat-hf"
    end

    test "creates Anyscale config with all options" do
      config =
        GenerativeConfig.anyscale(
          model: "meta-llama/Llama-3-70b-chat-hf",
          base_url: "https://api.anyscale.com",
          temperature: 0.5
        )

      assert config["generative-anyscale"].model == "meta-llama/Llama-3-70b-chat-hf"
      assert config["generative-anyscale"].baseURL == "https://api.anyscale.com"
      assert config["generative-anyscale"].temperature == 0.5
    end
  end

  describe "contextualai/1" do
    test "creates ContextualAI config" do
      config = GenerativeConfig.contextualai()

      assert config == %{"generative-contextualai" => %{}}
    end

    test "creates ContextualAI config with model" do
      config = GenerativeConfig.contextualai(model: "grounded-generation")

      assert config["generative-contextualai"].model == "grounded-generation"
    end
  end

  describe "providers/0" do
    test "lists all supported providers" do
      providers = GenerativeConfig.providers()

      assert :openai in providers
      assert :anthropic in providers
      assert :cohere in providers
      assert :mistral in providers
      assert :google in providers
      assert :aws in providers
      assert :ollama in providers
      assert :databricks in providers
      assert :nvidia in providers
      assert :friendliai in providers
      assert :xai in providers
      assert :anyscale in providers
      assert :contextualai in providers
    end
  end

  describe "provider_module/1" do
    test "returns module name for provider" do
      assert GenerativeConfig.provider_module(:openai) == "generative-openai"
      assert GenerativeConfig.provider_module(:anthropic) == "generative-anthropic"
      assert GenerativeConfig.provider_module(:cohere) == "generative-cohere"
      assert GenerativeConfig.provider_module(:google) == "generative-palm"
      assert GenerativeConfig.provider_module(:aws) == "generative-aws"
    end
  end
end
