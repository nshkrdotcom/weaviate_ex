defmodule WeaviateEx.API.VectorizersTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Vectorizers.{
    Img2VecNeural,
    Multi2VecClip,
    Multi2VecCohere,
    Multi2VecGoogle,
    Multi2VecVoyageAI,
    Ref2VecCentroid,
    Text2VecAWS,
    Text2VecAzureOpenAI,
    Text2VecGoogle,
    Text2VecJinaAI,
    Text2VecOllama,
    Text2VecPalm,
    Text2VecTransformers,
    Text2VecVoyageAI,
    Text2VecWeaviate
  }

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

  describe "Text2VecTransformers" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecTransformers.vectorizer_name() == "text2vec-transformers"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecTransformers.new(
          pooling_strategy: :cls,
          inference_url: "http://localhost:8080",
          passage_inference_url: "http://localhost:8081",
          query_inference_url: "http://localhost:8082"
        )

      assert %Text2VecTransformers{} = config
      assert config.pooling_strategy == :cls
      assert config.inference_url == "http://localhost:8080"
      assert config.passage_inference_url == "http://localhost:8081"
      assert config.query_inference_url == "http://localhost:8082"
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecTransformers.new(
          pooling_strategy: :masked_mean,
          inference_url: "http://localhost:8080",
          vectorize_collection_name: false
        )

      api_format = Text2VecTransformers.to_api(config)

      assert api_format["vectorizer"] == "text2vec-transformers"
      module_config = api_format["moduleConfig"]["text2vec-transformers"]
      assert module_config["poolingStrategy"] == "masked_mean"
      assert module_config["inferenceUrl"] == "http://localhost:8080"
      assert module_config["vectorizeClassName"] == false
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-transformers",
        "moduleConfig" => %{
          "text2vec-transformers" => %{
            "poolingStrategy" => "cls",
            "inferenceUrl" => "http://localhost:8080",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecTransformers.from_api(api_data)

      assert %Text2VecTransformers{} = config
      assert config.pooling_strategy == :cls
      assert config.inference_url == "http://localhost:8080"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecTransformers.new(
          pooling_strategy: :masked_mean,
          inference_url: "http://localhost:8080",
          vectorize_collection_name: false
        )

      round_tripped =
        original
        |> Text2VecTransformers.to_api()
        |> Text2VecTransformers.from_api()

      assert round_tripped.pooling_strategy == original.pooling_strategy
      assert round_tripped.inference_url == original.inference_url
      assert round_tripped.vectorize_collection_name == original.vectorize_collection_name
    end
  end

  describe "Text2VecOllama" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecOllama.vectorizer_name() == "text2vec-ollama"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecOllama.new(
          model: "nomic-embed-text",
          api_endpoint: "http://localhost:11434"
        )

      assert %Text2VecOllama{} = config
      assert config.model == "nomic-embed-text"
      assert config.api_endpoint == "http://localhost:11434"
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecOllama.new(
          model: "mxbai-embed-large",
          api_endpoint: "http://ollama:11434",
          vectorize_collection_name: true
        )

      api_format = Text2VecOllama.to_api(config)

      assert api_format["vectorizer"] == "text2vec-ollama"
      module_config = api_format["moduleConfig"]["text2vec-ollama"]
      assert module_config["model"] == "mxbai-embed-large"
      assert module_config["apiEndpoint"] == "http://ollama:11434"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-ollama",
        "moduleConfig" => %{
          "text2vec-ollama" => %{
            "model" => "nomic-embed-text",
            "apiEndpoint" => "http://localhost:11434",
            "vectorizeClassName" => true
          }
        }
      }

      config = Text2VecOllama.from_api(api_data)

      assert %Text2VecOllama{} = config
      assert config.model == "nomic-embed-text"
      assert config.api_endpoint == "http://localhost:11434"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecOllama.new(
          model: "nomic-embed-text",
          api_endpoint: "http://localhost:11434"
        )

      round_tripped =
        original
        |> Text2VecOllama.to_api()
        |> Text2VecOllama.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.api_endpoint == original.api_endpoint
    end
  end

  describe "Text2VecJinaAI" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecJinaAI.vectorizer_name() == "text2vec-jinaai"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecJinaAI.new(
          model: "jina-embeddings-v2-base-en",
          dimensions: 768
        )

      assert %Text2VecJinaAI{} = config
      assert config.model == "jina-embeddings-v2-base-en"
      assert config.dimensions == 768
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecJinaAI.new(
          model: "jina-embeddings-v3",
          dimensions: 1024,
          vectorize_collection_name: false
        )

      api_format = Text2VecJinaAI.to_api(config)

      assert api_format["vectorizer"] == "text2vec-jinaai"
      module_config = api_format["moduleConfig"]["text2vec-jinaai"]
      assert module_config["model"] == "jina-embeddings-v3"
      assert module_config["dimensions"] == 1024
      assert module_config["vectorizeClassName"] == false
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-jinaai",
        "moduleConfig" => %{
          "text2vec-jinaai" => %{
            "model" => "jina-embeddings-v2-base-en",
            "dimensions" => 768
          }
        }
      }

      config = Text2VecJinaAI.from_api(api_data)

      assert %Text2VecJinaAI{} = config
      assert config.model == "jina-embeddings-v2-base-en"
      assert config.dimensions == 768
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecJinaAI.new(
          model: "jina-embeddings-v3",
          dimensions: 1024
        )

      round_tripped =
        original
        |> Text2VecJinaAI.to_api()
        |> Text2VecJinaAI.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.dimensions == original.dimensions
    end
  end

  describe "Text2VecVoyageAI" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecVoyageAI.vectorizer_name() == "text2vec-voyageai"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecVoyageAI.new(
          model: "voyage-large-2",
          truncate: true
        )

      assert %Text2VecVoyageAI{} = config
      assert config.model == "voyage-large-2"
      assert config.truncate == true
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecVoyageAI.new(
          model: "voyage-3",
          truncate: false,
          vectorize_collection_name: true
        )

      api_format = Text2VecVoyageAI.to_api(config)

      assert api_format["vectorizer"] == "text2vec-voyageai"
      module_config = api_format["moduleConfig"]["text2vec-voyageai"]
      assert module_config["model"] == "voyage-3"
      assert module_config["truncate"] == false
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-voyageai",
        "moduleConfig" => %{
          "text2vec-voyageai" => %{
            "model" => "voyage-large-2",
            "truncate" => true
          }
        }
      }

      config = Text2VecVoyageAI.from_api(api_data)

      assert %Text2VecVoyageAI{} = config
      assert config.model == "voyage-large-2"
      assert config.truncate == true
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecVoyageAI.new(
          model: "voyage-3",
          truncate: true
        )

      round_tripped =
        original
        |> Text2VecVoyageAI.to_api()
        |> Text2VecVoyageAI.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.truncate == original.truncate
    end
  end

  describe "Text2VecPalm" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecPalm.vectorizer_name() == "text2vec-palm"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecPalm.new(
          project_id: "my-gcp-project",
          model_id: "textembedding-gecko@001"
        )

      assert %Text2VecPalm{} = config
      assert config.project_id == "my-gcp-project"
      assert config.model_id == "textembedding-gecko@001"
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecPalm.new(
          project_id: "my-project",
          model_id: "textembedding-gecko@003",
          api_endpoint: "us-central1-aiplatform.googleapis.com",
          vectorize_collection_name: false
        )

      api_format = Text2VecPalm.to_api(config)

      assert api_format["vectorizer"] == "text2vec-palm"
      module_config = api_format["moduleConfig"]["text2vec-palm"]
      assert module_config["projectId"] == "my-project"
      assert module_config["modelId"] == "textembedding-gecko@003"
      assert module_config["apiEndpoint"] == "us-central1-aiplatform.googleapis.com"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-palm",
        "moduleConfig" => %{
          "text2vec-palm" => %{
            "projectId" => "my-gcp-project",
            "modelId" => "textembedding-gecko@001"
          }
        }
      }

      config = Text2VecPalm.from_api(api_data)

      assert %Text2VecPalm{} = config
      assert config.project_id == "my-gcp-project"
      assert config.model_id == "textembedding-gecko@001"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecPalm.new(
          project_id: "test-project",
          model_id: "textembedding-gecko@003"
        )

      round_tripped =
        original
        |> Text2VecPalm.to_api()
        |> Text2VecPalm.from_api()

      assert round_tripped.project_id == original.project_id
      assert round_tripped.model_id == original.model_id
    end
  end

  describe "Text2VecAzureOpenAI" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Text2VecAzureOpenAI.vectorizer_name() == "text2vec-azure-openai"
    end

    test "new/1 creates config with options" do
      config =
        Text2VecAzureOpenAI.new(
          resource_name: "my-azure-resource",
          deployment_id: "my-embedding-deployment"
        )

      assert %Text2VecAzureOpenAI{} = config
      assert config.resource_name == "my-azure-resource"
      assert config.deployment_id == "my-embedding-deployment"
    end

    test "to_api/1 converts to API format" do
      config =
        Text2VecAzureOpenAI.new(
          resource_name: "my-resource",
          deployment_id: "text-embedding-ada-002",
          base_url: "https://custom.azure.com",
          vectorize_collection_name: false
        )

      api_format = Text2VecAzureOpenAI.to_api(config)

      assert api_format["vectorizer"] == "text2vec-azure-openai"
      module_config = api_format["moduleConfig"]["text2vec-azure-openai"]
      assert module_config["resourceName"] == "my-resource"
      assert module_config["deploymentId"] == "text-embedding-ada-002"
      assert module_config["baseURL"] == "https://custom.azure.com"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "text2vec-azure-openai",
        "moduleConfig" => %{
          "text2vec-azure-openai" => %{
            "resourceName" => "my-azure-resource",
            "deploymentId" => "my-embedding-deployment"
          }
        }
      }

      config = Text2VecAzureOpenAI.from_api(api_data)

      assert %Text2VecAzureOpenAI{} = config
      assert config.resource_name == "my-azure-resource"
      assert config.deployment_id == "my-embedding-deployment"
    end

    test "serialization round-trip preserves data" do
      original =
        Text2VecAzureOpenAI.new(
          resource_name: "test-resource",
          deployment_id: "test-deployment"
        )

      round_tripped =
        original
        |> Text2VecAzureOpenAI.to_api()
        |> Text2VecAzureOpenAI.from_api()

      assert round_tripped.resource_name == original.resource_name
      assert round_tripped.deployment_id == original.deployment_id
    end
  end

  describe "Multi2VecClip" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Multi2VecClip.vectorizer_name() == "multi2vec-clip"
    end

    test "new/1 creates config with options" do
      config =
        Multi2VecClip.new(
          image_fields: [%{name: "image", weight: 0.7}],
          text_fields: [%{name: "caption", weight: 0.3}],
          inference_url: "http://localhost:8080"
        )

      assert %Multi2VecClip{} = config
      assert length(config.image_fields) == 1
      assert length(config.text_fields) == 1
      assert config.inference_url == "http://localhost:8080"
    end

    test "new/1 normalizes string fields to maps" do
      config =
        Multi2VecClip.new(
          image_fields: ["image", "thumbnail"],
          text_fields: ["caption"]
        )

      assert [%{name: "image"}, %{name: "thumbnail"}] = config.image_fields
      assert [%{name: "caption"}] = config.text_fields
    end

    test "to_api/1 converts to API format" do
      config =
        Multi2VecClip.new(
          image_fields: [%{name: "image", weight: 0.7}],
          text_fields: [%{name: "caption", weight: 0.3}],
          vectorize_collection_name: false
        )

      api_format = Multi2VecClip.to_api(config)

      assert api_format["vectorizer"] == "multi2vec-clip"
      module_config = api_format["moduleConfig"]["multi2vec-clip"]
      assert [%{"name" => "image", "weight" => 0.7}] = module_config["imageFields"]
      assert [%{"name" => "caption", "weight" => 0.3}] = module_config["textFields"]
      assert module_config["vectorizeClassName"] == false
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "multi2vec-clip",
        "moduleConfig" => %{
          "multi2vec-clip" => %{
            "imageFields" => [%{"name" => "image", "weight" => 0.7}],
            "textFields" => [%{"name" => "caption", "weight" => 0.3}],
            "vectorizeClassName" => true
          }
        }
      }

      config = Multi2VecClip.from_api(api_data)

      assert %Multi2VecClip{} = config
      assert [%{name: "image", weight: 0.7}] = config.image_fields
      assert [%{name: "caption", weight: 0.3}] = config.text_fields
    end

    test "serialization round-trip preserves data" do
      original =
        Multi2VecClip.new(
          image_fields: [%{name: "image", weight: 0.7}],
          text_fields: [%{name: "caption", weight: 0.3}]
        )

      round_tripped =
        original
        |> Multi2VecClip.to_api()
        |> Multi2VecClip.from_api()

      assert length(round_tripped.image_fields) == length(original.image_fields)
      assert length(round_tripped.text_fields) == length(original.text_fields)
    end
  end

  describe "Multi2VecGoogle" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Multi2VecGoogle.vectorizer_name() == "multi2vec-google"
    end

    test "new/1 creates config with options" do
      config =
        Multi2VecGoogle.new(
          project_id: "my-gcp-project",
          location: "us-central1",
          model_id: "multimodalembedding@001",
          image_fields: [%{name: "image", weight: 0.5}],
          text_fields: [%{name: "description", weight: 0.5}]
        )

      assert %Multi2VecGoogle{} = config
      assert config.project_id == "my-gcp-project"
      assert config.location == "us-central1"
      assert config.model_id == "multimodalembedding@001"
    end

    test "new/1 supports video fields" do
      config =
        Multi2VecGoogle.new(
          project_id: "my-project",
          video_fields: [%{name: "video", weight: 0.4}],
          text_fields: [%{name: "caption", weight: 0.6}]
        )

      assert [%{name: "video", weight: 0.4}] = config.video_fields
    end

    test "to_api/1 converts to API format" do
      config =
        Multi2VecGoogle.new(
          project_id: "my-project",
          location: "us-central1",
          dimensions: 1408,
          image_fields: [%{name: "image"}],
          vectorize_collection_name: false
        )

      api_format = Multi2VecGoogle.to_api(config)

      assert api_format["vectorizer"] == "multi2vec-google"
      module_config = api_format["moduleConfig"]["multi2vec-google"]
      assert module_config["projectId"] == "my-project"
      assert module_config["location"] == "us-central1"
      assert module_config["dimensions"] == 1408
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "multi2vec-google",
        "moduleConfig" => %{
          "multi2vec-google" => %{
            "projectId" => "my-gcp-project",
            "location" => "us-central1",
            "imageFields" => [%{"name" => "image"}]
          }
        }
      }

      config = Multi2VecGoogle.from_api(api_data)

      assert %Multi2VecGoogle{} = config
      assert config.project_id == "my-gcp-project"
      assert config.location == "us-central1"
    end

    test "serialization round-trip preserves data" do
      original =
        Multi2VecGoogle.new(
          project_id: "test-project",
          location: "us-east1",
          dimensions: 768
        )

      round_tripped =
        original
        |> Multi2VecGoogle.to_api()
        |> Multi2VecGoogle.from_api()

      assert round_tripped.project_id == original.project_id
      assert round_tripped.location == original.location
      assert round_tripped.dimensions == original.dimensions
    end
  end

  describe "Multi2VecCohere" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Multi2VecCohere.vectorizer_name() == "multi2vec-cohere"
    end

    test "new/1 creates config with options" do
      config =
        Multi2VecCohere.new(
          model: "embed-english-v3.0",
          truncate: "END",
          image_fields: [%{name: "image", weight: 0.5}],
          text_fields: [%{name: "description", weight: 0.5}]
        )

      assert %Multi2VecCohere{} = config
      assert config.model == "embed-english-v3.0"
      assert config.truncate == "END"
    end

    test "to_api/1 converts to API format" do
      config =
        Multi2VecCohere.new(
          model: "embed-multilingual-v3.0",
          image_fields: [%{name: "photo"}],
          vectorize_collection_name: true
        )

      api_format = Multi2VecCohere.to_api(config)

      assert api_format["vectorizer"] == "multi2vec-cohere"
      module_config = api_format["moduleConfig"]["multi2vec-cohere"]
      assert module_config["model"] == "embed-multilingual-v3.0"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "multi2vec-cohere",
        "moduleConfig" => %{
          "multi2vec-cohere" => %{
            "model" => "embed-english-v3.0",
            "truncate" => "START",
            "imageFields" => [%{"name" => "image"}]
          }
        }
      }

      config = Multi2VecCohere.from_api(api_data)

      assert %Multi2VecCohere{} = config
      assert config.model == "embed-english-v3.0"
      assert config.truncate == "START"
    end

    test "serialization round-trip preserves data" do
      original =
        Multi2VecCohere.new(
          model: "embed-english-v3.0",
          truncate: "NONE"
        )

      round_tripped =
        original
        |> Multi2VecCohere.to_api()
        |> Multi2VecCohere.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.truncate == original.truncate
    end
  end

  describe "Multi2VecVoyageAI" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Multi2VecVoyageAI.vectorizer_name() == "multi2vec-voyageai"
    end

    test "new/1 creates config with options" do
      config =
        Multi2VecVoyageAI.new(
          model: "voyage-multimodal-3",
          truncate: true,
          image_fields: [%{name: "image", weight: 0.5}],
          text_fields: [%{name: "description", weight: 0.5}]
        )

      assert %Multi2VecVoyageAI{} = config
      assert config.model == "voyage-multimodal-3"
      assert config.truncate == true
    end

    test "to_api/1 converts to API format" do
      config =
        Multi2VecVoyageAI.new(
          model: "voyage-multimodal-3",
          image_fields: [%{name: "photo"}],
          vectorize_collection_name: false
        )

      api_format = Multi2VecVoyageAI.to_api(config)

      assert api_format["vectorizer"] == "multi2vec-voyageai"
      module_config = api_format["moduleConfig"]["multi2vec-voyageai"]
      assert module_config["model"] == "voyage-multimodal-3"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "multi2vec-voyageai",
        "moduleConfig" => %{
          "multi2vec-voyageai" => %{
            "model" => "voyage-multimodal-3",
            "truncate" => false,
            "imageFields" => [%{"name" => "image"}]
          }
        }
      }

      config = Multi2VecVoyageAI.from_api(api_data)

      assert %Multi2VecVoyageAI{} = config
      assert config.model == "voyage-multimodal-3"
      assert config.truncate == false
    end

    test "serialization round-trip preserves data" do
      original =
        Multi2VecVoyageAI.new(
          model: "voyage-multimodal-3",
          truncate: true
        )

      round_tripped =
        original
        |> Multi2VecVoyageAI.to_api()
        |> Multi2VecVoyageAI.from_api()

      assert round_tripped.model == original.model
      assert round_tripped.truncate == original.truncate
    end
  end

  describe "Ref2VecCentroid" do
    test "vectorizer_name/0 returns the vectorizer name" do
      assert Ref2VecCentroid.vectorizer_name() == "ref2vec-centroid"
    end

    test "new/1 creates config with options" do
      config =
        Ref2VecCentroid.new(
          reference_properties: ["hasArticles", "hasComments"],
          method: "mean"
        )

      assert %Ref2VecCentroid{} = config
      assert config.reference_properties == ["hasArticles", "hasComments"]
      assert config.method == "mean"
    end

    test "to_api/1 converts to API format" do
      config =
        Ref2VecCentroid.new(
          reference_properties: ["hasArticles"],
          method: "mean"
        )

      api_format = Ref2VecCentroid.to_api(config)

      assert api_format["vectorizer"] == "ref2vec-centroid"
      module_config = api_format["moduleConfig"]["ref2vec-centroid"]
      assert module_config["referenceProperties"] == ["hasArticles"]
      assert module_config["method"] == "mean"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "vectorizer" => "ref2vec-centroid",
        "moduleConfig" => %{
          "ref2vec-centroid" => %{
            "referenceProperties" => ["hasArticles", "hasComments"],
            "method" => "mean"
          }
        }
      }

      config = Ref2VecCentroid.from_api(api_data)

      assert %Ref2VecCentroid{} = config
      assert config.reference_properties == ["hasArticles", "hasComments"]
      assert config.method == "mean"
    end

    test "serialization round-trip preserves data" do
      original =
        Ref2VecCentroid.new(
          reference_properties: ["hasArticles"],
          method: "mean"
        )

      round_tripped =
        original
        |> Ref2VecCentroid.to_api()
        |> Ref2VecCentroid.from_api()

      assert round_tripped.reference_properties == original.reference_properties
      assert round_tripped.method == original.method
    end
  end
end
