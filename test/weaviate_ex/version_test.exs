defmodule WeaviateEx.VersionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Version

  describe "parse/1" do
    test "parses standard semver" do
      assert Version.parse("1.28.0") == {:ok, {1, 28, 0}}
    end

    test "parses version with v prefix" do
      assert Version.parse("v1.28.0") == {:ok, {1, 28, 0}}
    end

    test "parses version with prerelease" do
      assert Version.parse("1.28.0-rc1") == {:ok, {1, 28, 0}}
    end

    test "parses version with prerelease and build metadata" do
      assert Version.parse("1.28.0-rc1+build123") == {:ok, {1, 28, 0}}
    end

    test "parses version with only prerelease info" do
      assert Version.parse("1.27.5-beta") == {:ok, {1, 27, 5}}
    end

    test "returns error for invalid version" do
      assert Version.parse("invalid") == {:error, :invalid_version}
    end

    test "returns error for empty string" do
      assert Version.parse("") == {:error, :invalid_version}
    end

    test "returns error for partial version" do
      assert Version.parse("1.28") == {:error, :invalid_version}
    end
  end

  describe "meets_minimum?/2" do
    test "returns true when version meets minimum" do
      assert Version.meets_minimum?({1, 28, 0}, {1, 27, 0}) == true
    end

    test "returns false when version below minimum" do
      assert Version.meets_minimum?({1, 26, 0}, {1, 27, 0}) == false
    end

    test "returns true for equal versions" do
      assert Version.meets_minimum?({1, 27, 0}, {1, 27, 0}) == true
    end

    test "handles patch version differences" do
      assert Version.meets_minimum?({1, 27, 5}, {1, 27, 0}) == true
    end

    test "handles major version differences" do
      assert Version.meets_minimum?({2, 0, 0}, {1, 27, 0}) == true
    end

    test "returns false when major version is lower" do
      assert Version.meets_minimum?({0, 99, 99}, {1, 0, 0}) == false
    end

    test "handles minor version differences correctly" do
      assert Version.meets_minimum?({1, 26, 99}, {1, 27, 0}) == false
    end
  end

  describe "get_server_version/1" do
    test "extracts version from meta response" do
      meta = %{"version" => "1.28.0", "modules" => %{}}
      assert Version.get_server_version(meta) == {:ok, {1, 28, 0}}
    end

    test "extracts version with v prefix" do
      meta = %{"version" => "v1.28.0", "modules" => %{}}
      assert Version.get_server_version(meta) == {:ok, {1, 28, 0}}
    end

    test "returns error for missing version" do
      assert Version.get_server_version(%{}) == {:error, :no_version}
    end

    test "returns error for nil version" do
      assert Version.get_server_version(%{"version" => nil}) == {:error, :no_version}
    end

    test "returns error for non-string version" do
      assert Version.get_server_version(%{"version" => 123}) == {:error, :no_version}
    end
  end

  describe "validate_server/1" do
    test "returns ok for supported version" do
      assert Version.validate_server({1, 28, 0}) == :ok
    end

    test "returns ok for minimum version" do
      assert Version.validate_server({1, 27, 0}) == :ok
    end

    test "returns error for unsupported version" do
      assert {:error, {:unsupported_version, {1, 20, 0}, {1, 27, 0}}} =
               Version.validate_server({1, 20, 0})
    end

    test "returns error for version just below minimum" do
      assert {:error, {:unsupported_version, {1, 26, 99}, {1, 27, 0}}} =
               Version.validate_server({1, 26, 99})
    end
  end

  describe "minimum_version/0" do
    test "returns the minimum version tuple" do
      assert Version.minimum_version() == {1, 27, 0}
    end
  end

  describe "minimum_version_string/0" do
    test "returns the minimum version as string" do
      assert Version.minimum_version_string() == "1.27.0"
    end
  end

  describe "format_version/1" do
    test "formats version tuple to string" do
      assert Version.format_version({1, 28, 0}) == "1.28.0"
    end

    test "formats version with different numbers" do
      assert Version.format_version({2, 0, 15}) == "2.0.15"
    end
  end

  describe "check_compatibility/1" do
    test "returns ok for supported version" do
      meta = %{"version" => "1.28.0"}
      assert Version.check_compatibility(meta) == :ok
    end

    test "returns ok for minimum version" do
      meta = %{"version" => "1.27.0"}
      assert Version.check_compatibility(meta) == :ok
    end

    test "returns error for unsupported version" do
      meta = %{"version" => "1.20.0"}

      assert {:error, message} = Version.check_compatibility(meta)
      assert message =~ "1.20.0"
      assert message =~ "1.27.0"
      assert message =~ "below minimum"
    end

    test "returns error for missing version" do
      meta = %{"hostname" => "weaviate"}

      assert {:error, message} = Version.check_compatibility(meta)
      assert message =~ "Unable to determine"
    end

    test "returns error for invalid version format" do
      meta = %{"version" => "not-a-version"}

      assert {:error, message} = Version.check_compatibility(meta)
      assert message =~ "Invalid version format"
    end
  end

  describe "supports_grpc?/1" do
    test "returns true for versions >= 1.23.0" do
      assert Version.supports_grpc?({1, 28, 0}) == true
      assert Version.supports_grpc?({1, 23, 0}) == true
      assert Version.supports_grpc?({2, 0, 0}) == true
    end

    test "returns false for versions < 1.23.0" do
      assert Version.supports_grpc?({1, 22, 99}) == false
      assert Version.supports_grpc?({1, 20, 0}) == false
    end
  end

  describe "grpc_minimum_version/0" do
    test "returns the gRPC minimum version tuple" do
      assert Version.grpc_minimum_version() == {1, 23, 0}
    end
  end

  describe "get_grpc_max_message_size/1" do
    test "extracts integer message size from meta" do
      meta = %{"grpcMaxMessageSize" => 104_858_000}
      assert Version.get_grpc_max_message_size(meta) == {:ok, 104_858_000}
    end

    test "extracts string message size from meta" do
      meta = %{"grpcMaxMessageSize" => "104858000"}
      assert Version.get_grpc_max_message_size(meta) == {:ok, 104_858_000}
    end

    test "returns :default for missing message size" do
      meta = %{"version" => "1.28.0"}
      assert Version.get_grpc_max_message_size(meta) == :default
    end
  end
end
