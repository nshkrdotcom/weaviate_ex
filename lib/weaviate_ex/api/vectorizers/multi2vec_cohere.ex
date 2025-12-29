defmodule WeaviateEx.API.Vectorizers.Multi2VecCohere do
  @moduledoc """
  Multi2Vec-Cohere vectorizer configuration.

  Uses Cohere's multimodal embedding models for image and text.

  ## Example

      Multi2VecCohere.new(
        model: "embed-english-v3.0",
        image_fields: [%{name: "image", weight: 0.5}],
        text_fields: [%{name: "description", weight: 0.5}]
      )
  """

  @type field_config :: %{
          required(:name) => String.t(),
          optional(:weight) => float()
        }

  @type t :: %__MODULE__{
          model: String.t() | nil,
          base_url: String.t() | nil,
          truncate: String.t() | nil,
          image_fields: [field_config()] | nil,
          text_fields: [field_config()] | nil,
          vectorize_collection_name: boolean()
        }

  defstruct model: nil,
            base_url: nil,
            truncate: nil,
            image_fields: nil,
            text_fields: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "multi2vec-cohere"

  @doc """
  Create a new Multi2Vec-Cohere configuration.

  ## Options

  - `:model` - Cohere model name (e.g., "embed-english-v3.0", "embed-multilingual-v3.0")
  - `:base_url` - Custom API endpoint
  - `:truncate` - Truncation strategy ("NONE", "START", "END")
  - `:image_fields` - List of image field configs with name and optional weight
  - `:text_fields` - List of text field configs with name and optional weight
  - `:vectorize_collection_name` - Include collection name (default: true)

  ## Field Config

  Fields can be specified as:
  - Simple strings: `["image", "caption"]`
  - Maps with weights: `[%{name: "image", weight: 0.7}]`
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url),
      truncate: Keyword.get(opts, :truncate),
      image_fields: normalize_fields(Keyword.get(opts, :image_fields)),
      text_fields: normalize_fields(Keyword.get(opts, :text_fields)),
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
      |> maybe_put("baseURL", config.base_url)
      |> maybe_put("truncate", config.truncate)
      |> maybe_put("imageFields", format_fields_to_api(config.image_fields))
      |> maybe_put("textFields", format_fields_to_api(config.text_fields))

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"multi2vec-cohere" => config}}) do
    %__MODULE__{
      model: Map.get(config, "model"),
      base_url: Map.get(config, "baseURL"),
      truncate: Map.get(config, "truncate"),
      image_fields: parse_fields_from_api(Map.get(config, "imageFields")),
      text_fields: parse_fields_from_api(Map.get(config, "textFields")),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp normalize_fields(nil), do: nil

  defp normalize_fields(fields) when is_list(fields) do
    Enum.map(fields, fn
      field when is_binary(field) -> %{name: field}
      %{name: _} = field -> field
      %{"name" => name} = field -> %{name: name, weight: field["weight"]}
    end)
  end

  defp format_fields_to_api(nil), do: nil

  defp format_fields_to_api(fields) do
    Enum.map(fields, fn field ->
      %{"name" => field.name}
      |> maybe_put("weight", Map.get(field, :weight))
    end)
  end

  defp parse_fields_from_api(nil), do: nil

  defp parse_fields_from_api(fields) do
    Enum.map(fields, fn field ->
      %{name: field["name"]}
      |> maybe_put_field(:weight, field["weight"])
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_field(map, _key, nil), do: map
  defp maybe_put_field(map, key, value), do: Map.put(map, key, value)
end
