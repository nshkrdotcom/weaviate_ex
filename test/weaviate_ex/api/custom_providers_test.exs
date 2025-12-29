defmodule WeaviateEx.API.CustomProvidersTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.GenerativeConfig
  alias WeaviateEx.API.RerankerConfig

  describe "GenerativeConfig.custom/2" do
    test "creates config for unlisted provider" do
      config =
        GenerativeConfig.custom("my-custom-llm",
          api_endpoint: "https://my-llm.example.com/v1",
          model: "custom-model-v1"
        )

      assert Map.has_key?(config, "generative-custom")
      assert config["generative-custom"]["apiEndpoint"] == "https://my-llm.example.com/v1"
      assert config["generative-custom"]["model"] == "custom-model-v1"
    end

    test "accepts arbitrary options with camelCase conversion" do
      config =
        GenerativeConfig.custom("local-llm",
          api_endpoint: "http://localhost:8000",
          custom_param: "value",
          another_param: 123,
          max_tokens: 500
        )

      assert config["generative-custom"]["customParam"] == "value"
      assert config["generative-custom"]["anotherParam"] == 123
      assert config["generative-custom"]["maxTokens"] == 500
    end

    test "stores custom provider name" do
      config = GenerativeConfig.custom("enterprise-llm", model: "gpt-enterprise")

      assert config["generative-custom"][:_custom_name] == "enterprise-llm"
    end

    test "handles api_key_header option" do
      config =
        GenerativeConfig.custom("secure-llm",
          api_endpoint: "https://secure.example.com",
          api_key_header: "X-Custom-Key"
        )

      assert config["generative-custom"]["apiKeyHeader"] == "X-Custom-Key"
    end
  end

  describe "RerankerConfig.cohere/2" do
    test "creates default cohere config" do
      config = RerankerConfig.cohere()

      assert Map.has_key?(config, "reranker-cohere")
      assert config["reranker-cohere"]["model"] == "rerank-english-v2.0"
    end

    test "accepts custom model" do
      config = RerankerConfig.cohere("rerank-english-v3.0")

      assert config["reranker-cohere"]["model"] == "rerank-english-v3.0"
    end

    test "accepts base_url option" do
      config = RerankerConfig.cohere("rerank-english-v3.0", base_url: "https://custom.cohere.ai")

      assert config["reranker-cohere"]["baseURL"] == "https://custom.cohere.ai"
    end
  end

  describe "RerankerConfig.transformers/1" do
    test "creates default transformers config" do
      config = RerankerConfig.transformers()

      assert Map.has_key?(config, "reranker-transformers")
    end

    test "accepts inference_url option" do
      config = RerankerConfig.transformers(inference_url: "http://localhost:8080")

      assert config["reranker-transformers"]["inferenceUrl"] == "http://localhost:8080"
    end

    test "accepts query_key and passage_key options" do
      config = RerankerConfig.transformers(query_key: "query", passage_key: "passage")

      assert config["reranker-transformers"]["queryKey"] == "query"
      assert config["reranker-transformers"]["passageKey"] == "passage"
    end
  end

  describe "RerankerConfig.voyageai/2" do
    test "creates voyageai config" do
      config = RerankerConfig.voyageai("rerank-1")

      assert Map.has_key?(config, "reranker-voyageai")
      assert config["reranker-voyageai"]["model"] == "rerank-1"
    end

    test "accepts base_url option" do
      config = RerankerConfig.voyageai("rerank-1", base_url: "https://api.voyageai.com")

      assert config["reranker-voyageai"]["baseURL"] == "https://api.voyageai.com"
    end
  end

  describe "RerankerConfig.jinaai/2" do
    test "creates jinaai config" do
      config = RerankerConfig.jinaai("jina-reranker-v1-base-en")

      assert Map.has_key?(config, "reranker-jinaai")
      assert config["reranker-jinaai"]["model"] == "jina-reranker-v1-base-en"
    end

    test "accepts base_url option" do
      config = RerankerConfig.jinaai("jina-reranker-v1-base-en", base_url: "https://api.jina.ai")

      assert config["reranker-jinaai"]["baseURL"] == "https://api.jina.ai"
    end
  end

  describe "RerankerConfig.custom/2" do
    test "creates config for unlisted reranker" do
      config =
        RerankerConfig.custom("my-reranker",
          api_endpoint: "https://reranker.example.com",
          model: "rerank-v1"
        )

      assert Map.has_key?(config, "reranker-custom")
      assert config["reranker-custom"]["apiEndpoint"] == "https://reranker.example.com"
      assert config["reranker-custom"]["model"] == "rerank-v1"
    end

    test "accepts arbitrary options with camelCase conversion" do
      config =
        RerankerConfig.custom("local-reranker",
          api_endpoint: "http://localhost:9000",
          max_tokens: 512,
          batch_size: 32
        )

      assert config["reranker-custom"]["maxTokens"] == 512
      assert config["reranker-custom"]["batchSize"] == 32
    end

    test "stores custom provider name" do
      config = RerankerConfig.custom("enterprise-reranker", model: "rerank-enterprise")

      assert config["reranker-custom"][:_custom_name] == "enterprise-reranker"
    end
  end

  describe "RerankerConfig.none/0" do
    test "creates none config for disabling reranking" do
      config = RerankerConfig.none()

      assert config == %{"none" => %{}}
    end
  end

  describe "integration scenarios" do
    test "custom generative with all common options" do
      config =
        GenerativeConfig.custom("enterprise-llm",
          api_endpoint: "https://llm.company.com/v1",
          model: "enterprise-gpt",
          api_key_header: "X-API-Key",
          temperature: 0.7,
          max_tokens: 4096,
          top_p: 0.9
        )

      gc = config["generative-custom"]
      assert gc["apiEndpoint"] == "https://llm.company.com/v1"
      assert gc["model"] == "enterprise-gpt"
      assert gc["apiKeyHeader"] == "X-API-Key"
      assert gc["temperature"] == 0.7
      assert gc["maxTokens"] == 4096
      assert gc["topP"] == 0.9
    end

    test "custom reranker with various options" do
      config =
        RerankerConfig.custom("custom-reranker",
          api_endpoint: "https://reranker.company.com",
          model: "rerank-v2",
          query_max_length: 256,
          passage_max_length: 512,
          batch_size: 16
        )

      rc = config["reranker-custom"]
      assert rc["apiEndpoint"] == "https://reranker.company.com"
      assert rc["model"] == "rerank-v2"
      assert rc["queryMaxLength"] == 256
      assert rc["passageMaxLength"] == 512
      assert rc["batchSize"] == 16
    end
  end
end
