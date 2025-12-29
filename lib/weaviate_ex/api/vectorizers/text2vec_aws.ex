defmodule WeaviateEx.API.Vectorizers.Text2VecAWS do
  @moduledoc """
  Text2Vec-AWS vectorizer configuration.

  Supports both AWS Bedrock and AWS SageMaker services for text embedding.

  ## Services

  - `:bedrock` - Use AWS Bedrock models (e.g., Titan, Cohere)
  - `:sagemaker` - Use custom SageMaker endpoints

  ## Bedrock Example

      Text2VecAWS.new(
        service: :bedrock,
        model: "amazon.titan-embed-text-v1",
        region: "us-east-1"
      )

  ## SageMaker Example

      Text2VecAWS.new(
        service: :sagemaker,
        endpoint: "my-endpoint",
        region: "us-west-2",
        target_model: "target",
        target_variant: "variant"
      )
  """

  @type service :: :bedrock | :sagemaker
  @type t :: %__MODULE__{
          service: service(),
          model: String.t() | nil,
          region: String.t() | nil,
          endpoint: String.t() | nil,
          target_model: String.t() | nil,
          target_variant: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct service: :bedrock,
            model: nil,
            region: nil,
            endpoint: nil,
            target_model: nil,
            target_variant: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-aws"

  @doc """
  Create a new Text2Vec-AWS configuration.

  ## Options

  ### Common
  - `:service` - Service type: `:bedrock` or `:sagemaker` (default: `:bedrock`)
  - `:region` - AWS region (required)
  - `:vectorize_collection_name` - Include collection name in vectorization (default: true)

  ### Bedrock-specific
  - `:model` - Model ID (e.g., "amazon.titan-embed-text-v1")

  ### SageMaker-specific
  - `:endpoint` - SageMaker endpoint name
  - `:target_model` - Target model for multi-model endpoints
  - `:target_variant` - Target variant for A/B testing
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      service: Keyword.get(opts, :service, :bedrock),
      model: Keyword.get(opts, :model),
      region: Keyword.get(opts, :region),
      endpoint: Keyword.get(opts, :endpoint),
      target_model: Keyword.get(opts, :target_model),
      target_variant: Keyword.get(opts, :target_variant),
      vectorize_collection_name: Keyword.get(opts, :vectorize_collection_name, true)
    }
  end

  @doc """
  Convert configuration to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    module_config =
      %{
        "service" => service_to_string(config.service),
        "vectorizeClassName" => config.vectorize_collection_name
      }
      |> maybe_put("model", config.model)
      |> maybe_put("region", config.region)
      |> maybe_put("endpoint", config.endpoint)
      |> maybe_put("targetModel", config.target_model)
      |> maybe_put("targetVariant", config.target_variant)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{
        vectorizer_name() => module_config
      }
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-aws" => config}}) do
    %__MODULE__{
      service: parse_service(Map.get(config, "service")),
      model: Map.get(config, "model"),
      region: Map.get(config, "region"),
      endpoint: Map.get(config, "endpoint"),
      target_model: Map.get(config, "targetModel"),
      target_variant: Map.get(config, "targetVariant"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp service_to_string(:bedrock), do: "bedrock"
  defp service_to_string(:sagemaker), do: "sagemaker"

  defp parse_service("bedrock"), do: :bedrock
  defp parse_service("sagemaker"), do: :sagemaker
  defp parse_service(nil), do: :bedrock

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
