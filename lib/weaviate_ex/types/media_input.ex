defmodule WeaviateEx.Types.MediaInput do
  @moduledoc """
  Handles media input for multi-modal search.

  Accepts file paths, base64 strings, or raw binary data and converts them
  to base64-encoded format suitable for Weaviate API requests.

  ## Input Types

  This module can handle three types of input:

  1. **File paths** - Absolute or relative paths to media files on disk
  2. **Base64 strings** - Already encoded data (with or without data URI prefix)
  3. **Raw binary** - Binary data that will be base64-encoded

  ## Examples

      # From file path
      {:ok, encoded} = MediaInput.prepare("/path/to/image.jpg")

      # From base64 string (with data URI)
      {:ok, encoded} = MediaInput.prepare("data:image/jpeg;base64,/9j/4AAQ...")

      # From base64 string (without data URI)
      {:ok, encoded} = MediaInput.prepare("/9j/4AAQSkZJRg...")

      # From raw binary
      {:ok, encoded} = MediaInput.prepare(<<0xFF, 0xD8, 0xFF, 0xE0>>)
  """

  @type input :: String.t() | binary()

  @doc """
  Prepares media input for API request.

  Takes a file path, base64 string, or raw binary and returns the base64-encoded
  data suitable for sending to Weaviate.

  ## Arguments

  - `input` - The media input (file path, base64 string, or raw binary)

  ## Returns

  - `{:ok, base64_string}` - Successfully prepared media data
  - `{:error, {:file_read_error, reason}}` - Failed to read the file

  ## Examples

      # From file path
      {:ok, encoded} = MediaInput.prepare("/path/to/image.jpg")

      # From base64 string
      {:ok, encoded} = MediaInput.prepare("data:image/jpeg;base64,/9j/4AAQ...")

      # From raw binary
      {:ok, encoded} = MediaInput.prepare(<<0xFF, 0xD8, 0xFF, 0xE0>>)

      # Non-existent file
      {:error, {:file_read_error, :enoent}} = MediaInput.prepare("/nonexistent.jpg")
  """
  @spec prepare(input()) :: {:ok, String.t()} | {:error, term()}
  def prepare(input) when is_binary(input) do
    cond do
      # Check for existing file first
      File.exists?(input) ->
        read_and_encode(input)

      # Check for data URI format (data:type;base64,...)
      base64_with_data_uri?(input) ->
        {:ok, strip_data_uri(input)}

      # Check if it looks like a file path (starts with / or ./ or has file extension)
      # If it looks like a path but doesn't exist, try to read it (will error)
      looks_like_file_path?(input) ->
        read_and_encode(input)

      # Check for valid base64 string
      valid_base64?(input) ->
        {:ok, input}

      true ->
        # Treat as raw binary, encode to base64
        {:ok, Base.encode64(input)}
    end
  end

  @doc """
  Prepares media input, raising on error.

  Same as `prepare/1` but raises an `ArgumentError` on failure.

  ## Examples

      encoded = MediaInput.prepare!("/path/to/image.jpg")

      # Raises ArgumentError for non-existent file
      MediaInput.prepare!("/nonexistent.jpg")
  """
  @spec prepare!(input()) :: String.t()
  def prepare!(input) do
    case prepare(input) do
      {:ok, encoded} -> encoded
      {:error, reason} -> raise ArgumentError, "Failed to prepare media: #{inspect(reason)}"
    end
  end

  @doc """
  Checks if the input is a valid file path that exists.

  ## Examples

      MediaInput.file?(Path.join(System.tmp_dir!(), "existing_file"))  # => true
      MediaInput.file?("/nonexistent/path")  # => false
  """
  @spec file?(String.t()) :: boolean()
  def file?(input) when is_binary(input), do: File.exists?(input)
  def file?(_), do: false

  @doc """
  Checks if the input appears to be base64-encoded.

  Detects both data URI format and raw base64 strings.

  ## Examples

      MediaInput.base64?("data:image/png;base64,iVBORw0...")  # => true
      MediaInput.base64?("iVBORw0KGgo...")  # => true (if valid base64)
      MediaInput.base64?("not base64!")  # => false
  """
  @spec base64?(String.t()) :: boolean()
  def base64?(input) when is_binary(input) do
    base64_with_data_uri?(input) or valid_base64?(input)
  end

  def base64?(_), do: false

  # Private functions

  defp read_and_encode(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, Base.encode64(data)}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp base64_with_data_uri?(str) when is_binary(str) do
    String.starts_with?(str, "data:")
  end

  defp valid_base64?(str) when is_binary(str) do
    # Check if it looks like base64 (only valid base64 chars and reasonable length)
    # and can be successfully decoded
    if String.length(str) >= 4 and Regex.match?(~r/^[A-Za-z0-9+\/=]+$/, str) do
      case Base.decode64(str) do
        {:ok, _} -> true
        :error -> false
      end
    else
      false
    end
  end

  # Heuristics to detect file paths
  # Matches: /path/to/file.ext, ./file.ext, ../file.ext, file.ext (with common extensions)
  defp looks_like_file_path?(str) when is_binary(str) do
    cond do
      # Absolute path
      String.starts_with?(str, "/") -> true
      # Relative path starting with . or ..
      String.starts_with?(str, "./") -> true
      String.starts_with?(str, "../") -> true
      # Has a common media file extension
      has_media_extension?(str) -> true
      true -> false
    end
  end

  @media_extensions ~w(.jpg .jpeg .png .gif .webp .bmp .tiff .tif
                       .mp3 .wav .flac .aac .ogg .m4a
                       .mp4 .avi .mov .mkv .webm .wmv .flv
                       .raw .bin .dat)

  defp has_media_extension?(str) do
    lower = String.downcase(str)
    Enum.any?(@media_extensions, &String.ends_with?(lower, &1))
  end

  defp strip_data_uri(str) do
    case String.split(str, ",", parts: 2) do
      [_, data] -> data
      [data] -> data
    end
  end
end
