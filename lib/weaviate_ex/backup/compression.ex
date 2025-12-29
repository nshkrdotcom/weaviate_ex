defmodule WeaviateEx.Backup.Compression do
  @moduledoc """
  Backup compression level options.

  ## Levels

  - `:default` - Balanced compression (default)
  - `:best_speed` - Faster compression, larger files
  - `:best_compression` - Slower compression, smaller files

  ## Examples

      iex> Compression.to_api(:best_speed)
      "BestSpeed"

      iex> Compression.from_api("BestCompression")
      {:ok, :best_compression}
  """

  @type t :: :default | :best_speed | :best_compression

  @levels [:default, :best_speed, :best_compression]

  @doc """
  List all available compression levels.

  ## Examples

      iex> Compression.all()
      [:default, :best_speed, :best_compression]
  """
  @spec all() :: [t()]
  def all, do: @levels

  @doc """
  Check if compression level is valid.

  ## Examples

      iex> Compression.valid?(:best_speed)
      true

      iex> Compression.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(level) when level in @levels, do: true
  def valid?(_), do: false

  @doc """
  Convert to API format.

  ## Examples

      iex> Compression.to_api(:default)
      "DefaultCompression"

      iex> Compression.to_api(:best_speed)
      "BestSpeed"
  """
  @spec to_api(t()) :: String.t()
  def to_api(:default), do: "DefaultCompression"
  def to_api(:best_speed), do: "BestSpeed"
  def to_api(:best_compression), do: "BestCompression"

  @doc """
  Parse from API response.

  ## Examples

      iex> Compression.from_api("BestSpeed")
      {:ok, :best_speed}

      iex> Compression.from_api("invalid")
      {:error, :invalid_compression}
  """
  @spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_compression}
  def from_api("DefaultCompression"), do: {:ok, :default}
  def from_api("BestSpeed"), do: {:ok, :best_speed}
  def from_api("BestCompression"), do: {:ok, :best_compression}
  def from_api(_), do: {:error, :invalid_compression}
end
