defmodule WeaviateEx.API.Vectorizers.Ref2VecCentroid do
  @moduledoc """
  Ref2Vec-Centroid vectorizer configuration.

  Calculates vectors based on the centroid of referenced objects' vectors.
  This is useful for creating aggregate vectors from cross-references.

  ## Example

      Ref2VecCentroid.new(
        reference_properties: ["hasArticles", "hasComments"],
        method: "mean"
      )
  """

  @type t :: %__MODULE__{
          reference_properties: [String.t()] | nil,
          method: String.t() | nil
        }

  defstruct reference_properties: nil,
            method: nil

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "ref2vec-centroid"

  @doc """
  Create a new Ref2Vec-Centroid configuration.

  ## Options

  - `:reference_properties` - List of cross-reference property names to include
  - `:method` - Centroid calculation method ("mean")
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      reference_properties: Keyword.get(opts, :reference_properties),
      method: Keyword.get(opts, :method)
    }
  end

  @doc """
  Convert configuration to API format.
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    module_config =
      %{}
      |> maybe_put("referenceProperties", config.reference_properties)
      |> maybe_put("method", config.method)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"ref2vec-centroid" => config}}) do
    %__MODULE__{
      reference_properties: Map.get(config, "referenceProperties"),
      method: Map.get(config, "method")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
