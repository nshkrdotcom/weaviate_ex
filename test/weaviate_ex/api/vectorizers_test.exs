defmodule WeaviateEx.API.VectorizersTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Vectorizers.{Img2VecNeural, Text2VecAWS, Text2VecGoogle, Text2VecWeaviate}

  describe "Text2VecAWS" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecAWS.vectorizer_name() == "text2vec-aws"
    end

    test "new/1 creates default Bedrock config" do
      config =
        Text2VecAWS.new(
          service: :bedrock,
          model: "amazon.titan-embed-text-v1",
          region: "us-east-1"
        )

      assert %Text2VecAWS{} = config
      assert config.service == :bedrock
      assert config.model == "amazon.titan-embed-text-v1"
      assert config.region == "us-east-1"
      assert config.vectorize_collection_name == true
    end

    test "new/1 creates SageMaker config" do
      config =
        Text2VecAWS.new(
          service: :sagemaker,
          endpoint: "my-endpoint",
          region: "us-west-2",
          target_model: "target",
          target_variant: "variant"
        )

      assert %Text2VecAWS{} = config
      assert config.service == :sagemaker
      assert config.endpoint == "my-endpoint"
      assert config.region == "us-west-2"
      assert config.target_model == "target"
      assert config.target_variant == "variant"
    end

    test "to_api/1 converts Bedrock config to API format" do
      config =
        Text2VecAWS.new(
          service: :bedrock,
          model: "amazon.titan-embed-text-v1",
          region: "us-east-1",
          vectorize_collection_name: false
        )

      api_format = Text2VecAWS.to_api(config)

      assert api_format == %{
               "vectorizer" => "text2vec-aws",
               "moduleConfig" => %{
                 "text2vec-aws" => %{
                   "service" => "bedrock",
                   "model" => "amazon.titan-embed-text-v1",
                   "region" => "us-east-1",
                   "vectorizeClassName" => false
                 }
               }
             }
    end

    test "to_api/1 converts SageMaker config to API format" do
      config =
        Text2VecAWS.new(
          service: :sagemaker,
          endpoint: "my-endpoint",
          region: "us-west-2",
          target_model: "target",
          target_variant: "variant"
        )

      api_format = Text2VecAWS.to_api(config)

      assert api_format["vectorizer"] == "text2vec-aws"
      assert api_format["moduleConfig"]["text2vec-aws"]["service"] == "sagemaker"
      assert api_format["moduleConfig"]["text2vec-aws"]["endpoint"] == "my-endpoint"
      assert api_format["moduleConfig"]["text2vec-aws"]["region"] == "us-west-2"
      assert api_format["moduleConfig"]["text2vec-aws"]["targetModel"] == "target"
      assert api_format["moduleConfig"]["text2vec-aws"]["targetVariant"] == "variant"
    end

    test "from_api/1 parses Bedrock API response" do
      api_data = %{
        "vectorizer" => "text2vec-aws",
        "moduleConfig" => %{
          "text2vec-aws" => %{
            "service" => "bedrock",
            "model" => "amazon.titan-embed-text-v1",
            "region" => "us-east-1",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecAWS.from_api(api_data)

      assert %Text2VecAWS{} = config
      assert config.service == :bedrock
      assert config.model == "amazon.titan-embed-text-v1"
      assert config.region == "us-east-1"
      assert config.vectorize_collection_name == true
    end

    test "from_api/1 parses SageMaker API response" do
      api_data = %{
        "vectorizer" => "text2vec-aws",
        "moduleConfig" => %{
          "text2vec-aws" => %{
            "service" => "sagemaker",
            "endpoint" => "my-endpoint",
            "region" => "us-west-2",
            "targetModel" => "target",
            "targetVariant" => "variant"
          }
        }
      }

      config = Text2VecAWS.from_api(api_data)

      assert %Text2VecAWS{} = config
      assert config.service == :sagemaker
      assert config.endpoint == "my-endpoint"
      assert config.target_model == "target"
      assert config.target_variant == "variant"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecAWS.new(
          service: :bedrock,
          model: "cohere.embed-english-v3",
          region: "us-east-1",
          vectorize_collection_name: false
        )

      round_tripped =
        original
        |> Text2VecAWS.to_api()
        |> Text2VecAWS.from_api()

      assert round_tripped.service == original.service
      assert round_tripped.model == original.model
      assert round_tripped.region == original.region
      assert round_tripped.vectorize_collection_name == original.vectorize_collection_name
    end
  end

  describe "Text2VecGoogle" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecGoogle.vectorizer_name() == "text2vec-palm"
    end

    test "new/1 creates Vertex AI config" do
      config =
        Text2VecGoogle.new(
          service: :vertex,
          project_id: "my-project",
          model: "textembedding-gecko@001"
        )

      assert %Text2VecGoogle{} = config
      assert config.service == :vertex
      assert config.project_id == "my-project"
      assert config.model == "textembedding-gecko@001"
      assert config.vectorize_collection_name == true
    end

    test "new/1 creates Gemini config" do
      config =
        Text2VecGoogle.new(
          service: :gemini,
          model: "text-embedding-004",
          dimensions: 768
        )

      assert %Text2VecGoogle{} = config
      assert config.service == :gemini
      assert config.model == "text-embedding-004"
      assert config.dimensions == 768
      assert config.api_endpoint == "generativelanguage.googleapis.com"
    end

    test "to_api/1 converts Vertex AI config to API format" do
      config =
        Text2VecGoogle.new(
          service: :vertex,
          project_id: "my-project",
          model: "textembedding-gecko@001",
          api_endpoint: "us-central1-aiplatform.googleapis.com",
          dimensions: 768,
          title_property: "title",
          task_type: "RETRIEVAL_DOCUMENT"
        )

      api_format = Text2VecGoogle.to_api(config)

      assert api_format["vectorizer"] == "text2vec-palm"
      module_config = api_format["moduleConfig"]["text2vec-palm"]
      assert module_config["projectId"] == "my-project"
      assert module_config["modelId"] == "textembedding-gecko@001"
      assert module_config["apiEndpoint"] == "us-central1-aiplatform.googleapis.com"
      assert module_config["dimensions"] == 768
      assert module_config["titleProperty"] == "title"
      assert module_config["taskType"] == "RETRIEVAL_DOCUMENT"
    end

    test "to_api/1 converts Gemini config to API format" do
      config =
        Text2VecGoogle.new(
          service: :gemini,
          model: "text-embedding-004"
        )

      api_format = Text2VecGoogle.to_api(config)

      assert api_format["vectorizer"] == "text2vec-palm"
      module_config = api_format["moduleConfig"]["text2vec-palm"]
      assert module_config["apiEndpoint"] == "generativelanguage.googleapis.com"
      assert module_config["modelId"] == "text-embedding-004"
    end

    test "from_api/1 parses Vertex AI API response" do
      api_data = %{
        "vectorizer" => "text2vec-palm",
        "moduleConfig" => %{
          "text2vec-palm" => %{
            "projectId" => "my-project",
            "modelId" => "textembedding-gecko@001",
            "apiEndpoint" => "us-central1-aiplatform.googleapis.com",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecGoogle.from_api(api_data)

      assert %Text2VecGoogle{} = config
      assert config.service == :vertex
      assert config.project_id == "my-project"
      assert config.model == "textembedding-gecko@001"
    end

    test "from_api/1 parses Gemini API response" do
      api_data = %{
        "vectorizer" => "text2vec-palm",
        "moduleConfig" => %{
          "text2vec-palm" => %{
            "apiEndpoint" => "generativelanguage.googleapis.com",
            "modelId" => "text-embedding-004",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecGoogle.from_api(api_data)

      assert %Text2VecGoogle{} = config
      assert config.service == :gemini
      assert config.model == "text-embedding-004"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecGoogle.new(
          service: :vertex,
          project_id: "test-project",
          model: "textembedding-gecko@003",
          dimensions: 768,
          title_property: "title"
        )

      round_tripped =
        original
        |> Text2VecGoogle.to_api()
        |> Text2VecGoogle.from_api()

      assert round_tripped.service == original.service
      assert round_tripped.project_id == original.project_id
      assert round_tripped.model == original.model
      assert round_tripped.dimensions == original.dimensions
      assert round_tripped.title_property == original.title_property
    end
  end

  describe "Text2VecWeaviate" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecWeaviate.vectorizer_name() == "text2vec-weaviate"
    end

    test "new/0 creates default config" do
      config = Text2VecWeaviate.new()

      assert %Text2VecWeaviate{} = config
      assert config.vectorize_collection_name == true
      assert config.model == nil
      assert config.base_url == nil
    end

    test "new/1 creates config with options" do
      config =
        Text2VecWeaviate.new(
          model: "Snowflake/snowflake-arctic-embed-m-v1.5",
          base_url: "https://api.weaviate.io",
          vectorize_collection_name: false
        )

      assert %Text2VecWeaviate{} = config
      assert config.model == "Snowflake/snowflake-arctic-embed-m-v1.5"
      assert config.base_url == "https://api.weaviate.io"
      assert config.vectorize_collection_name == false
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecWeaviate.new(
          model: "Snowflake/snowflake-arctic-embed-m-v1.5",
          vectorize_collection_name: true
        )

      api_format = Text2VecWeaviate.to_api(config)

      assert api_format == %{
               "vectorizer" => "text2vec-weaviate",
               "moduleConfig" => %{
                 "text2vec-weaviate" => %{
                   "model" => "Snowflake/snowflake-arctic-embed-m-v1.5",
                   "vectorizeClassName" => true
                 }
               }
             }
    end

    test "to_api/1 omits nil values" do
      config = Text2VecWeaviate.new()
      api_format = Text2VecWeaviate.to_api(config)

      module_config = api_format["moduleConfig"]["text2vec-weaviate"]
      refute Map.has_key?(module_config, "model")
      refute Map.has_key?(module_config, "baseURL")
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-weaviate",
        "moduleConfig" => %{
          "text2vec-weaviate" => %{
            "model" => "Snowflake/snowflake-arctic-embed-m-v1.5",
            "baseURL" => "https://api.weaviate.io",
            "vectorizeClassName" => false
          }
        }
      }

      config = Text2VecWeaviate.from_api(api_data)

      assert %Text2VecWeaviate{} = config
      assert config.model == "Snowflake/snowflake-arctic-embed-m-v1.5"
      assert config.base_url == "https://api.weaviate.io"
      assert config.vectorize_collection_name == false
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecWeaviate.new(
          model: "test-model",
          base_url: "https://custom.url",
          vectorize_collection_name: false
        )

      round_tripped =
        original
        |> Text2VecWeaviate.to_api()
        |> Text2VecWeaviate.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.base_url == original.base_url
      assert round_tripped.vectorize_collection_name == original.vectorize_collection_name
    end
  end

  describe "Img2VecNeural" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Img2VecNeural.vectorizer_name() == "img2vec-neural"
    end

    test "new/0 creates default config" do
      config = Img2VecNeural.new()

      assert %Img2VecNeural{} = config
      assert config.image_fields == nil
    end

    test "new/1 creates config with image fields" do
      config = Img2VecNeural.new(image_fields: ["image", "thumbnail"])

      assert %Img2VecNeural{} = config
      assert config.image_fields == ["image", "thumbnail"]
    end

    test "to_api/1 converts to API format with image fields" do
      config = Img2VecNeural.new(image_fields: ["image", "thumbnail"])

      api_format = Img2VecNeural.to_api(config)

      assert api_format == %{
               "vectorizer" => "img2vec-neural",
               "moduleConfig" => %{
                 "img2vec-neural" => %{
                   "imageFields" => ["image", "thumbnail"]
                 }
               }
             }
    end

    test "to_api/1 omits nil image_fields" do
      config = Img2VecNeural.new()
      api_format = Img2VecNeural.to_api(config)

      module_config = api_format["moduleConfig"]["img2vec-neural"]
      refute Map.has_key?(module_config, "imageFields")
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "img2vec-neural",
        "moduleConfig" => %{
          "img2vec-neural" => %{
            "imageFields" => ["image", "thumbnail"]
          }
        }
      }

      config = Img2VecNeural.from_api(api_data)

      assert %Img2VecNeural{} = config
      assert config.image_fields == ["image", "thumbnail"]
    end

    test "from_api/1 handles empty module config" do
      api_data = %{
        "vectorizer" => "img2vec-neural",
        "moduleConfig" => %{
          "img2vec-neural" => %{}
        }
      }

      config = Img2VecNeural.from_api(api_data)

      assert %Img2VecNeural{} = config
      assert config.image_fields == nil
    end

    test "serialization round-trip preserves data" do
      original = Img2VecNeural.new(image_fields: ["photo", "avatar"])

      round_tripped =
        original
        |> Img2VecNeural.to_api()
        |> Img2VecNeural.from_api()

      assert round_tripped.image_fields == original.image_fields
    end
  end

  describe "edge cases" do
    test "Text2VecAWS handles string service values from API" do
      api_data = %{
        "vectorizer" => "text2vec-aws",
        "moduleConfig" => %{
          "text2vec-aws" => %{
            "service" => "bedrock",
            "model" => "test",
            "region" => "us-east-1"
          }
        }
      }

      config = Text2VecAWS.from_api(api_data)
      assert config.service == :bedrock
    end

    test "Text2VecGoogle infers Gemini service from api_endpoint" do
      api_data = %{
        "vectorizer" => "text2vec-palm",
        "moduleConfig" => %{
          "text2vec-palm" => %{
            "apiEndpoint" => "generativelanguage.googleapis.com"
          }
        }
      }

      config = Text2VecGoogle.from_api(api_data)
      assert config.service == :gemini
    end

    test "Text2VecGoogle infers Vertex service when project_id present" do
      api_data = %{
        "vectorizer" => "text2vec-palm",
        "moduleConfig" => %{
          "text2vec-palm" => %{
            "projectId" => "my-project"
          }
        }
      }

      config = Text2VecGoogle.from_api(api_data)
      assert config.service == :vertex
    end
  end

  describe "struct validation" do
    test "Text2VecAWS struct has correct fields" do
      config = %Text2VecAWS{}
      assert Map.has_key?(config, :service)
      assert Map.has_key?(config, :model)
      assert Map.has_key?(config, :region)
      assert Map.has_key?(config, :endpoint)
      assert Map.has_key?(config, :target_model)
      assert Map.has_key?(config, :target_variant)
      assert Map.has_key?(config, :vectorize_collection_name)
    end

    test "Text2VecGoogle struct has correct fields" do
      config = %Text2VecGoogle{}
      assert Map.has_key?(config, :service)
      assert Map.has_key?(config, :project_id)
      assert Map.has_key?(config, :api_endpoint)
      assert Map.has_key?(config, :model)
      assert Map.has_key?(config, :dimensions)
      assert Map.has_key?(config, :title_property)
      assert Map.has_key?(config, :task_type)
      assert Map.has_key?(config, :vectorize_collection_name)
    end

    test "Text2VecWeaviate struct has correct fields" do
      config = %Text2VecWeaviate{}
      assert Map.has_key?(config, :model)
      assert Map.has_key?(config, :base_url)
      assert Map.has_key?(config, :vectorize_collection_name)
    end

    test "Img2VecNeural struct has correct fields" do
      config = %Img2VecNeural{}
      assert Map.has_key?(config, :image_fields)
    end
  end
end
