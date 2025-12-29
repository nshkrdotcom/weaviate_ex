defmodule WeaviateEx.API.Vectorizers.Text2VecWeaviate do
  @moduledoc """
  Text2Vec-Weaviate vectorizer configuration.

  Uses Weaviate-hosted embedding models for text vectorization.
  This is Weaviate's managed embedding service.

  ## Example

      Text2VecWeaviate.new(
        model: "Snowflake/snowflake-arctic-embed-m-v1.5"
      )
  """

  @type t :: %__MODULE__{
          model: String.t() | nil,
          base_url: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct model: nil,
            base_url: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-weaviate"

  @doc """
  Create a new Text2Vec-Weaviate configuration.

  ## Options

  - `:model` - Model name (e.g., "Snowflake/snowflake-arctic-embed-m-v1.5")
  - `:base_url` - Custom API base URL
  - `:vectorize_collection_name` - Include collection name (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      model: Keyword.get(opts, :model),
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
      %{
        "vectorizeClassName" => config.vectorize_collection_name
      }
      |> maybe_put("model", config.model)
      |> maybe_put("baseURL", config.base_url)

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
  def from_api(%{"moduleConfig" => %{"text2vec-weaviate" => config}}) do
    %__MODULE__{
      model: Map.get(config, "model"),
      base_url: Map.get(config, "baseURL"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
