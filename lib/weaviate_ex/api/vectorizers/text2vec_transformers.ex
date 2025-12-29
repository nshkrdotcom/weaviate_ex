defmodule WeaviateEx.API.Vectorizers.Text2VecTransformers do
  @moduledoc """
  Text2Vec-Transformers vectorizer configuration.

  Uses local transformer models for text embedding. This module requires
  a running transformers inference service.

  ## Example

      Text2VecTransformers.new(
        pooling_strategy: :masked_mean,
        inference_url: "http://localhost:8080"
      )

  ## Passage/Query Models

  For asymmetric search (different embeddings for queries vs documents):

      Text2VecTransformers.new(
        passage_inference_url: "http://localhost:8081",
        query_inference_url: "http://localhost:8082"
      )
  """

  @type pooling_strategy :: :masked_mean | :cls
  @type t :: %__MODULE__{
          pooling_strategy: pooling_strategy() | nil,
          inference_url: String.t() | nil,
          passage_inference_url: String.t() | nil,
          query_inference_url: String.t() | nil,
          vectorize_collection_name: boolean()
        }

  defstruct pooling_strategy: nil,
            inference_url: nil,
            passage_inference_url: nil,
            query_inference_url: nil,
            vectorize_collection_name: true

  @doc """
  Returns the vectorizer name for the API.
  """
  @spec vectorizer_name() :: String.t()
  def vectorizer_name, do: "text2vec-transformers"

  @doc """
  Create a new Text2Vec-Transformers configuration.

  ## Options

  - `:pooling_strategy` - Pooling strategy (:masked_mean, :cls)
  - `:inference_url` - URL of the transformers inference service
  - `:passage_inference_url` - URL for passage/document inference
  - `:query_inference_url` - URL for query inference
  - `:vectorize_collection_name` - Include collection name (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      pooling_strategy: Keyword.get(opts, :pooling_strategy),
      inference_url: Keyword.get(opts, :inference_url),
      passage_inference_url: Keyword.get(opts, :passage_inference_url),
      query_inference_url: Keyword.get(opts, :query_inference_url),
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
      |> maybe_put("poolingStrategy", pooling_to_string(config.pooling_strategy))
      |> maybe_put("inferenceUrl", config.inference_url)
      |> maybe_put("passageInferenceUrl", config.passage_inference_url)
      |> maybe_put("queryInferenceUrl", config.query_inference_url)

    %{
      "vectorizer" => vectorizer_name(),
      "moduleConfig" => %{vectorizer_name() => module_config}
    }
  end

  @doc """
  Parse configuration from API response.
  """
  @spec from_api(map()) :: t()
  def from_api(%{"moduleConfig" => %{"text2vec-transformers" => config}}) do
    %__MODULE__{
      pooling_strategy: parse_pooling(Map.get(config, "poolingStrategy")),
      inference_url: Map.get(config, "inferenceUrl"),
      passage_inference_url: Map.get(config, "passageInferenceUrl"),
      query_inference_url: Map.get(config, "queryInferenceUrl"),
      vectorize_collection_name: Map.get(config, "vectorizeClassName", true)
    }
  end

  defp pooling_to_string(nil), do: nil
  defp pooling_to_string(:masked_mean), do: "masked_mean"
  defp pooling_to_string(:cls), do: "cls"

  defp parse_pooling(nil), do: nil
  defp parse_pooling("masked_mean"), do: :masked_mean
  defp parse_pooling("cls"), do: :cls

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
