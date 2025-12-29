defmodule WeaviateEx.API.Vectorizers.Text2VecGoogle do
  @moduledoc """
  Text2Vec-Google vectorizer configuration.

  Supports both Google Vertex AI and Google AI Studio (Gemini) services.

  ## Services

  - `:vertex` - Google Vertex AI (requires project_id)
  - `:gemini` - Google AI Studio (Gemini, uses generativelanguage.googleapis.com)

  ## Vertex AI Example

      Text2VecGoogle.new(
        service: :vertex,
        project_id: "my-project",
        model: "textembedding-gecko@001"
      )

  ## Gemini Example

      Text2VecGoogle.new(
        service: :gemini,
        model: "text-embedding-004"
      )
  """

  @gemini_endpoint "generativelanguage.googleapis.com"

  @type service :: :vertex | :gemini
  @type t :: %__MODULE__{
          service: service(),
          project_id: String.t() | nil,
          api_endpoint: String.t() | nil,
          model: String.t() | nil,
          dimensions: non_neg_integer() | nil,
          title_property: String.t() | nil,
          task_type: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct service: :vertex,
            project_id: nil,
            api_endpoint: nil,
            model: nil,
            dimensions: nil,
            title_property: nil,
            task_type: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-palm"

  @doc """
  Create a new Text2Vec-Google configuration.

  ## Options

  ### Common
  - `:service` - Service type: `:vertex` or `:gemini` (default: `:vertex`)
  - `:model` - Model ID
  - `:dimensions` - Output dimensions
  - `:title_property` - Property to use as title
  - `:task_type` - Task type for embeddings (e.g., "RETRIEVAL_DOCUMENT")
  - `:vectorize_collection_name` - Include collection name (default: true)

  ### Vertex AI specific
  - `:project_id` - Google Cloud project ID (required for Vertex)
  - `:api_endpoint` - API endpoint (optional, default varies by region)

  ### Gemini specific
  - For Gemini, `:api_endpoint` defaults to "generativelanguage.googleapis.com"
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    service = Keyword.get(opts, :service, :vertex)

    api_endpoint =
      case service do
        :gemini -> Keyword.get(opts, :api_endpoint, @gemini_endpoint)
        :vertex -> Keyword.get(opts, :api_endpoint)
      end

    %__MODULE__{
      service: service,
      project_id: Keyword.get(opts, :project_id),
      api_endpoint: api_endpoint,
      model: Keyword.get(opts, :model),
      dimensions: Keyword.get(opts, :dimensions),
      title_property: Keyword.get(opts, :title_property),
      task_type: Keyword.get(opts, :task_type),
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
        "vectorizeClassName" => config.vectorize_collection_name
      }
      |> maybe_put("projectId", config.project_id)
      |> maybe_put("apiEndpoint", config.api_endpoint)
      |> maybe_put("modelId", config.model)
      |> maybe_put("dimensions", config.dimensions)
      |> maybe_put("titleProperty", config.title_property)
      |> maybe_put("taskType", config.task_type)

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
  def from_api(%{"moduleConfig" => %{"text2vec-palm" => config}}) do
    service = infer_service(config)

    %__MODULE__{
      service: service,
      project_id: Map.get(config, "projectId"),
      api_endpoint: Map.get(config, "apiEndpoint"),
      model: Map.get(config, "modelId"),
      dimensions: Map.get(config, "dimensions"),
      title_property: Map.get(config, "titleProperty"),
      task_type: Map.get(config, "taskType"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  # Infer service type from API response
  defp infer_service(config) do
    cond do
      Map.get(config, "apiEndpoint") == @gemini_endpoint -> :gemini
      Map.has_key?(config, "projectId") -> :vertex
      true -> :vertex
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
