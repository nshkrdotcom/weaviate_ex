defmodule WeaviateEx.Types.MediaInputTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.MediaInput

  describe "prepare/1" do
    test "reads and encodes file path" do
      path = Path.join(System.tmp_dir!(), "test_media_#{:rand.uniform(10000)}.jpg")
      File.write!(path, "image content")

      result = MediaInput.prepare(path)
      assert {:ok, encoded} = result
      assert encoded == Base.encode64("image content")

      File.rm!(path)
    end

    test "returns error for non-existent file" do
      # This path doesn't exist but looks like a file path (has extension)
      # So it won't be treated as base64 or binary
      path = Path.join(System.tmp_dir!(), "nonexistent_#{:rand.uniform(10000)}.jpg")

      result = MediaInput.prepare(path)
      assert {:error, {:file_read_error, :enoent}} = result
    end

    test "strips data URI prefix from base64" do
      data_uri = "data:image/jpeg;base64,SGVsbG8gV29ybGQ="

      result = MediaInput.prepare(data_uri)
      assert {:ok, "SGVsbG8gV29ybGQ="} = result
    end

    test "returns already-encoded base64 as-is" do
      base64 = Base.encode64("test content")

      result = MediaInput.prepare(base64)
      assert {:ok, ^base64} = result
    end

    test "encodes raw binary to base64" do
      # Raw binary data that's not valid base64 or a file path
      binary = <<0xFF, 0xD8, 0xFF, 0xE0>>

      result = MediaInput.prepare(binary)
      assert {:ok, encoded} = result
      assert encoded == Base.encode64(binary)
    end

    test "handles empty data URI" do
      data_uri = "data:image/png;base64,"

      result = MediaInput.prepare(data_uri)
      assert {:ok, ""} = result
    end

    test "handles base64 with padding" do
      base64_with_padding = "SGVsbG8="

      result = MediaInput.prepare(base64_with_padding)
      assert {:ok, ^base64_with_padding} = result
    end

    test "handles base64 without padding" do
      # Valid base64 without padding - "YWJj" decodes to "abc"
      base64_no_padding = "YWJj"

      result = MediaInput.prepare(base64_no_padding)
      assert {:ok, ^base64_no_padding} = result
    end
  end

  describe "prepare!/1" do
    test "returns encoded data for valid input" do
      path = Path.join(System.tmp_dir!(), "test_prepare_bang_#{:rand.uniform(10000)}.png")
      File.write!(path, "png content")

      result = MediaInput.prepare!(path)
      assert result == Base.encode64("png content")

      File.rm!(path)
    end

    test "raises ArgumentError for non-existent file" do
      path = Path.join(System.tmp_dir!(), "nonexistent_bang_#{:rand.uniform(10000)}.png")

      assert_raise ArgumentError, ~r/Failed to prepare media/, fn ->
        MediaInput.prepare!(path)
      end
    end
  end

  describe "file?/1" do
    test "returns true for existing file" do
      path = Path.join(System.tmp_dir!(), "test_file_check_#{:rand.uniform(10000)}.txt")
      File.write!(path, "content")

      assert MediaInput.file?(path) == true

      File.rm!(path)
    end

    test "returns false for non-existent file" do
      path = Path.join(System.tmp_dir!(), "nonexistent_check_#{:rand.uniform(10000)}.txt")
      assert MediaInput.file?(path) == false
    end

    test "returns false for non-string input" do
      assert MediaInput.file?(123) == false
      assert MediaInput.file?(nil) == false
    end
  end

  describe "base64?/1" do
    test "returns true for data URI format" do
      assert MediaInput.base64?("data:image/png;base64,iVBORw0KGgo=") == true
    end

    test "returns true for valid base64 string" do
      assert MediaInput.base64?(Base.encode64("test")) == true
    end

    test "returns false for invalid base64" do
      # String with invalid base64 characters
      assert MediaInput.base64?("not!valid@base64#") == false
    end

    test "returns false for non-string input" do
      assert MediaInput.base64?(123) == false
      assert MediaInput.base64?(nil) == false
    end

    test "returns false for very short strings" do
      # Very short strings shouldn't be considered base64
      assert MediaInput.base64?("ab") == false
    end
  end

  describe "integration scenarios" do
    test "handles image file path" do
      path = Path.join(System.tmp_dir!(), "test_image_#{:rand.uniform(10000)}.jpg")
      # JPEG file signature
      File.write!(path, <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>)

      {:ok, encoded} = MediaInput.prepare(path)
      {:ok, decoded} = Base.decode64(encoded)
      assert decoded == <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>

      File.rm!(path)
    end

    test "handles audio file path" do
      path = Path.join(System.tmp_dir!(), "test_audio_#{:rand.uniform(10000)}.wav")
      # WAV file header (RIFF)
      File.write!(path, "RIFF" <> <<0x00, 0x00, 0x00, 0x00>> <> "WAVE")

      {:ok, encoded} = MediaInput.prepare(path)
      {:ok, decoded} = Base.decode64(encoded)
      assert decoded == "RIFF" <> <<0x00, 0x00, 0x00, 0x00>> <> "WAVE"

      File.rm!(path)
    end

    test "handles video file path" do
      path = Path.join(System.tmp_dir!(), "test_video_#{:rand.uniform(10000)}.mp4")
      # MP4 ftyp box header
      File.write!(path, <<0x00, 0x00, 0x00, 0x18>> <> "ftyp")

      {:ok, encoded} = MediaInput.prepare(path)
      {:ok, decoded} = Base.decode64(encoded)
      assert decoded == <<0x00, 0x00, 0x00, 0x18>> <> "ftyp"

      File.rm!(path)
    end
  end
end
