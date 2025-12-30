defmodule WeaviateEx.API.Vectorizers.Text2VecOpenAI do
  @moduledoc """
  Text2Vec-OpenAI vectorizer configuration.

  Uses OpenAI's embedding models for text vectorization.

  ## Example

      # Basic usage with default model
      Text2VecOpenAI.new(model: "text-embedding-ada-002")

      # With dimensions (for text-embedding-3-* models)
      Text2VecOpenAI.new(
        model: "text-embedding-3-small",
        dimensions: 512
      )

      # Full configuration
      Text2VecOpenAI.new(
        model: "text-embedding-3-large",
        dimensions: 1024,
        base_url: "https://custom.openai.com",
        type: :text,
        vectorize_collection_name: false
      )
  """

  @type embedding_type :: :text | :code

  @type t :: %__MODULE__{
          model: String.t() | nil,
          dimensions: pos_integer() | nil,
          base_url: String.t() | nil,
          type: embedding_type() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct model: nil,
            dimensions: nil,
            base_url: nil,
            type: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-openai"

  @doc """
  Create a new Text2Vec-OpenAI configuration.

  ## Options

  - `:model` - OpenAI model name (e.g., "text-embedding-ada-002", "text-embedding-3-small")
  - `:dimensions` - Output dimensions (only for text-embedding-3-* models)
  - `:base_url` - Custom OpenAI API endpoint
  - `:type` - Embedding type, either `:text` or `:code`
  - `:vectorize_collection_name` - Include collection name in vectorization (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      model: Keyword.get(opts, :model),
      dimensions: Keyword.get(opts, :dimensions),
      base_url: Keyword.get(opts, :base_url),
      type: Keyword.get(opts, :type),
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
      |> maybe_put("baseURL", config.base_url)
      |> maybe_put("type", type_to_string(config.type))

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-openai" => config}}) do
    %__MODULE__{
      model: Map.get(config, "model"),
      dimensions: Map.get(config, "dimensions"),
      base_url: Map.get(config, "baseURL"),
      type: parse_type(Map.get(config, "type")),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp type_to_string(nil), do: nil
  defp type_to_string(:text), do: "text"
  defp type_to_string(:code), do: "code"

  defp parse_type(nil), do: nil
  defp parse_type("text"), do: :text
  defp parse_type("code"), do: :code
end
