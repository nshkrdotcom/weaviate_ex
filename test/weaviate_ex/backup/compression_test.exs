defmodule WeaviateEx.Backup.CompressionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Compression

  describe "all/0" do
    test "returns all compression levels including ZSTD variants" do
      levels = Compression.all()

      # Original GZIP levels
      assert :default in levels
      assert :best_speed in levels
      assert :best_compression in levels

      # New ZSTD levels
      assert :zstd_default in levels
      assert :zstd_best_speed in levels
      assert :zstd_best_compression in levels

      # No compression
      assert :no_compression in levels

      # Should have 7 total levels
      assert length(levels) == 7
    end
  end

  describe "valid?/1" do
    test "returns true for GZIP compression levels" do
      assert Compression.valid?(:default) == true
      assert Compression.valid?(:best_speed) == true
      assert Compression.valid?(:best_compression) == true
    end

    test "returns true for ZSTD compression levels" do
      assert Compression.valid?(:zstd_default) == true
      assert Compression.valid?(:zstd_best_speed) == true
      assert Compression.valid?(:zstd_best_compression) == true
    end

    test "returns true for no_compression" do
      assert Compression.valid?(:no_compression) == true
    end

    test "returns false for invalid compression levels" do
      assert Compression.valid?(:invalid) == false
      assert Compression.valid?(:none) == false
      assert Compression.valid?(:fast) == false
    end
  end

  describe "to_api/1" do
    test "converts GZIP levels to API format" do
      assert Compression.to_api(:default) == "DefaultCompression"
      assert Compression.to_api(:best_speed) == "BestSpeed"
      assert Compression.to_api(:best_compression) == "BestCompression"
    end

    test "converts ZSTD levels to API format" do
      assert Compression.to_api(:zstd_default) == "ZstdDefaultCompression"
      assert Compression.to_api(:zstd_best_speed) == "ZstdBestSpeed"
      assert Compression.to_api(:zstd_best_compression) == "ZstdBestCompression"
    end

    test "converts no_compression to API format" do
      assert Compression.to_api(:no_compression) == "NoCompression"
    end
  end

  describe "from_api/1" do
    test "parses GZIP levels from API response" do
      assert Compression.from_api("DefaultCompression") == {:ok, :default}
      assert Compression.from_api("BestSpeed") == {:ok, :best_speed}
      assert Compression.from_api("BestCompression") == {:ok, :best_compression}
    end

    test "parses ZSTD levels from API response" do
      assert Compression.from_api("ZstdDefaultCompression") == {:ok, :zstd_default}
      assert Compression.from_api("ZstdBestSpeed") == {:ok, :zstd_best_speed}
      assert Compression.from_api("ZstdBestCompression") == {:ok, :zstd_best_compression}
    end

    test "parses no_compression from API response" do
      assert Compression.from_api("NoCompression") == {:ok, :no_compression}
    end

    test "returns error for invalid string" do
      assert Compression.from_api("invalid") == {:error, :invalid_compression}
      assert Compression.from_api("None") == {:error, :invalid_compression}
      assert Compression.from_api("") == {:error, :invalid_compression}
    end
  end

  describe "gzip?/1" do
    test "returns true for GZIP compression levels" do
      assert Compression.gzip?(:default) == true
      assert Compression.gzip?(:best_speed) == true
      assert Compression.gzip?(:best_compression) == true
    end

    test "returns false for ZSTD compression levels" do
      assert Compression.gzip?(:zstd_default) == false
      assert Compression.gzip?(:zstd_best_speed) == false
      assert Compression.gzip?(:zstd_best_compression) == false
    end

    test "returns false for no_compression" do
      assert Compression.gzip?(:no_compression) == false
    end
  end

  describe "zstd?/1" do
    test "returns false for GZIP compression levels" do
      assert Compression.zstd?(:default) == false
      assert Compression.zstd?(:best_speed) == false
      assert Compression.zstd?(:best_compression) == false
    end

    test "returns true for ZSTD compression levels" do
      assert Compression.zstd?(:zstd_default) == true
      assert Compression.zstd?(:zstd_best_speed) == true
      assert Compression.zstd?(:zstd_best_compression) == true
    end

    test "returns false for no_compression" do
      assert Compression.zstd?(:no_compression) == false
    end
  end
end
