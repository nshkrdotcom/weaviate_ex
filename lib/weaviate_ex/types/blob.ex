defmodule WeaviateEx.Types.Blob do
  @moduledoc """
  Binary/Blob data handling for Weaviate.

  Weaviate stores blobs as base64-encoded strings.
  This module provides a struct for blob data and utilities for encoding/decoding.

  ## Struct Usage

  The `Blob` struct wraps binary data for automatic serialization:

      # Create from binary data
      blob = Blob.new(<<binary_data>>)

      # Use in object properties - automatically serialized to base64
      WeaviateEx.Objects.create("MyCollection", %{
        properties: %{image: blob}
      })

  ## Utility Functions

      # Encode binary data directly
      encoded = Blob.encode(<<binary_data>>)

      # Encode file
      {:ok, encoded} = Blob.encode_file("/path/to/image.jpg")

      # Decode
      {:ok, binary} = Blob.decode(encoded)

      # Decode to file
      :ok = Blob.decode_to_file(encoded, "/path/to/output.jpg")
  """

  @type t :: %__MODULE__{
          data: binary() | nil
        }

  defstruct [:data]

  @doc """
  Create a new Blob from binary data.

  ## Examples

      iex> blob = Blob.new("Hello, World!")
      %Blob{data: "Hello, World!"}

      iex> blob = Blob.new(<<1, 2, 3, 4, 5>>)
      %Blob{data: <<1, 2, 3, 4, 5>>}
  """
  @spec new(binary()) :: t()
  def new(data) when is_binary(data) do
    %__MODULE__{data: data}
  end

  @doc """
  Create a Blob from a file.

  ## Examples

      {:ok, blob} = Blob.from_file("/path/to/image.jpg")
  """
  @spec from_file(Path.t()) :: {:ok, t()} | {:error, File.posix()}
  def from_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, %__MODULE__{data: data}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a Blob from a file, raising on error.

  ## Examples

      blob = Blob.from_file!("/path/to/image.jpg")
  """
  @spec from_file!(Path.t()) :: t()
  def from_file!(path) do
    %__MODULE__{data: File.read!(path)}
  end

  @doc """
  Convert Blob to base64-encoded string for Weaviate API.

  ## Examples

      iex> Blob.new("Hello, World!") |> Blob.to_base64()
      "SGVsbG8sIFdvcmxkIQ=="
  """
  @spec to_base64(t()) :: String.t() | nil
  def to_base64(%__MODULE__{data: nil}), do: nil
  def to_base64(%__MODULE__{data: data}), do: Base.encode64(data)

  @doc """
  Create a Blob from base64-encoded string.

  ## Examples

      iex> Blob.from_base64("SGVsbG8sIFdvcmxkIQ==")
      {:ok, %Blob{data: "Hello, World!"}}
  """
  @spec from_base64(String.t()) :: {:ok, t()} | :error
  def from_base64(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, data} -> {:ok, %__MODULE__{data: data}}
      :error -> :error
    end
  end

  @doc """
  Encode binary data to base64 string for Weaviate.

  ## Examples

      iex> Blob.encode("Hello, World!")
      "SGVsbG8sIFdvcmxkIQ=="
  """
  @spec encode(binary()) :: String.t()
  def encode(data) when is_binary(data) do
    Base.encode64(data)
  end

  @doc """
  Decode base64 string to binary.

  ## Examples

      iex> Blob.decode("SGVsbG8sIFdvcmxkIQ==")
      {:ok, "Hello, World!"}

      iex> Blob.decode("invalid!!!")
      :error
  """
  @spec decode(String.t()) :: {:ok, binary()} | :error
  def decode(encoded) when is_binary(encoded) do
    Base.decode64(encoded)
  end

  @doc """
  Decode base64 string, raising on error.

  ## Examples

      iex> Blob.decode!("SGVsbG8sIFdvcmxkIQ==")
      "Hello, World!"
  """
  @spec decode!(String.t()) :: binary()
  def decode!(encoded) when is_binary(encoded) do
    Base.decode64!(encoded)
  end

  @doc """
  Encode file contents to base64 string.

  ## Examples

      {:ok, encoded} = Blob.encode_file("/path/to/file.bin")
  """
  @spec encode_file(Path.t()) :: {:ok, String.t()} | {:error, File.posix()}
  def encode_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, encode(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Encode file contents, raising on error.

  ## Examples

      encoded = Blob.encode_file!("/path/to/file.bin")
  """
  @spec encode_file!(Path.t()) :: String.t()
  def encode_file!(path) do
    path
    |> File.read!()
    |> encode()
  end

  @doc """
  Write decoded blob to file.

  ## Examples

      :ok = Blob.decode_to_file(encoded, "/path/to/output.bin")
  """
  @spec decode_to_file(String.t(), Path.t()) :: :ok | {:error, term()}
  def decode_to_file(encoded, path) do
    case decode(encoded) do
      {:ok, data} -> File.write(path, data)
      :error -> {:error, :invalid_base64}
    end
  end
end
