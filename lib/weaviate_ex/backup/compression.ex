defmodule WeaviateEx.Backup.Compression do
  @moduledoc """
  Backup compression level options.

  ## GZIP Compression Levels

  - `:default` - Balanced GZIP compression (default)
  - `:best_speed` - Faster GZIP compression, larger files
  - `:best_compression` - Slower GZIP compression, smaller files

  ## ZSTD Compression Levels

  - `:zstd_default` - Balanced ZSTD compression
  - `:zstd_best_speed` - Faster ZSTD compression, larger files
  - `:zstd_best_compression` - Slower ZSTD compression, smaller files

  ## No Compression

  - `:no_compression` - No compression (fastest, largest files)

  ## Examples

      iex> Compression.to_api(:best_speed)
      "BestSpeed"

      iex> Compression.to_api(:zstd_default)
      "ZstdDefaultCompression"

      iex> Compression.from_api("BestCompression")
      {:ok, :best_compression}

      iex> Compression.gzip?(:default)
      true

      iex> Compression.zstd?(:zstd_best_speed)
      true
  """

  @type t ::
          :default
          | :best_speed
          | :best_compression
          | :zstd_default
          | :zstd_best_speed
          | :zstd_best_compression
          | :no_compression

  @gzip_levels [:default, :best_speed, :best_compression]
  @zstd_levels [:zstd_default, :zstd_best_speed, :zstd_best_compression]
  @levels @gzip_levels ++ @zstd_levels ++ [:no_compression]

  @doc """
  List all available compression levels.

  ## Examples

      iex> Compression.all()
      [:default, :best_speed, :best_compression, :zstd_default, :zstd_best_speed, :zstd_best_compression, :no_compression]
  """
  @spec all() :: [t()]
  def all, do: @levels

  @doc """
  Check if compression level is valid.

  ## Examples

      iex> Compression.valid?(:best_speed)
      true

      iex> Compression.valid?(:zstd_default)
      true

      iex> Compression.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(level) when level in @levels, do: true
  def valid?(_), do: false

  @doc """
  Check if compression level is a GZIP variant.

  ## Examples

      iex> Compression.gzip?(:default)
      true

      iex> Compression.gzip?(:zstd_default)
      false
  """
  @spec gzip?(atom()) :: boolean()
  def gzip?(level) when level in @gzip_levels, do: true
  def gzip?(_), do: false

  @doc """
  Check if compression level is a ZSTD variant.

  ## Examples

      iex> Compression.zstd?(:zstd_default)
      true

      iex> Compression.zstd?(:default)
      false
  """
  @spec zstd?(atom()) :: boolean()
  def zstd?(level) when level in @zstd_levels, do: true
  def zstd?(_), do: false

  @doc """
  Convert to API format.

  ## Examples

      iex> Compression.to_api(:default)
      "DefaultCompression"

      iex> Compression.to_api(:best_speed)
      "BestSpeed"

      iex> Compression.to_api(:zstd_default)
      "ZstdDefaultCompression"

      iex> Compression.to_api(:no_compression)
      "NoCompression"
  """
  @spec to_api(t()) :: String.t()
  # GZIP variants
  def to_api(:default), do: "DefaultCompression"
  def to_api(:best_speed), do: "BestSpeed"
  def to_api(:best_compression), do: "BestCompression"
  # ZSTD variants
  def to_api(:zstd_default), do: "ZstdDefaultCompression"
  def to_api(:zstd_best_speed), do: "ZstdBestSpeed"
  def to_api(:zstd_best_compression), do: "ZstdBestCompression"
  # No compression
  def to_api(:no_compression), do: "NoCompression"

  @doc """
  Parse from API response.

  ## Examples

      iex> Compression.from_api("BestSpeed")
      {:ok, :best_speed}

      iex> Compression.from_api("ZstdDefaultCompression")
      {:ok, :zstd_default}

      iex> Compression.from_api("invalid")
      {:error, :invalid_compression}
  """
  @spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_compression}
  # GZIP variants
  def from_api("DefaultCompression"), do: {:ok, :default}
  def from_api("BestSpeed"), do: {:ok, :best_speed}
  def from_api("BestCompression"), do: {:ok, :best_compression}
  # ZSTD variants
  def from_api("ZstdDefaultCompression"), do: {:ok, :zstd_default}
  def from_api("ZstdBestSpeed"), do: {:ok, :zstd_best_speed}
  def from_api("ZstdBestCompression"), do: {:ok, :zstd_best_compression}
  # No compression
  def from_api("NoCompression"), do: {:ok, :no_compression}
  # Invalid
  def from_api(_), do: {:error, :invalid_compression}
end
