defmodule WeaviateEx.API.Vectorizers.Text2VecPalm do
  @moduledoc """
  Text2Vec-Palm (Google Vertex AI) vectorizer configuration.

  Uses Google's PaLM/Vertex AI embedding models.

  ## Example

      Text2VecPalm.new(
        project_id: "my-gcp-project",
        model_id: "textembedding-gecko@001"
      )
  """

  @type t :: %__MODULE__{
          project_id: String.t() | nil,
          model_id: String.t() | nil,
          api_endpoint: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct project_id: nil,
            model_id: nil,
            api_endpoint: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-palm"

  @doc """
  Create a new Text2Vec-Palm configuration.

  ## Options

  - `:project_id` - Google Cloud project ID (required)
  - `:model_id` - Model ID (e.g., "textembedding-gecko@001")
  - `:api_endpoint` - Custom API endpoint
  - `:vectorize_collection_name` - Include collection name (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      project_id: Keyword.get(opts, :project_id),
      model_id: Keyword.get(opts, :model_id),
      api_endpoint: Keyword.get(opts, :api_endpoint),
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
      |> maybe_put("projectId", config.project_id)
      |> maybe_put("modelId", config.model_id)
      |> maybe_put("apiEndpoint", config.api_endpoint)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-palm" => config}}) do
    %__MODULE__{
      project_id: Map.get(config, "projectId"),
      model_id: Map.get(config, "modelId"),
      api_endpoint: Map.get(config, "apiEndpoint"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
