defmodule WeaviateEx.Backup.ConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Backup.Config

  describe "create/1" do
    test "creates config with all options" do
      config = Config.create(cpu_percentage: 50, compression: :best_compression)

      assert config.cpu_percentage == 50
      assert config.compression == :best_compression
    end

    test "creates config with only cpu_percentage" do
      config = Config.create(cpu_percentage: 80)

      assert config.cpu_percentage == 80
      assert config.compression == nil
    end

    test "creates config with only compression" do
      config = Config.create(compression: :best_speed)

      assert config.cpu_percentage == nil
      assert config.compression == :best_speed
    end

    test "creates empty config with no options" do
      config = Config.create()

      assert config.cpu_percentage == nil
      assert config.compression == nil
    end
  end

  describe "restore/1" do
    test "creates restore config with cpu_percentage" do
      config = Config.restore(cpu_percentage: 80)

      assert config.cpu_percentage == 80
    end

    test "creates empty restore config with no options" do
      config = Config.restore()

      assert config.cpu_percentage == nil
    end
  end

  describe "Config.Create struct" do
    test "new/1 creates struct with all options" do
      config = Config.Create.new(cpu_percentage: 50, compression: :best_compression)

      assert config.cpu_percentage == 50
      assert config.compression == :best_compression
    end

    test "new/0 creates empty struct" do
      config = Config.Create.new()

      assert config.cpu_percentage == nil
      assert config.compression == nil
    end
  end

  describe "Config.Create.to_api/1" do
    test "includes all provided fields" do
      config = Config.Create.new(cpu_percentage: 50, compression: :best_compression)
      api_map = Config.Create.to_api(config)

      assert api_map[:CPUPercentage] == 50
      assert api_map[:CompressionLevel] == "BestCompression"
    end

    test "excludes nil cpu_percentage" do
      config = Config.Create.new(compression: :best_speed)
      api_map = Config.Create.to_api(config)

      refute Map.has_key?(api_map, :CPUPercentage)
      assert api_map[:CompressionLevel] == "BestSpeed"
    end

    test "excludes nil compression" do
      config = Config.Create.new(cpu_percentage: 50)
      api_map = Config.Create.to_api(config)

      assert api_map[:CPUPercentage] == 50
      refute Map.has_key?(api_map, :CompressionLevel)
    end

    test "returns empty map when all nil" do
      config = Config.Create.new()
      api_map = Config.Create.to_api(config)

      assert api_map == %{}
    end
  end

  describe "Config.Restore struct" do
    test "new/1 creates struct with cpu_percentage" do
      config = Config.Restore.new(cpu_percentage: 80)

      assert config.cpu_percentage == 80
    end

    test "new/0 creates empty struct" do
      config = Config.Restore.new()

      assert config.cpu_percentage == nil
    end
  end

  describe "Config.Restore.to_api/1" do
    test "includes cpu_percentage when provided" do
      config = Config.Restore.new(cpu_percentage: 80)
      api_map = Config.Restore.to_api(config)

      assert api_map == %{CPUPercentage: 80}
    end

    test "returns empty map when cpu_percentage is nil" do
      config = Config.Restore.new()
      api_map = Config.Restore.to_api(config)

      assert api_map == %{}
    end
  end
end
