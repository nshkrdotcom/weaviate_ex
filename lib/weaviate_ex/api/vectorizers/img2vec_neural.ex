defmodule WeaviateEx.API.Vectorizers.Img2VecNeural do
  @moduledoc """
  Img2Vec-Neural vectorizer configuration.

  Uses neural networks to create vector embeddings from images.
  This module runs locally using ResNet-based models.

  ## Example

      Img2VecNeural.new(image_fields: ["image", "thumbnail"])
  """

  @type t :: %__MODULE__{
          image_fields: [String.t()] | nil
        }

  defstruct image_fields: nil

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "img2vec-neural"

  @doc """
  Create a new Img2Vec-Neural configuration.

  ## Options

  - `:image_fields` - List of property names containing image data
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      image_fields: Keyword.get(opts, :image_fields)
    }
  end

  @doc """
  Convert configuration to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    module_config =
      %{}
      |> maybe_put("imageFields", config.image_fields)

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
  def from_api(%{"moduleConfig" => %{"img2vec-neural" => config}}) do
    %__MODULE__{
      image_fields: Map.get(config, "imageFields")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
