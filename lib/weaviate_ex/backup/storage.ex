defmodule WeaviateEx.Backup.Storage do
  @moduledoc """
  Backup storage backend types.

  ## Available Backends

  - `:filesystem` - Local filesystem storage
  - `:s3` - Amazon S3 or S3-compatible storage
  - `:gcs` - Google Cloud Storage
  - `:azure` - Azure Blob Storage

  ## Examples

      iex> Storage.valid?(:s3)
      true

      iex> Storage.to_api_path(:filesystem)
      "filesystem"

      iex> Storage.from_api("gcs")
      {:ok, :gcs}
  """

  @type t :: :filesystem | :s3 | :gcs | :azure

  @backends [:filesystem, :s3, :gcs, :azure]

  @doc """
  List all available storage backends.

  ## Examples

      iex> Storage.all()
      [:filesystem, :s3, :gcs, :azure]
  """
  @spec all() :: [t()]
  def all, do: @backends

  @doc """
  Check if backend is valid.

  ## Examples

      iex> Storage.valid?(:s3)
      true

      iex> Storage.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(backend) when backend in @backends, do: true
  def valid?(_), do: false

  @doc """
  Convert to API path segment.

  ## Examples

      iex> Storage.to_api_path(:filesystem)
      "filesystem"

      iex> Storage.to_api_path(:s3)
      "s3"
  """
  @spec to_api_path(t()) :: String.t()
  def to_api_path(:filesystem), do: "filesystem"
  def to_api_path(:s3), do: "s3"
  def to_api_path(:gcs), do: "gcs"
  def to_api_path(:azure), do: "azure"

  @doc """
  Parse from API response.

  ## Examples

      iex> Storage.from_api("s3")
      {:ok, :s3}

      iex> Storage.from_api("invalid")
      {:error, :invalid_backend}
  """
  @spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_backend}
  def from_api("filesystem"), do: {:ok, :filesystem}
  def from_api("s3"), do: {:ok, :s3}
  def from_api("gcs"), do: {:ok, :gcs}
  def from_api("azure"), do: {:ok, :azure}
  def from_api(_), do: {:error, :invalid_backend}
end
