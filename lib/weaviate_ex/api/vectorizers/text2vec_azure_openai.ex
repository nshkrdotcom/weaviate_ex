defmodule WeaviateEx.API.Vectorizers.Text2VecAzureOpenAI do
  @moduledoc """
  Text2Vec-Azure-OpenAI vectorizer configuration.

  Uses Azure OpenAI's embedding models for text vectorization.

  ## Example

      Text2VecAzureOpenAI.new(
        resource_name: "my-azure-resource",
        deployment_id: "my-embedding-deployment"
      )
  """

  @type t :: %__MODULE__{
          resource_name: String.t() | nil,
          deployment_id: String.t() | nil,
          base_url: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct resource_name: nil,
            deployment_id: nil,
            base_url: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-azure-openai"

  @doc """
  Create a new Text2Vec-Azure-OpenAI configuration.

  ## Options

  - `:resource_name` - Azure resource name (required)
  - `:deployment_id` - Azure deployment ID (required)
  - `:base_url` - Custom API endpoint
  - `:vectorize_collection_name` - Include collection name (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      resource_name: Keyword.get(opts, :resource_name),
      deployment_id: Keyword.get(opts, :deployment_id),
      base_url: Keyword.get(opts, :base_url),
      vectorize_collection_name: Keyword.get(opts, :vectorize_collection_name, true)
    }
  end

  @doc """
  Convert configuration to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    module_config =
      %{"vectorizeClassName" => config.vectorize_collection_name}
      |> maybe_put("resourceName", config.resource_name)
      |> maybe_put("deploymentId", config.deployment_id)
      |> maybe_put("baseURL", config.base_url)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-azure-openai" => config}}) do
    %__MODULE__{
      resource_name: Map.get(config, "resourceName"),
      deployment_id: Map.get(config, "deploymentId"),
      base_url: Map.get(config, "baseURL"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
