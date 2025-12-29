defmodule WeaviateEx.API.MultiVector do
  @moduledoc """
  Multi-vector configuration for ColBERT-style embeddings.

  Multi-vectors allow storing multiple vectors per document,
  enabling late interaction retrieval methods like MaxSim.

  ## Examples

      # Self-provided multi-vectors
      MultiVector.self_provided(
        name: "custom_multivec",
        encoding: MultiVector.muvera_encoding(ksim: 64)
      )

      # text2colbert-jinaai for ColBERT embeddings
      MultiVector.text2colbert_jinaai(
        name: "colbert_vector",
        model: "jina-colbert-v2",
        source_properties: ["title", "content"],
        encoding: MultiVector.muvera_encoding(ksim: 64, dprojections: 128),
        multi_vector_config: MultiVector.multi_vector_config(aggregation: :max_sim)
      )
  """

  @type aggregation :: :max_sim

  @doc """
  Configure Muvera encoding for multi-vectors.

  Muvera is an encoding scheme optimized for multi-vector representations.

  ## Options

    - `:ksim` - Number of similar vectors to consider
    - `:dprojections` - Dimension of projections
    - `:repetitions` - Number of repetitions

  ## Examples

      MultiVector.muvera_encoding()
      MultiVector.muvera_encoding(ksim: 64, dprojections: 128)
  """
  @spec muvera_encoding(keyword()) :: map()
  def muvera_encoding(opts \\ []) do
    config =
      %{"enabled" => true}
      |> maybe_put("ksim", Keyword.get(opts, :ksim))
      |> maybe_put("dprojections", Keyword.get(opts, :dprojections))
      |> maybe_put("repetitions", Keyword.get(opts, :repetitions))

    %{"muvera" => config}
  end

  @doc """
  Configure multi-vector aggregation.

  ## Options

    - `:aggregation` - Aggregation method (:max_sim for MaxSim)

  ## Examples

      MultiVector.multi_vector_config(aggregation: :max_sim)
  """
  @spec multi_vector_config(keyword()) :: map()
  def multi_vector_config(opts \\ []) do
    aggregation =
      case Keyword.get(opts, :aggregation) do
        :max_sim -> "maxSim"
        nil -> nil
        agg when is_binary(agg) -> agg
      end

    %{}
    |> maybe_put("aggregation", aggregation)
  end

  @doc """
  Create a self-provided multi-vector configuration.

  Use this when you want to provide your own multi-vector embeddings
  rather than using automatic vectorization.

  ## Options

    - `:name` - Vector name (required)
    - `:encoding` - Encoding configuration (e.g., from `muvera_encoding/1`)
    - `:multi_vector_config` - Multi-vector config (e.g., from `multi_vector_config/1`)
    - `:hnsw_opts` - HNSW index options

  ## Examples

      MultiVector.self_provided(
        name: "custom_multivec",
        encoding: MultiVector.muvera_encoding(ksim: 64)
      )
  """
  @spec self_provided(keyword()) :: map()
  def self_provided(opts) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"none" => %{}},
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => build_multi_vector_index_config(opts)
    }
  end

  @doc """
  Create a text2colbert-jinaai multi-vector configuration.

  ColBERT (Contextualized Late Interaction over BERT) produces
  multiple token-level embeddings for each document.

  ## Options

    - `:name` - Vector name (required)
    - `:model` - Jina ColBERT model (e.g., "jina-colbert-v2")
    - `:dimensions` - Output dimensions
    - `:source_properties` - Properties to vectorize
    - `:vectorize_collection_name` - Whether to vectorize collection name
    - `:encoding` - Encoding configuration (e.g., from `muvera_encoding/1`)
    - `:multi_vector_config` - Multi-vector config (e.g., from `multi_vector_config/1`)
    - `:hnsw_opts` - HNSW index options

  ## Examples

      MultiVector.text2colbert_jinaai(
        name: "colbert_vector",
        model: "jina-colbert-v2",
        source_properties: ["title", "content"],
        encoding: MultiVector.muvera_encoding(ksim: 64, dprojections: 128)
      )
  """
  @spec text2colbert_jinaai(keyword()) :: map()
  def text2colbert_jinaai(opts) do
    vectorizer_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    base = %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"text2colbert-jinaai" => vectorizer_config},
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => build_multi_vector_index_config(opts)
    }

    maybe_add_source_properties(base, opts)
  end

  @doc """
  Create a multi2multivec-jinaai configuration for multimodal multi-vectors.

  Supports image and text fields for multimodal embeddings.

  ## Options

    - `:name` - Vector name (required)
    - `:model` - Jina model (e.g., "jina-clip-v2")
    - `:dimensions` - Output dimensions
    - `:image_fields` - Image property fields
    - `:text_fields` - Text property fields
    - `:vectorize_collection_name` - Whether to vectorize collection name
    - `:encoding` - Encoding configuration
    - `:multi_vector_config` - Multi-vector config

  ## Examples

      MultiVector.multi2multivec_jinaai(
        name: "multivec",
        model: "jina-clip-v2",
        image_fields: ["image"],
        text_fields: ["caption"]
      )
  """
  @spec multi2multivec_jinaai(keyword()) :: map()
  def multi2multivec_jinaai(opts) do
    vectorizer_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
      |> maybe_put("imageFields", format_multi_fields(Keyword.get(opts, :image_fields)))
      |> maybe_put("textFields", format_multi_fields(Keyword.get(opts, :text_fields)))

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"multi2multivec-jinaai" => vectorizer_config},
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => build_multi_vector_index_config(opts)
    }
  end

  # Private helpers

  defp build_multi_vector_index_config(opts) do
    # Start with base HNSW config
    base_config = %{}

    # Build the multivector section
    multivector_config = build_multivector_section(opts)

    Map.put(base_config, "multivector", multivector_config)
  end

  defp build_multivector_section(opts) do
    mv_config = Keyword.get(opts, :multi_vector_config, %{})
    encoding = Keyword.get(opts, :encoding)

    config =
      %{"enabled" => true}
      |> Map.merge(mv_config)

    case encoding do
      nil -> config
      enc when is_map(enc) -> Map.merge(config, enc)
    end
  end

  defp format_multi_fields(nil), do: nil

  defp format_multi_fields(fields) when is_list(fields) do
    Enum.map(fields, fn
      field when is_binary(field) -> %{"name" => field}
      %{name: name} = field -> %{"name" => name} |> maybe_put("weight", field[:weight])
      field when is_map(field) -> field
    end)
  end

  defp maybe_add_source_properties(config, opts) do
    case Keyword.get(opts, :source_properties) do
      nil ->
        config

      props ->
        vectorizer_key = config["vectorizer"] |> Map.keys() |> List.first()
        put_in(config, ["vectorizer", vectorizer_key, "properties"], props)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
