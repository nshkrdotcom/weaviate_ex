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

  describe "update_config/2" do
    test "creates update config for vector index" do
      update =
        NamedVectors.update_config("title_vector",
          vector_index: [
            ef: 200,
            dynamic_ef_min: 50,
            dynamic_ef_max: 500
          ]
        )

      assert update.name == "title_vector"
      assert update.vector_index_config["ef"] == 200
      assert update.vector_index_config["dynamicEfMin"] == 50
      assert update.vector_index_config["dynamicEfMax"] == 500
    end

    test "creates update config for quantizer" do
      update =
        NamedVectors.update_config("content_vector",
          quantizer: [
            type: :pq,
            segments: 128
          ]
        )

      assert update.name == "content_vector"
      assert update.quantizer_config["type"] == "pq"
      assert update.quantizer_config["segments"] == 128
    end

    test "creates update config with both vector_index and quantizer" do
      update =
        NamedVectors.update_config("embedding",
          vector_index: [ef: 150],
          quantizer: [type: :bq, rescore_limit: 200]
        )

      assert update.vector_index_config["ef"] == 150
      assert update.quantizer_config["type"] == "bq"
      assert update.quantizer_config["rescoreLimit"] == 200
    end

    test "supports all vector index options" do
      update =
        NamedVectors.update_config("test_vector",
          vector_index: [
            ef: 200,
            dynamic_ef_min: 50,
            dynamic_ef_max: 500,
            dynamic_ef_factor: 8,
            flat_search_cutoff: 40_000
          ]
        )

      vic = update.vector_index_config
      assert vic["ef"] == 200
      assert vic["dynamicEfMin"] == 50
      assert vic["dynamicEfMax"] == 500
      assert vic["dynamicEfFactor"] == 8
      assert vic["flatSearchCutoff"] == 40_000
    end

    test "supports all quantizer types" do
      pq_update = NamedVectors.update_config("pq_vector", quantizer: [type: :pq])
      bq_update = NamedVectors.update_config("bq_vector", quantizer: [type: :bq])
      sq_update = NamedVectors.update_config("sq_vector", quantizer: [type: :sq])

      assert pq_update.quantizer_config["type"] == "pq"
      assert bq_update.quantizer_config["type"] == "bq"
      assert sq_update.quantizer_config["type"] == "sq"
    end
  end

  describe "update_to_api/1" do
    test "converts update to API format" do
      update =
        NamedVectors.update_config("title_vector",
          vector_index: [ef: 200]
        )

      api = NamedVectors.update_to_api(update)

      assert api["vectorConfig"]["title_vector"]["vectorIndexConfig"]["ef"] == 200
    end

    test "includes quantizer in vectorIndexConfig" do
      update =
        NamedVectors.update_config("content_vector",
          quantizer: [type: :pq, segments: 128]
        )

      api = NamedVectors.update_to_api(update)

      assert api["vectorConfig"]["content_vector"]["vectorIndexConfig"]["quantizer"]["type"] ==
               "pq"

      assert api["vectorConfig"]["content_vector"]["vectorIndexConfig"]["quantizer"]["segments"] ==
               128
    end

    test "combines vector_index and quantizer" do
      update =
        NamedVectors.update_config("embedding",
          vector_index: [ef: 300],
          quantizer: [type: :bq]
        )

      api = NamedVectors.update_to_api(update)

      vic = api["vectorConfig"]["embedding"]["vectorIndexConfig"]
      assert vic["ef"] == 300
      assert vic["quantizer"]["type"] == "bq"
    end
  end

  describe "build_update_config/1" do
    test "builds combined update config for multiple vectors" do
      updates = [
        NamedVectors.update_config("title_vector", vector_index: [ef: 200]),
        NamedVectors.update_config("content_vector", vector_index: [ef: 150])
      ]

      result = NamedVectors.build_update_config(updates)

      assert Map.has_key?(result["vectorConfig"], "title_vector")
      assert Map.has_key?(result["vectorConfig"], "content_vector")
      assert result["vectorConfig"]["title_vector"]["vectorIndexConfig"]["ef"] == 200
      assert result["vectorConfig"]["content_vector"]["vectorIndexConfig"]["ef"] == 150
    end
  end
end
