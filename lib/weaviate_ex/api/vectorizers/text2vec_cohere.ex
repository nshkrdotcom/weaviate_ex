defmodule WeaviateEx.API.Vectorizers.Text2VecCohere do
  @moduledoc """
  Text2Vec-Cohere vectorizer configuration.

  Uses Cohere's embedding models for text vectorization.

  ## Example

      # Basic usage with model
      Text2VecCohere.new(model: "embed-english-v3.0")

      # With dimensions and truncation
      Text2VecCohere.new(
        model: "embed-multilingual-v3.0",
        dimensions: 512,
        truncate: :end
      )

      # Full configuration
      Text2VecCohere.new(
        model: "embed-english-v3.0",
        dimensions: 384,
        truncate: :end,
        base_url: "https://api.cohere.ai",
        vectorize_collection_name: false
      )
  """

  @type truncate_mode :: :none | :start | :end

  @type t :: %__MODULE__{
          model: String.t() | nil,
          dimensions: pos_integer() | nil,
          truncate: truncate_mode() | nil,
          base_url: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct model: nil,
            dimensions: nil,
            truncate: nil,
            base_url: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-cohere"

  @doc """
  Create a new Text2Vec-Cohere configuration.

  ## Options

  - `:model` - Cohere model name (e.g., "embed-english-v3.0", "embed-multilingual-v3.0")
  - `:dimensions` - Output dimensions
  - `:truncate` - Truncation mode: `:none`, `:start`, or `:end`
  - `:base_url` - Custom Cohere API endpoint
  - `:vectorize_collection_name` - Include collection name in vectorization (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      model: Keyword.get(opts, :model),
      dimensions: Keyword.get(opts, :dimensions),
      truncate: Keyword.get(opts, :truncate),
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
      |> maybe_put("model", config.model)
      |> maybe_put("dimensions", config.dimensions)
      |> maybe_put("truncate", truncate_to_string(config.truncate))
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
  def from_api(%{"moduleConfig" => %{"text2vec-cohere" => config}}) do
    %__MODULE__{
      model: Map.get(config, "model"),
      dimensions: Map.get(config, "dimensions"),
      truncate: parse_truncate(Map.get(config, "truncate")),
      base_url: Map.get(config, "baseURL"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp truncate_to_string(nil), do: nil
  defp truncate_to_string(:none), do: "NONE"
  defp truncate_to_string(:start), do: "START"
  defp truncate_to_string(:end), do: "END"

  defp parse_truncate(nil), do: nil
  defp parse_truncate("NONE"), do: :none
  defp parse_truncate("START"), do: :start
  defp parse_truncate("END"), do: :end
end
