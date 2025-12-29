defmodule WeaviateEx.Backup.CompressionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Compression

  describe "all/0" do
    test "returns all compression levels" do
      levels = Compression.all()

      assert length(levels) == 3
      assert :default in levels
      assert :best_speed in levels
      assert :best_compression in levels
    end
  end

  describe "valid?/1" do
    test "returns true for valid compression levels" do
      assert Compression.valid?(:default) == true
      assert Compression.valid?(:best_speed) == true
      assert Compression.valid?(:best_compression) == true
    end

    test "returns false for invalid compression levels" do
      assert Compression.valid?(:invalid) == false
      assert Compression.valid?(:none) == false
      assert Compression.valid?(:fast) == false
    end
  end

  describe "to_api/1" do
    test "converts default to API format" do
      assert Compression.to_api(:default) == "DefaultCompression"
    end

    test "converts best_speed to API format" do
      assert Compression.to_api(:best_speed) == "BestSpeed"
    end

    test "converts best_compression to API format" do
      assert Compression.to_api(:best_compression) == "BestCompression"
    end
  end

  describe "from_api/1" do
    test "parses DefaultCompression string" do
      assert Compression.from_api("DefaultCompression") == {:ok, :default}
    end

    test "parses BestSpeed string" do
      assert Compression.from_api("BestSpeed") == {:ok, :best_speed}
    end

    test "parses BestCompression string" do
      assert Compression.from_api("BestCompression") == {:ok, :best_compression}
    end

    test "returns error for invalid string" do
      assert Compression.from_api("invalid") == {:error, :invalid_compression}
      assert Compression.from_api("None") == {:error, :invalid_compression}
      assert Compression.from_api("") == {:error, :invalid_compression}
    end
  end
end
