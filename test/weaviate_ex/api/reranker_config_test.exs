defmodule WeaviateEx.API.RerankerConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.RerankerConfig

  describe "nvidia/2" do
    test "creates NVIDIA reranker config with default model" do
      config = RerankerConfig.nvidia()

      assert config == %{"reranker-nvidia" => %{}}
    end

    test "creates NVIDIA reranker config with model" do
      config = RerankerConfig.nvidia("nvidia-nemo-retriever-qa-mistral-4b-instruct")

      assert config == %{
               "reranker-nvidia" => %{
                 "model" => "nvidia-nemo-retriever-qa-mistral-4b-instruct"
               }
             }
    end

    test "creates NVIDIA reranker config with base_url option" do
      config = RerankerConfig.nvidia("nvidia-rerank", base_url: "https://api.nvidia.com")

      assert config == %{
               "reranker-nvidia" => %{
                 "model" => "nvidia-rerank",
                 "baseURL" => "https://api.nvidia.com"
               }
             }
    end

    test "omits nil values" do
      config = RerankerConfig.nvidia(nil)

      refute Map.has_key?(config["reranker-nvidia"], "model")
    end
  end

  describe "contextualai/2" do
    test "creates ContextualAI reranker config with default model" do
      config = RerankerConfig.contextualai()

      assert config == %{"reranker-contextualai" => %{}}
    end

    test "creates ContextualAI reranker config with model" do
      config = RerankerConfig.contextualai("ctxai-rerank-v1")

      assert config == %{
               "reranker-contextualai" => %{
                 "model" => "ctxai-rerank-v1"
               }
             }
    end

    test "creates ContextualAI reranker config with base_url option" do
      config = RerankerConfig.contextualai("ctxai-rerank", base_url: "https://api.contextual.ai")

      assert config == %{
               "reranker-contextualai" => %{
                 "model" => "ctxai-rerank",
                 "baseURL" => "https://api.contextual.ai"
               }
             }
    end

    test "creates ContextualAI reranker config with instruction option" do
      config = RerankerConfig.contextualai("ctxai-rerank", instruction: "Rank by relevance")

      assert config == %{
               "reranker-contextualai" => %{
                 "model" => "ctxai-rerank",
                 "instruction" => "Rank by relevance"
               }
             }
    end

    test "creates ContextualAI reranker config with all options" do
      config =
        RerankerConfig.contextualai("ctxai-rerank",
          base_url: "https://api.contextual.ai",
          instruction: "Rank documents"
        )

      assert config == %{
               "reranker-contextualai" => %{
                 "model" => "ctxai-rerank",
                 "baseURL" => "https://api.contextual.ai",
                 "instruction" => "Rank documents"
               }
             }
    end

    test "omits nil values" do
      config = RerankerConfig.contextualai(nil)

      refute Map.has_key?(config["reranker-contextualai"], "model")
    end
  end

  describe "cohere/2" do
    test "creates Cohere reranker config with default model" do
      config = RerankerConfig.cohere()

      assert config == %{
               "reranker-cohere" => %{
                 "model" => "rerank-english-v2.0"
               }
             }
    end

    test "creates Cohere reranker config with custom model" do
      config = RerankerConfig.cohere("rerank-english-v3.0")

      assert config["reranker-cohere"]["model"] == "rerank-english-v3.0"
    end

    test "accepts base_url option" do
      config = RerankerConfig.cohere("rerank-english-v3.0", base_url: "https://api.cohere.ai")

      assert config["reranker-cohere"]["baseURL"] == "https://api.cohere.ai"
    end
  end

  describe "transformers/1" do
    test "creates transformers reranker config with defaults" do
      config = RerankerConfig.transformers()

      assert config == %{"reranker-transformers" => %{}}
    end

    test "accepts inference_url option" do
      config = RerankerConfig.transformers(inference_url: "http://localhost:8080")

      assert config["reranker-transformers"]["inferenceUrl"] == "http://localhost:8080"
    end
  end

  describe "voyageai/2" do
    test "creates VoyageAI reranker config with model" do
      config = RerankerConfig.voyageai("rerank-1")

      assert config == %{
               "reranker-voyageai" => %{
                 "model" => "rerank-1"
               }
             }
    end

    test "accepts base_url and truncation options" do
      config =
        RerankerConfig.voyageai("rerank-1",
          base_url: "https://api.voyageai.com",
          truncation: true
        )

      assert config["reranker-voyageai"]["baseURL"] == "https://api.voyageai.com"
      assert config["reranker-voyageai"]["truncation"] == true
    end
  end

  describe "jinaai/2" do
    test "creates JinaAI reranker config with model" do
      config = RerankerConfig.jinaai("jina-reranker-v1-base-en")

      assert config == %{
               "reranker-jinaai" => %{
                 "model" => "jina-reranker-v1-base-en"
               }
             }
    end

    test "accepts base_url option" do
      config = RerankerConfig.jinaai("jina-reranker-v1", base_url: "https://api.jina.ai")

      assert config["reranker-jinaai"]["baseURL"] == "https://api.jina.ai"
    end
  end

  describe "none/0" do
    test "creates a none reranker config" do
      config = RerankerConfig.none()

      assert config == %{"none" => %{}}
    end
  end

  describe "custom/2" do
    test "creates custom reranker config with options" do
      config =
        RerankerConfig.custom("my-reranker",
          api_endpoint: "https://reranker.example.com",
          model: "v1"
        )

      assert config["reranker-custom"]["apiEndpoint"] == "https://reranker.example.com"
      assert config["reranker-custom"]["model"] == "v1"
      assert config["reranker-custom"][:_custom_name] == "my-reranker"
    end
  end
end
