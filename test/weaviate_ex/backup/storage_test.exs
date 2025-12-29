defmodule WeaviateEx.Backup.StorageTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Storage

  describe "all/0" do
    test "returns all four backends" do
      backends = Storage.all()

      assert length(backends) == 4
      assert :filesystem in backends
      assert :s3 in backends
      assert :gcs in backends
      assert :azure in backends
    end
  end

  describe "valid?/1" do
    test "returns true for valid backends" do
      assert Storage.valid?(:filesystem) == true
      assert Storage.valid?(:s3) == true
      assert Storage.valid?(:gcs) == true
      assert Storage.valid?(:azure) == true
    end

    test "returns false for invalid backends" do
      assert Storage.valid?(:invalid) == false
      assert Storage.valid?(:local) == false
      assert Storage.valid?(:aws) == false
      assert Storage.valid?(nil) == false
    end
  end

  describe "to_api_path/1" do
    test "converts filesystem to api path" do
      assert Storage.to_api_path(:filesystem) == "filesystem"
    end

    test "converts s3 to api path" do
      assert Storage.to_api_path(:s3) == "s3"
    end

    test "converts gcs to api path" do
      assert Storage.to_api_path(:gcs) == "gcs"
    end

    test "converts azure to api path" do
      assert Storage.to_api_path(:azure) == "azure"
    end
  end

  describe "from_api/1" do
    test "parses filesystem string" do
      assert Storage.from_api("filesystem") == {:ok, :filesystem}
    end

    test "parses s3 string" do
      assert Storage.from_api("s3") == {:ok, :s3}
    end

    test "parses gcs string" do
      assert Storage.from_api("gcs") == {:ok, :gcs}
    end

    test "parses azure string" do
      assert Storage.from_api("azure") == {:ok, :azure}
    end

    test "returns error for invalid string" do
      assert Storage.from_api("invalid") == {:error, :invalid_backend}
      assert Storage.from_api("local") == {:error, :invalid_backend}
      assert Storage.from_api("") == {:error, :invalid_backend}
    end
  end
end
