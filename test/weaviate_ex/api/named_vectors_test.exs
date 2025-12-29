defmodule WeaviateEx.API.NamedVectorsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.NamedVectors

  describe "self_provided/1" do
    test "creates self-provided named vector config" do
      config = NamedVectors.self_provided(name: "custom_vector")

      assert config["name"] == "custom_vector"
      assert config["vectorizer"] == %{"none" => %{}}
      assert config["vectorIndexType"] == "hnsw"
    end

    test "accepts vector index type option" do
      config = NamedVectors.self_provided(name: "custom", vector_index_type: "flat")

      assert config["vectorIndexType"] == "flat"
    end
  end

  describe "text2vec_openai/1" do
    test "creates text2vec-openai named vector config" do
      config = NamedVectors.text2vec_openai(name: "title_vector")

      assert config["name"] == "title_vector"
      assert config["vectorizer"]["text2vec-openai"]["vectorizeClassName"] == true
    end

    test "accepts source properties" do
      config =
        NamedVectors.text2vec_openai(
          name: "title_vector",
          source_properties: ["title", "summary"]
        )

      vectorizer_config = config["vectorizer"]["text2vec-openai"]
      assert vectorizer_config["properties"] == ["title", "summary"]
    end

    test "accepts model option" do
      config =
        NamedVectors.text2vec_openai(
          name: "title_vector",
          model: "text-embedding-3-small"
        )

      assert config["vectorizer"]["text2vec-openai"]["model"] == "text-embedding-3-small"
    end

    test "accepts dimensions option" do
      config =
        NamedVectors.text2vec_openai(
          name: "title_vector",
          dimensions: 1024
        )

      assert config["vectorizer"]["text2vec-openai"]["dimensions"] == 1024
    end

    test "accepts base_url option" do
      config =
        NamedVectors.text2vec_openai(
          name: "title_vector",
          base_url: "https://custom-openai.example.com"
        )

      assert config["vectorizer"]["text2vec-openai"]["baseURL"] ==
               "https://custom-openai.example.com"
    end
  end

  describe "text2vec_cohere/1" do
    test "creates text2vec-cohere named vector config" do
      config = NamedVectors.text2vec_cohere(name: "cohere_vector", model: "embed-v4.0")

      assert config["name"] == "cohere_vector"
      assert config["vectorizer"]["text2vec-cohere"]["model"] == "embed-v4.0"
    end
  end

  describe "text2vec_huggingface/1" do
    test "creates text2vec-huggingface named vector config" do
      config = NamedVectors.text2vec_huggingface(name: "hf_vector")

      assert config["name"] == "hf_vector"
      assert Map.has_key?(config["vectorizer"], "text2vec-huggingface")
    end
  end

  describe "text2vec_voyageai/1" do
    test "creates text2vec-voyageai named vector config" do
      config = NamedVectors.text2vec_voyageai(name: "voyage_vector", model: "voyage-3")

      assert config["name"] == "voyage_vector"
      assert config["vectorizer"]["text2vec-voyageai"]["model"] == "voyage-3"
    end
  end

  describe "text2vec_jinaai/1" do
    test "creates text2vec-jinaai named vector config" do
      config = NamedVectors.text2vec_jinaai(name: "jina_vector", model: "jina-embeddings-v3")

      assert config["name"] == "jina_vector"
      assert config["vectorizer"]["text2vec-jinaai"]["model"] == "jina-embeddings-v3"
    end
  end

  describe "text2vec_ollama/1" do
    test "creates text2vec-ollama named vector config" do
      config =
        NamedVectors.text2vec_ollama(
          name: "ollama_vector",
          model: "llama2",
          api_endpoint: "http://localhost:11434"
        )

      assert config["name"] == "ollama_vector"
      assert config["vectorizer"]["text2vec-ollama"]["model"] == "llama2"
      assert config["vectorizer"]["text2vec-ollama"]["apiEndpoint"] == "http://localhost:11434"
    end
  end

  describe "text2vec_mistral/1" do
    test "creates text2vec-mistral named vector config" do
      config = NamedVectors.text2vec_mistral(name: "mistral_vector", model: "mistral-embed")

      assert config["name"] == "mistral_vector"
      assert config["vectorizer"]["text2vec-mistral"]["model"] == "mistral-embed"
    end
  end

  describe "text2vec_nvidia/1" do
    test "creates text2vec-nvidia named vector config" do
      config = NamedVectors.text2vec_nvidia(name: "nvidia_vector")

      assert config["name"] == "nvidia_vector"
      assert Map.has_key?(config["vectorizer"], "text2vec-nvidia")
    end
  end

  describe "text2vec_azure_openai/1" do
    test "creates text2vec-azure-openai named vector config" do
      config =
        NamedVectors.text2vec_azure_openai(
          name: "azure_vector",
          resource_name: "my-resource",
          deployment_id: "my-deployment"
        )

      assert config["name"] == "azure_vector"
      assert config["vectorizer"]["text2vec-azure-openai"]["resourceName"] == "my-resource"
      assert config["vectorizer"]["text2vec-azure-openai"]["deploymentId"] == "my-deployment"
    end
  end

  describe "text2vec_google_vertex/1" do
    test "creates text2vec-google (Vertex) named vector config" do
      config =
        NamedVectors.text2vec_google_vertex(
          name: "vertex_vector",
          project_id: "my-project",
          model: "textembedding-gecko@003"
        )

      assert config["name"] == "vertex_vector"
      assert config["vectorizer"]["text2vec-palm"]["projectId"] == "my-project"
    end
  end

  describe "multi2vec configurations" do
    test "multi2vec_clip creates CLIP config" do
      config =
        NamedVectors.multi2vec_clip(
          name: "clip_vector",
          image_fields: ["image"],
          text_fields: ["caption"]
        )

      assert config["name"] == "clip_vector"
      assert Map.has_key?(config["vectorizer"], "multi2vec-clip")
    end

    test "multi2vec_bind creates bind config" do
      config = NamedVectors.multi2vec_bind(name: "bind_vector")

      assert config["name"] == "bind_vector"
      assert Map.has_key?(config["vectorizer"], "multi2vec-bind")
    end
  end

  describe "build_vectorizer_config/1" do
    test "builds vectorizer config list for collection creation" do
      configs = [
        NamedVectors.text2vec_openai(
          name: "title_vector",
          source_properties: ["title"]
        ),
        NamedVectors.text2vec_openai(
          name: "content_vector",
          source_properties: ["content"]
        ),
        NamedVectors.self_provided(name: "custom_vector")
      ]

      result = NamedVectors.build_vectorizer_config(configs)

      assert is_map(result)
      assert Map.has_key?(result, "title_vector")
      assert Map.has_key?(result, "content_vector")
      assert Map.has_key?(result, "custom_vector")
    end
  end
end
