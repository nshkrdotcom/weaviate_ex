defmodule WeaviateEx.API.Vectorizers.Multi2VecGoogle do
  @moduledoc """
  Multi2Vec-Google (Vertex AI) vectorizer configuration.

  Uses Google's multimodal embedding models for image, text, and video.

  ## Example

      Multi2VecGoogle.new(
        project_id: "my-gcp-project",
        location: "us-central1",
        image_fields: [%{name: "image", weight: 0.5}],
        text_fields: [%{name: "description", weight: 0.5}]
      )
  """

  @type field_config :: %{
          required(:name) => String.t(),
          optional(:weight) => float()
        }

  @type t :: %__MODULE__{
          project_id: String.t() | nil,
          location: String.t() | nil,
          model_id: String.t() | nil,
          dimensions: pos_integer() | nil,
          image_fields: [field_config()] | nil,
          text_fields: [field_config()] | nil,
          video_fields: [field_config()] | nil,
          vectorize_collection_name: boolean()
        }

  defstruct project_id: nil,
            location: nil,
            model_id: nil,
            dimensions: nil,
            image_fields: nil,
            text_fields: nil,
            video_fields: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "multi2vec-google"

  @doc """
  Create a new Multi2Vec-Google configuration.

  ## Options

  - `:project_id` - Google Cloud project ID (required)
  - `:location` - Google Cloud location (e.g., "us-central1")
  - `:model_id` - Model ID (e.g., "multimodalembedding@001")
  - `:dimensions` - Output dimensions
  - `:image_fields` - List of image field configs with name and optional weight
  - `:text_fields` - List of text field configs with name and optional weight
  - `:video_fields` - List of video field configs with name and optional weight
  - `:vectorize_collection_name` - Include collection name (default: true)

  ## Field Config

  Fields can be specified as:
  - Simple strings: `["image", "caption"]`
  - Maps with weights: `[%{name: "image", weight: 0.7}]`
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      project_id: Keyword.get(opts, :project_id),
      location: Keyword.get(opts, :location),
      model_id: Keyword.get(opts, :model_id),
      dimensions: Keyword.get(opts, :dimensions),
      image_fields: normalize_fields(Keyword.get(opts, :image_fields)),
      text_fields: normalize_fields(Keyword.get(opts, :text_fields)),
      video_fields: normalize_fields(Keyword.get(opts, :video_fields)),
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
      |> maybe_put("location", config.location)
      |> maybe_put("modelId", config.model_id)
      |> maybe_put("dimensions", config.dimensions)
      |> maybe_put("imageFields", format_fields_to_api(config.image_fields))
      |> maybe_put("textFields", format_fields_to_api(config.text_fields))
      |> maybe_put("videoFields", format_fields_to_api(config.video_fields))

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"multi2vec-google" => config}}) do
    %__MODULE__{
      project_id: Map.get(config, "projectId"),
      location: Map.get(config, "location"),
      model_id: Map.get(config, "modelId"),
      dimensions: Map.get(config, "dimensions"),
      image_fields: parse_fields_from_api(Map.get(config, "imageFields")),
      text_fields: parse_fields_from_api(Map.get(config, "textFields")),
      video_fields: parse_fields_from_api(Map.get(config, "videoFields")),
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
