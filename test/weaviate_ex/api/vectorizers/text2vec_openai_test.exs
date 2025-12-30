defmodule WeaviateEx.API.Vectorizers.Text2VecOpenAITest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Vectorizers.Text2VecOpenAI

  describe "vectorizer_name/0" do
    test "returns the correct vectorizer name" do
      assert Text2VecOpenAI.vectorizer_name() == "text2vec-openai"
    end
  end

  describe "new/1" do
    test "creates config with default values" do
      config = Text2VecOpenAI.new()

      assert %Text2VecOpenAI{} = config
      assert config.model == nil
      assert config.dimensions == nil
      assert config.base_url == nil
      assert config.type == nil
      assert config.vectorize_collection_name == true
    end

    test "creates config with model option" do
      config = Text2VecOpenAI.new(model: "text-embedding-3-small")

      assert config.model == "text-embedding-3-small"
    end

    test "creates config with dimensions option" do
      config = Text2VecOpenAI.new(dimensions: 512)

      assert config.dimensions == 512
    end

    test "creates config with base_url option" do
      config = Text2VecOpenAI.new(base_url: "https://custom.openai.com")

      assert config.base_url == "https://custom.openai.com"
    end

    test "creates config with type option :text" do
      config = Text2VecOpenAI.new(type: :text)

      assert config.type == :text
    end

    test "creates config with type option :code" do
      config = Text2VecOpenAI.new(type: :code)

      assert config.type == :code
    end

    test "creates config with vectorize_collection_name set to false" do
      config = Text2VecOpenAI.new(vectorize_collection_name: false)

      assert config.vectorize_collection_name == false
    end

    test "creates config with all options" do
      config =
        Text2VecOpenAI.new(
          model: "text-embedding-3-large",
          dimensions: 1024,
          base_url: "https://api.openai.com/v1",
          type: :text,
          vectorize_collection_name: false
        )

      assert config.model == "text-embedding-3-large"
      assert config.dimensions == 1024
      assert config.base_url == "https://api.openai.com/v1"
      assert config.type == :text
      assert config.vectorize_collection_name == false
    end
  end

  describe "to_api/1" do
    test "converts config to API format with only default vectorize_collection_name" do
      config = Text2VecOpenAI.new()
      api = Text2VecOpenAI.to_api(config)

      assert api == %{
               "vectorizer" => "text2vec-openai",
               "moduleConfig" => %{
                 "text2vec-openai" => %{
                   "vectorizeClassName" => true
                 }
               }
             }
    end

    test "converts config with model to API format" do
      config = Text2VecOpenAI.new(model: "text-embedding-ada-002")
      api = Text2VecOpenAI.to_api(config)

      assert api["moduleConfig"]["text2vec-openai"]["model"] == "text-embedding-ada-002"
    end

    test "converts config with dimensions to API format" do
      config = Text2VecOpenAI.new(dimensions: 256)
      api = Text2VecOpenAI.to_api(config)

      assert api["moduleConfig"]["text2vec-openai"]["dimensions"] == 256
    end

    test "converts config with base_url to API format using baseURL key" do
      config = Text2VecOpenAI.new(base_url: "https://custom.openai.com")
      api = Text2VecOpenAI.to_api(config)

      assert api["moduleConfig"]["text2vec-openai"]["baseURL"] == "https://custom.openai.com"
    end

    test "converts config with type :text to API format" do
      config = Text2VecOpenAI.new(type: :text)
      api = Text2VecOpenAI.to_api(config)

      assert api["moduleConfig"]["text2vec-openai"]["type"] == "text"
    end

    test "converts config with type :code to API format" do
      config = Text2VecOpenAI.new(type: :code)
      api = Text2VecOpenAI.to_api(config)

      assert api["moduleConfig"]["text2vec-openai"]["type"] == "code"
    end

    test "omits nil values from API output" do
      config = Text2VecOpenAI.new(model: "text-embedding-3-small")
      api = Text2VecOpenAI.to_api(config)
      module_config = api["moduleConfig"]["text2vec-openai"]

      assert Map.has_key?(module_config, "model")
      refute Map.has_key?(module_config, "dimensions")
      refute Map.has_key?(module_config, "baseURL")
      refute Map.has_key?(module_config, "type")
    end

    test "converts full config to API format" do
      config =
        Text2VecOpenAI.new(
          model: "text-embedding-3-large",
          dimensions: 1024,
          base_url: "https://custom.openai.com",
          type: :code,
          vectorize_collection_name: false
        )

      api = Text2VecOpenAI.to_api(config)

      assert api == %{
               "vectorizer" => "text2vec-openai",
               "moduleConfig" => %{
                 "text2vec-openai" => %{
                   "vectorizeClassName" => false,
                   "model" => "text-embedding-3-large",
                   "dimensions" => 1024,
                   "baseURL" => "https://custom.openai.com",
                   "type" => "code"
                 }
               }
             }
    end
  end

  describe "from_api/1" do
    test "parses API response with minimal config" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert %Text2VecOpenAI{} = config
      assert config.vectorize_collection_name == true
      assert config.model == nil
    end

    test "parses API response with model" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "model" => "text-embedding-ada-002",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.model == "text-embedding-ada-002"
    end

    test "parses API response with dimensions" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "dimensions" => 512,
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.dimensions == 512
    end

    test "parses API response with baseURL" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "baseURL" => "https://custom.openai.com",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.base_url == "https://custom.openai.com"
    end

    test "parses API response with type text" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "type" => "text",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.type == :text
    end

    test "parses API response with type code" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "type" => "code",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.type == :code
    end

    test "parses full API response" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-openai" => %{
            "model" => "text-embedding-3-large",
            "dimensions" => 1024,
            "baseURL" => "https://custom.openai.com",
            "type" => "code",
            "vectorizeClassName" => false
          }
        }
      }

      config = Text2VecOpenAI.from_api(api_response)

      assert config.model == "text-embedding-3-large"
      assert config.dimensions == 1024
      assert config.base_url == "https://custom.openai.com"
      assert config.type == :code
      assert config.vectorize_collection_name == false
    end
  end

  describe "serialization round-trip" do
    test "preserves data through to_api and from_api" do
      original =
        Text2VecOpenAI.new(
          model: "text-embedding-3-small",
          dimensions: 512,
          base_url: "https://api.openai.com/v1",
          type: :text,
          vectorize_collection_name: true
        )

      api = Text2VecOpenAI.to_api(original)
      parsed = Text2VecOpenAI.from_api(api)

      assert parsed.model == original.model
      assert parsed.dimensions == original.dimensions
      assert parsed.base_url == original.base_url
      assert parsed.type == original.type
      assert parsed.vectorize_collection_name == original.vectorize_collection_name
    end

    test "preserves minimal config through round-trip" do
      original = Text2VecOpenAI.new()
      api = Text2VecOpenAI.to_api(original)
      parsed = Text2VecOpenAI.from_api(api)

      assert parsed.vectorize_collection_name == original.vectorize_collection_name
    end
  end
end
