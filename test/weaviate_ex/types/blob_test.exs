defmodule WeaviateEx.Types.BlobTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.Blob

  describe "encode/1" do
    test "encodes binary data to base64" do
      data = "Hello, World!"
      encoded = Blob.encode(data)
      assert encoded == Base.encode64(data)
    end

    test "encodes empty binary" do
      assert Blob.encode("") == ""
    end

    test "encodes binary with special characters" do
      data = <<0, 1, 2, 255, 254, 253>>
      encoded = Blob.encode(data)
      assert {:ok, ^data} = Blob.decode(encoded)
    end
  end

  describe "decode/1" do
    test "decodes base64 string to binary" do
      original = "Hello, World!"
      encoded = Base.encode64(original)

      assert {:ok, ^original} = Blob.decode(encoded)
    end

    test "returns error for invalid base64" do
      assert :error = Blob.decode("not-valid-base64!!!")
    end
  end

  describe "decode!/1" do
    test "decodes base64 string to binary" do
      original = "Hello, World!"
      encoded = Base.encode64(original)

      assert Blob.decode!(encoded) == original
    end

    test "raises for invalid base64" do
      assert_raise ArgumentError, fn ->
        Blob.decode!("not-valid-base64!!!")
      end
    end
  end

  describe "encode_file/1" do
    test "encodes file contents to base64" do
      # Create a temporary file
      path = Path.join(System.tmp_dir!(), "blob_test_#{:erlang.unique_integer()}.txt")
      content = "Test file content"
      File.write!(path, content)

      try do
        assert {:ok, encoded} = Blob.encode_file(path)
        assert {:ok, ^content} = Blob.decode(encoded)
      after
        File.rm(path)
      end
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = Blob.encode_file("/nonexistent/file.txt")
    end
  end

  describe "encode_file!/1" do
    test "encodes file contents to base64" do
      path = Path.join(System.tmp_dir!(), "blob_test_#{:erlang.unique_integer()}.txt")
      content = "Test file content"
      File.write!(path, content)

      try do
        encoded = Blob.encode_file!(path)
        assert Blob.decode!(encoded) == content
      after
        File.rm(path)
      end
    end

    test "raises for non-existent file" do
      assert_raise File.Error, fn ->
        Blob.encode_file!("/nonexistent/file.txt")
      end
    end
  end

  describe "decode_to_file/2" do
    test "writes decoded blob to file" do
      original = "Test content for file"
      encoded = Blob.encode(original)
      path = Path.join(System.tmp_dir!(), "blob_out_#{:erlang.unique_integer()}.txt")

      try do
        assert :ok = Blob.decode_to_file(encoded, path)
        assert File.read!(path) == original
      after
        File.rm(path)
      end
    end

    test "returns error for invalid base64" do
      path = Path.join(System.tmp_dir!(), "blob_out_#{:erlang.unique_integer()}.txt")
      assert {:error, _} = Blob.decode_to_file("invalid!!!", path)
    end
  end
end
