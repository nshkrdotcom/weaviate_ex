defmodule WeaviateEx.Types.Blob do
  @moduledoc """
  Binary/Blob data handling for Weaviate.

  Weaviate stores blobs as base64-encoded strings.
  This module provides utilities for encoding and decoding blob data.

  ## Examples

      # Encode binary data
      encoded = Blob.encode(<<binary_data>>)

      # Encode file
      {:ok, encoded} = Blob.encode_file("/path/to/image.jpg")

      # Decode
      {:ok, binary} = Blob.decode(encoded)

      # Decode to file
      :ok = Blob.decode_to_file(encoded, "/path/to/output.jpg")
  """

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
