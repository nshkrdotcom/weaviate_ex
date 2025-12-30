defmodule WeaviateEx.Types.MediaTypeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.MediaType

  describe "valid?/1" do
    test "returns true for all supported media types" do
      for type <- [:image, :audio, :video, :thermal, :depth, :imu] do
        assert MediaType.valid?(type), "Expected #{type} to be valid"
      end
    end

    test "returns false for unsupported types" do
      refute MediaType.valid?(:invalid)
      refute MediaType.valid?(:pdf)
      refute MediaType.valid?(:text)
      refute MediaType.valid?(nil)
    end
  end

  describe "all/0" do
    test "returns all supported media types" do
      assert MediaType.all() == [:image, :audio, :video, :thermal, :depth, :imu]
    end
  end

  describe "to_grpc_field/1" do
    test "maps image to :image" do
      assert MediaType.to_grpc_field(:image) == :image
    end

    test "maps audio to :audio" do
      assert MediaType.to_grpc_field(:audio) == :audio
    end

    test "maps video to :video" do
      assert MediaType.to_grpc_field(:video) == :video
    end

    test "maps thermal to :thermal" do
      assert MediaType.to_grpc_field(:thermal) == :thermal
    end

    test "maps depth to :depth" do
      assert MediaType.to_grpc_field(:depth) == :depth
    end

    test "maps imu to :imu" do
      assert MediaType.to_grpc_field(:imu) == :imu
    end
  end
end
