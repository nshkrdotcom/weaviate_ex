defmodule WeaviateEx.API.Quantizer.PQConfig do
  @moduledoc """
  Product Quantization (PQ) configuration.

  PQ compresses vectors by dividing them into segments and quantizing each
  segment independently. This provides significant memory reduction while
  maintaining reasonable search accuracy.

  ## Fields

  - `:enabled` - Whether PQ is enabled (default: true)
  - `:training_limit` - Number of vectors to use for training the quantizer
  - `:segments` - Number of segments to divide vectors into (0 for auto)
  - `:centroids` - Number of centroids per segment (default: 256)
  - `:encoder` - Encoder configuration with type and distribution

  ## Encoder Types

  - `"kmeans"` - Standard k-means clustering (default)
  - `"tile"` - Tile encoder for specific distributions

  ## Encoder Distributions

  - `"log-normal"` - Log-normal distribution (default)
  - `"normal"` - Normal/Gaussian distribution
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          training_limit: non_neg_integer() | nil,
          segments: non_neg_integer() | nil,
          centroids: non_neg_integer() | nil,
          encoder: map() | nil
        }

  defstruct enabled: true,
            training_limit: nil,
            segments: nil,
            centroids: nil,
            encoder: nil

  @doc """
  Create a new PQ configuration.

  ## Options

  - `:enabled` - Enable PQ (default: true)
  - `:training_limit` - Number of vectors to train on
  - `:segments` - Number of segments (0 for auto)
  - `:centroids` - Number of centroids per segment
  - `:encoder` - Encoder configuration map

  ## Examples

      iex> PQConfig.new()
      %PQConfig{enabled: true}

      iex> PQConfig.new(segments: 128, centroids: 256)
      %PQConfig{enabled: true, segments: 128, centroids: 256}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, true),
      training_limit: Keyword.get(opts, :training_limit),
      segments: Keyword.get(opts, :segments),
      centroids: Keyword.get(opts, :centroids),
      encoder: Keyword.get(opts, :encoder)
    }
  end

  @doc """
  Convert a PQ configuration to API format.

  ## Examples

      iex> config = PQConfig.new(segments: 128)
      iex> PQConfig.to_api(config)
      %{"pq" => %{"enabled" => true, "segments" => 128}}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    pq_config =
      %{"enabled" => config.enabled}
      |> maybe_put("trainingLimit", config.training_limit)
      |> maybe_put("segments", config.segments)
      |> maybe_put("centroids", config.centroids)
      |> maybe_put_encoder(config.encoder)

    %{"pq" => pq_config}
  end

  @doc """
  Parse a PQ configuration from API response.

  ## Examples

      iex> PQConfig.from_api(%{"pq" => %{"enabled" => true, "segments" => 128}})
      %PQConfig{enabled: true, segments: 128}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"pq" => pq_data}) do
    %__MODULE__{
      enabled: Map.get(pq_data, "enabled", false),
      training_limit: Map.get(pq_data, "trainingLimit"),
      segments: Map.get(pq_data, "segments"),
      centroids: Map.get(pq_data, "centroids"),
      encoder: Map.get(pq_data, "encoder")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_encoder(map, nil), do: map

  defp maybe_put_encoder(map, encoder) when is_map(encoder) do
    api_encoder =
      encoder
      |> Enum.into(%{}, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)

    Map.put(map, "encoder", api_encoder)
  end
end

defmodule WeaviateEx.API.Quantizer.BQConfig do
  @moduledoc """
  Binary Quantization (BQ) configuration.

  BQ converts vectors to binary representations, providing the most aggressive
  compression and fastest search. However, it may result in some accuracy loss.

  ## Fields

  - `:enabled` - Whether BQ is enabled (default: true)
  - `:cache` - Enable vector cache for faster rescoring
  - `:rescore_limit` - Number of candidates to rescore with original vectors
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          cache: boolean() | nil,
          rescore_limit: non_neg_integer() | nil
        }

  defstruct enabled: true,
            cache: nil,
            rescore_limit: nil

  @doc """
  Create a new BQ configuration.

  ## Options

  - `:enabled` - Enable BQ (default: true)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore

  ## Examples

      iex> BQConfig.new()
      %BQConfig{enabled: true}

      iex> BQConfig.new(cache: true, rescore_limit: 200)
      %BQConfig{enabled: true, cache: true, rescore_limit: 200}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, true),
      cache: Keyword.get(opts, :cache),
      rescore_limit: Keyword.get(opts, :rescore_limit)
    }
  end

  @doc """
  Convert a BQ configuration to API format.

  ## Examples

      iex> config = BQConfig.new(cache: true)
      iex> BQConfig.to_api(config)
      %{"bq" => %{"enabled" => true, "cache" => true}}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    bq_config =
      %{"enabled" => config.enabled}
      |> maybe_put("cache", config.cache)
      |> maybe_put("rescoreLimit", config.rescore_limit)

    %{"bq" => bq_config}
  end

  @doc """
  Parse a BQ configuration from API response.

  ## Examples

      iex> BQConfig.from_api(%{"bq" => %{"enabled" => true, "cache" => true}})
      %BQConfig{enabled: true, cache: true}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"bq" => bq_data}) do
    %__MODULE__{
      enabled: Map.get(bq_data, "enabled", false),
      cache: Map.get(bq_data, "cache"),
      rescore_limit: Map.get(bq_data, "rescoreLimit")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule WeaviateEx.API.Quantizer.SQConfig do
  @moduledoc """
  Scalar Quantization (SQ) configuration.

  SQ quantizes each dimension independently, providing a good balance
  between compression ratio and search accuracy.

  ## Fields

  - `:enabled` - Whether SQ is enabled (default: true)
  - `:cache` - Enable vector cache for faster rescoring
  - `:rescore_limit` - Number of candidates to rescore with original vectors
  - `:training_limit` - Number of vectors to use for training
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          cache: boolean() | nil,
          rescore_limit: non_neg_integer() | nil,
          training_limit: non_neg_integer() | nil
        }

  defstruct enabled: true,
            cache: nil,
            rescore_limit: nil,
            training_limit: nil

  @doc """
  Create a new SQ configuration.

  ## Options

  - `:enabled` - Enable SQ (default: true)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore
  - `:training_limit` - Number of vectors to train on

  ## Examples

      iex> SQConfig.new()
      %SQConfig{enabled: true}

      iex> SQConfig.new(cache: true, training_limit: 50_000)
      %SQConfig{enabled: true, cache: true, training_limit: 50_000}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, true),
      cache: Keyword.get(opts, :cache),
      rescore_limit: Keyword.get(opts, :rescore_limit),
      training_limit: Keyword.get(opts, :training_limit)
    }
  end

  @doc """
  Convert an SQ configuration to API format.

  ## Examples

      iex> config = SQConfig.new(cache: true, training_limit: 50_000)
      iex> SQConfig.to_api(config)
      %{"sq" => %{"enabled" => true, "cache" => true, "trainingLimit" => 50_000}}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    sq_config =
      %{"enabled" => config.enabled}
      |> maybe_put("cache", config.cache)
      |> maybe_put("rescoreLimit", config.rescore_limit)
      |> maybe_put("trainingLimit", config.training_limit)

    %{"sq" => sq_config}
  end

  @doc """
  Parse an SQ configuration from API response.

  ## Examples

      iex> SQConfig.from_api(%{"sq" => %{"enabled" => true, "trainingLimit" => 50_000}})
      %SQConfig{enabled: true, training_limit: 50_000}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"sq" => sq_data}) do
    %__MODULE__{
      enabled: Map.get(sq_data, "enabled", false),
      cache: Map.get(sq_data, "cache"),
      rescore_limit: Map.get(sq_data, "rescoreLimit"),
      training_limit: Map.get(sq_data, "trainingLimit")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule WeaviateEx.API.Quantizer.RQConfig do
  @moduledoc """
  Rotational Quantization (RQ) configuration.

  RQ uses rotational transformations before quantization, which can provide
  better accuracy than other methods at similar compression ratios.

  ## Fields

  - `:enabled` - Whether RQ is enabled (default: true)
  - `:bits` - Number of bits for quantization (4, 8, or 16)
  - `:cache` - Enable vector cache for faster rescoring
  - `:rescore_limit` - Number of candidates to rescore with original vectors
  - `:training_limit` - Number of vectors to use for training
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          bits: non_neg_integer() | nil,
          cache: boolean() | nil,
          rescore_limit: non_neg_integer() | nil,
          training_limit: non_neg_integer() | nil
        }

  defstruct enabled: true,
            bits: nil,
            cache: nil,
            rescore_limit: nil,
            training_limit: nil

  @doc """
  Create a new RQ configuration.

  ## Options

  - `:enabled` - Enable RQ (default: true)
  - `:bits` - Number of bits (4, 8, or 16)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore
  - `:training_limit` - Number of vectors to train on

  ## Examples

      iex> RQConfig.new()
      %RQConfig{enabled: true}

      iex> RQConfig.new(bits: 8, cache: true)
      %RQConfig{enabled: true, bits: 8, cache: true}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, true),
      bits: Keyword.get(opts, :bits),
      cache: Keyword.get(opts, :cache),
      rescore_limit: Keyword.get(opts, :rescore_limit),
      training_limit: Keyword.get(opts, :training_limit)
    }
  end

  @doc """
  Convert an RQ configuration to API format.

  ## Examples

      iex> config = RQConfig.new(bits: 8, cache: true)
      iex> RQConfig.to_api(config)
      %{"rq" => %{"enabled" => true, "bits" => 8, "cache" => true}}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = config) do
    rq_config =
      %{"enabled" => config.enabled}
      |> maybe_put("bits", config.bits)
      |> maybe_put("cache", config.cache)
      |> maybe_put("rescoreLimit", config.rescore_limit)
      |> maybe_put("trainingLimit", config.training_limit)

    %{"rq" => rq_config}
  end

  @doc """
  Parse an RQ configuration from API response.

  ## Examples

      iex> RQConfig.from_api(%{"rq" => %{"enabled" => true, "bits" => 8}})
      %RQConfig{enabled: true, bits: 8}
  """
  @spec from_api(map()) :: t()
  def from_api(%{"rq" => rq_data}) do
    %__MODULE__{
      enabled: Map.get(rq_data, "enabled", false),
      bits: Map.get(rq_data, "bits"),
      cache: Map.get(rq_data, "cache"),
      rescore_limit: Map.get(rq_data, "rescoreLimit"),
      training_limit: Map.get(rq_data, "trainingLimit")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule WeaviateEx.API.Quantizer do
  @moduledoc """
  Quantizer configuration structs for vector index compression.

  Provides typed structs for configuring vector quantization methods:
  - `PQConfig` - Product Quantization
  - `BQConfig` - Binary Quantization
  - `SQConfig` - Scalar Quantization
  - `RQConfig` - Rotational Quantization

  Each struct provides `new/1`, `to_api/1`, and `from_api/1` functions
  for creating, serializing, and deserializing configurations.

  ## Usage

      # Create a PQ configuration
      pq = Quantizer.pq(segments: 128, centroids: 256)

      # Use with HNSW index
      VectorConfig.hnsw_index(quantizer: Quantizer.to_api(pq))

      # Parse from API response
      config = Quantizer.from_api(api_response)

  ## Quantization Methods

  - **Product Quantization (PQ)**: Compresses vectors by dividing them into segments
    and quantizing each segment independently. Good for memory reduction.

  - **Binary Quantization (BQ)**: Converts vectors to binary representations.
    Most aggressive compression, fastest search, some accuracy loss.

  - **Scalar Quantization (SQ)**: Quantizes each dimension independently.
    Good balance of compression and accuracy.

  - **Rotational Quantization (RQ)**: Uses rotational transformations before
    quantization. Advanced method with configurable bit depth.
  """

  alias WeaviateEx.API.Quantizer.{BQConfig, PQConfig, RQConfig, SQConfig}

  @type quantizer_config :: PQConfig.t() | BQConfig.t() | SQConfig.t() | RQConfig.t()
  @type quantizer_type :: :pq | :bq | :sq | :rq

  @doc """
  Detect the quantizer type from an API response map.

  Returns `:pq`, `:bq`, `:sq`, `:rq`, or `nil` if no quantizer is configured.

  ## Examples

      iex> Quantizer.detect_type(%{"pq" => %{"enabled" => true}})
      :pq

      iex> Quantizer.detect_type(%{})
      nil
  """
  @spec detect_type(map()) :: quantizer_type() | nil
  def detect_type(api_data) when is_map(api_data) do
    cond do
      Map.has_key?(api_data, "pq") -> :pq
      Map.has_key?(api_data, "bq") -> :bq
      Map.has_key?(api_data, "sq") -> :sq
      Map.has_key?(api_data, "rq") -> :rq
      true -> nil
    end
  end

  @doc """
  Parse a quantizer configuration from an API response.

  Automatically detects the quantizer type and returns the appropriate struct.
  Returns `nil` if no quantizer is configured.

  ## Examples

      iex> Quantizer.from_api(%{"pq" => %{"enabled" => true, "segments" => 128}})
      %PQConfig{enabled: true, segments: 128}

      iex> Quantizer.from_api(%{})
      nil
  """
  @spec from_api(map()) :: quantizer_config() | nil
  def from_api(api_data) when is_map(api_data) do
    case detect_type(api_data) do
      :pq -> PQConfig.from_api(api_data)
      :bq -> BQConfig.from_api(api_data)
      :sq -> SQConfig.from_api(api_data)
      :rq -> RQConfig.from_api(api_data)
      nil -> nil
    end
  end

  @doc """
  Convert a quantizer config struct to API format.

  Returns an empty map for `nil`.

  ## Examples

      iex> pq = PQConfig.new(segments: 128)
      iex> Quantizer.to_api(pq)
      %{"pq" => %{"enabled" => true, "segments" => 128}}

      iex> Quantizer.to_api(nil)
      %{}
  """
  @spec to_api(quantizer_config() | nil) :: map()
  def to_api(nil), do: %{}
  def to_api(%PQConfig{} = config), do: PQConfig.to_api(config)
  def to_api(%BQConfig{} = config), do: BQConfig.to_api(config)
  def to_api(%SQConfig{} = config), do: SQConfig.to_api(config)
  def to_api(%RQConfig{} = config), do: RQConfig.to_api(config)

  @doc """
  Create a Product Quantization configuration.

  Convenience alias for `PQConfig.new/1`.

  ## Options

  - `:enabled` - Enable PQ (default: true)
  - `:training_limit` - Number of vectors to train on
  - `:segments` - Number of segments (0 for auto)
  - `:centroids` - Number of centroids per segment (default: 256)
  - `:encoder` - Encoder configuration map with `:type` and `:distribution`

  ## Examples

      iex> Quantizer.pq(segments: 128, centroids: 256)
      %PQConfig{enabled: true, segments: 128, centroids: 256}
  """
  @spec pq(keyword()) :: PQConfig.t()
  def pq(opts \\ []), do: PQConfig.new(opts)

  @doc """
  Create a Binary Quantization configuration.

  Convenience alias for `BQConfig.new/1`.

  ## Options

  - `:enabled` - Enable BQ (default: true)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore

  ## Examples

      iex> Quantizer.bq(cache: true)
      %BQConfig{enabled: true, cache: true}
  """
  @spec bq(keyword()) :: BQConfig.t()
  def bq(opts \\ []), do: BQConfig.new(opts)

  @doc """
  Create a Scalar Quantization configuration.

  Convenience alias for `SQConfig.new/1`.

  ## Options

  - `:enabled` - Enable SQ (default: true)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore
  - `:training_limit` - Number of vectors to train on

  ## Examples

      iex> Quantizer.sq(training_limit: 50_000)
      %SQConfig{enabled: true, training_limit: 50_000}
  """
  @spec sq(keyword()) :: SQConfig.t()
  def sq(opts \\ []), do: SQConfig.new(opts)

  @doc """
  Create a Rotational Quantization configuration.

  Convenience alias for `RQConfig.new/1`.

  ## Options

  - `:enabled` - Enable RQ (default: true)
  - `:bits` - Number of bits for quantization (4, 8, or 16)
  - `:cache` - Enable vector cache
  - `:rescore_limit` - Number of candidates to rescore
  - `:training_limit` - Number of vectors to train on

  ## Examples

      iex> Quantizer.rq(bits: 8, cache: true)
      %RQConfig{enabled: true, bits: 8, cache: true}
  """
  @spec rq(keyword()) :: RQConfig.t()
  def rq(opts \\ []), do: RQConfig.new(opts)
end
