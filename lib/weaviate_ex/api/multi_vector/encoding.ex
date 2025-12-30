defmodule WeaviateEx.API.MultiVector.Encoding do
  @moduledoc """
  Multi-vector encoding configurations.

  Provides configuration builders for multi-vector encoding strategies,
  particularly for ColBERT-style multi-vector representations.

  ## Muvera Encoding

  Muvera is an efficient encoding scheme for multi-vector search that
  projects multiple vectors into a compressed representation.

  ## Example

      alias WeaviateEx.API.MultiVector.Encoding

      # Default Muvera encoding
      encoding = Encoding.muvera()

      # Custom Muvera parameters
      encoding = Encoding.muvera(
        ksim: 15,
        dprojections: 512,
        repetitions: 8
      )

      # Use in vector index config
      VectorConfig.hnsw_index(
        multi_vector: %{
          aggregation: :max_sim,
          encoding: encoding
        }
      )
  """

  @type encoding_type :: :muvera | :none

  @type t :: %__MODULE__{
          type: encoding_type(),
          ksim: non_neg_integer() | nil,
          dprojections: non_neg_integer() | nil,
          repetitions: non_neg_integer() | nil
        }

  defstruct [:type, :ksim, :dprojections, :repetitions]

  @doc """
  Create a Muvera encoding configuration.

  Muvera encoding is used for efficient multi-vector search, particularly
  with ColBERT-style token embeddings.

  ## Options

  - `:ksim` - Number of similar vectors to consider (default: 10)
  - `:dprojections` - Dimensionality of projections (default: 256)
  - `:repetitions` - Number of repetitions for hashing (default: 4)

  ## Examples

      # Default settings
      Encoding.muvera()
      # => %Encoding{type: :muvera, ksim: 10, dprojections: 256, repetitions: 4}

      # Custom settings
      Encoding.muvera(ksim: 15, dprojections: 512)
  """
  @spec muvera(keyword()) :: t()
  def muvera(opts \\ []) do
    %__MODULE__{
      type: :muvera,
      ksim: Keyword.get(opts, :ksim, 10),
      dprojections: Keyword.get(opts, :dprojections, 256),
      repetitions: Keyword.get(opts, :repetitions, 4)
    }
  end

  @doc """
  Create a no-encoding configuration (raw multi-vectors).

  Use this when you want to store multi-vectors without any encoding
  compression. This preserves full precision but uses more memory.

  ## Examples

      Encoding.none()
      # => %Encoding{type: :none}
  """
  @spec none() :: t()
  def none do
    %__MODULE__{type: :none}
  end

  @doc """
  Convert encoding configuration to API format.

  ## Examples

      encoding = Encoding.muvera(ksim: 15)
      Encoding.to_api(encoding)
      # => %{
      #   "type" => "muvera",
      #   "ksim" => 15,
      #   "dProjections" => 256,
      #   "repetitions" => 4
      # }
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{type: :muvera} = config) do
    %{
      "type" => "muvera",
      "ksim" => config.ksim,
      "dProjections" => config.dprojections,
      "repetitions" => config.repetitions
    }
  end

  def to_api(%__MODULE__{type: :none}) do
    %{"type" => "none"}
  end

  @doc """
  Parse encoding configuration from API response.

  ## Examples

      Encoding.from_api(%{"type" => "muvera", "ksim" => 10})
  """
  @spec from_api(map()) :: t()
  def from_api(%{"type" => "muvera"} = data) do
    %__MODULE__{
      type: :muvera,
      ksim: Map.get(data, "ksim"),
      dprojections: Map.get(data, "dProjections"),
      repetitions: Map.get(data, "repetitions")
    }
  end

  def from_api(%{"type" => "none"}) do
    %__MODULE__{type: :none}
  end

  def from_api(nil), do: nil
end
