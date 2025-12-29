defmodule WeaviateEx.API.Vectorizers.Text2VecOllama do
  @moduledoc """
  Text2Vec-Ollama vectorizer configuration.

  Uses Ollama for local text embedding. Requires a running Ollama instance.

  ## Example

      Text2VecOllama.new(
        api_endpoint: "http://localhost:11434",
        model: "llama2"
      )
  """

  @type t :: %__MODULE__{
          api_endpoint: String.t() | nil,
          model: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct api_endpoint: nil,
            model: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-ollama"

  @doc """
  Create a new Text2Vec-Ollama configuration.

  ## Options

  - `:api_endpoint` - Ollama API endpoint (default: http://localhost:11434)
  - `:model` - Ollama model name (e.g., "llama2", "mistral")
  - `:vectorize_collection_name` - Include collection name (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      api_endpoint: Keyword.get(opts, :api_endpoint),
      model: Keyword.get(opts, :model),
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
      |> maybe_put("apiEndpoint", config.api_endpoint)
      |> maybe_put("model", config.model)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-ollama" => config}}) do
    %__MODULE__{
      api_endpoint: Map.get(config, "apiEndpoint"),
      model: Map.get(config, "model"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
