defmodule WeaviateEx.API.Vectorizers.Text2VecCohereTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Vectorizers.Text2VecCohere

  describe "vectorizer_name/0" do
    test "returns the correct vectorizer name" do
      assert Text2VecCohere.vectorizer_name() == "text2vec-cohere"
    end
  end

  describe "new/1" do
    test "creates config with default values" do
      config = Text2VecCohere.new()

      assert %Text2VecCohere{} = config
      assert config.model == nil
      assert config.dimensions == nil
      assert config.truncate == nil
      assert config.base_url == nil
      assert config.vectorize_collection_name == true
    end

    test "creates config with model option" do
      config = Text2VecCohere.new(model: "embed-english-v3.0")

      assert config.model == "embed-english-v3.0"
    end

    test "creates config with dimensions option" do
      config = Text2VecCohere.new(dimensions: 384)

      assert config.dimensions == 384
    end

    test "creates config with truncate option :none" do
      config = Text2VecCohere.new(truncate: :none)

      assert config.truncate == :none
    end

    test "creates config with truncate option :start" do
      config = Text2VecCohere.new(truncate: :start)

      assert config.truncate == :start
    end

    test "creates config with truncate option :end" do
      config = Text2VecCohere.new(truncate: :end)

      assert config.truncate == :end
    end

    test "creates config with base_url option" do
      config = Text2VecCohere.new(base_url: "https://custom.cohere.com")

      assert config.base_url == "https://custom.cohere.com"
    end

    test "creates config with vectorize_collection_name set to false" do
      config = Text2VecCohere.new(vectorize_collection_name: false)

      assert config.vectorize_collection_name == false
    end

    test "creates config with all options" do
      config =
        Text2VecCohere.new(
          model: "embed-multilingual-v3.0",
          dimensions: 512,
          truncate: :end,
          base_url: "https://api.cohere.ai",
          vectorize_collection_name: false
        )

      assert config.model == "embed-multilingual-v3.0"
      assert config.dimensions == 512
      assert config.truncate == :end
      assert config.base_url == "https://api.cohere.ai"
      assert config.vectorize_collection_name == false
    end
  end

  describe "to_api/1" do
    test "converts config to API format with only default vectorize_collection_name" do
      config = Text2VecCohere.new()
      api = Text2VecCohere.to_api(config)

      assert api == %{
               "vectorizer" => "text2vec-cohere",
               "moduleConfig" => %{
                 "text2vec-cohere" => %{
                   "vectorizeClassName" => true
                 }
               }
             }
    end

    test "converts config with model to API format" do
      config = Text2VecCohere.new(model: "embed-english-v3.0")
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["model"] == "embed-english-v3.0"
    end

    test "converts config with dimensions to API format" do
      config = Text2VecCohere.new(dimensions: 256)
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["dimensions"] == 256
    end

    test "converts config with truncate :none to API format" do
      config = Text2VecCohere.new(truncate: :none)
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["truncate"] == "NONE"
    end

    test "converts config with truncate :start to API format" do
      config = Text2VecCohere.new(truncate: :start)
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["truncate"] == "START"
    end

    test "converts config with truncate :end to API format" do
      config = Text2VecCohere.new(truncate: :end)
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["truncate"] == "END"
    end

    test "converts config with base_url to API format using baseURL key" do
      config = Text2VecCohere.new(base_url: "https://custom.cohere.com")
      api = Text2VecCohere.to_api(config)

      assert api["moduleConfig"]["text2vec-cohere"]["baseURL"] == "https://custom.cohere.com"
    end

    test "omits nil values from API output" do
      config = Text2VecCohere.new(model: "embed-english-v3.0")
      api = Text2VecCohere.to_api(config)
      module_config = api["moduleConfig"]["text2vec-cohere"]

      assert Map.has_key?(module_config, "model")
      refute Map.has_key?(module_config, "dimensions")
      refute Map.has_key?(module_config, "baseURL")
      refute Map.has_key?(module_config, "truncate")
    end

    test "converts full config to API format" do
      config =
        Text2VecCohere.new(
          model: "embed-multilingual-v3.0",
          dimensions: 512,
          truncate: :end,
          base_url: "https://api.cohere.ai",
          vectorize_collection_name: false
        )

      api = Text2VecCohere.to_api(config)

      assert api == %{
               "vectorizer" => "text2vec-cohere",
               "moduleConfig" => %{
                 "text2vec-cohere" => %{
                   "vectorizeClassName" => false,
                   "model" => "embed-multilingual-v3.0",
                   "dimensions" => 512,
                   "truncate" => "END",
                   "baseURL" => "https://api.cohere.ai"
                 }
               }
             }
    end
  end

  describe "from_api/1" do
    test "parses API response with minimal config" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert %Text2VecCohere{} = config
      assert config.vectorize_collection_name == true
      assert config.model == nil
    end

    test "parses API response with model" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "model" => "embed-english-v3.0",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.model == "embed-english-v3.0"
    end

    test "parses API response with dimensions" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "dimensions" => 384,
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.dimensions == 384
    end

    test "parses API response with truncate NONE" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "truncate" => "NONE",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.truncate == :none
    end

    test "parses API response with truncate START" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "truncate" => "START",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.truncate == :start
    end

    test "parses API response with truncate END" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "truncate" => "END",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.truncate == :end
    end

    test "parses API response with baseURL" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "baseURL" => "https://custom.cohere.com",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.base_url == "https://custom.cohere.com"
    end

    test "parses full API response" do
      api_response = %{
        "moduleConfig" => %{
          "text2vec-cohere" => %{
            "model" => "embed-multilingual-v3.0",
            "dimensions" => 512,
            "truncate" => "END",
            "baseURL" => "https://api.cohere.ai",
            "vectorizeClassName" => false
          }
        }
      }

      config = Text2VecCohere.from_api(api_response)

      assert config.model == "embed-multilingual-v3.0"
      assert config.dimensions == 512
      assert config.truncate == :end
      assert config.base_url == "https://api.cohere.ai"
      assert config.vectorize_collection_name == false
    end
  end

  describe "serialization round-trip" do
    test "preserves data through to_api and from_api" do
      original =
        Text2VecCohere.new(
          model: "embed-english-v3.0",
          dimensions: 384,
          truncate: :end,
          base_url: "https://api.cohere.ai",
          vectorize_collection_name: true
        )

      api = Text2VecCohere.to_api(original)
      parsed = Text2VecCohere.from_api(api)

      assert parsed.model == original.model
      assert parsed.dimensions == original.dimensions
      assert parsed.truncate == original.truncate
      assert parsed.base_url == original.base_url
      assert parsed.vectorize_collection_name == original.vectorize_collection_name
    end

    test "preserves minimal config through round-trip" do
      original = Text2VecCohere.new()
      api = Text2VecCohere.to_api(original)
      parsed = Text2VecCohere.from_api(api)

      assert parsed.vectorize_collection_name == original.vectorize_collection_name
    end
  end
end
