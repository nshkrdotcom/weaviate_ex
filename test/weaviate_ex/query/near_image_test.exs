defmodule WeaviateEx.Query.NearImageTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.NearImage

  describe "new/1" do
    test "creates near_image query from base64 string" do
      result = NearImage.new(image: "base64encodeddata==")

      assert result.image == "base64encodeddata=="
      assert result.image_file == nil
      assert result.certainty == nil
      assert result.distance == nil
    end

    test "creates near_image query from file path" do
      result = NearImage.new(image_file: "/path/to/image.png")

      assert result.image_file == "/path/to/image.png"
      assert result.image == nil
    end

    test "accepts certainty threshold" do
      result = NearImage.new(image: "data", certainty: 0.8)

      assert result.certainty == 0.8
    end

    test "accepts distance threshold" do
      result = NearImage.new(image: "data", distance: 0.2)

      assert result.distance == 0.2
    end

    test "accepts target_vectors for named vectors" do
      result = NearImage.new(image: "data", target_vectors: ["image_vector"])

      assert result.target_vectors == ["image_vector"]
    end

    test "raises on missing image source" do
      assert_raise ArgumentError, ~r/must provide either :image or :image_file/, fn ->
        NearImage.new([])
      end
    end

    test "raises on both image sources provided" do
      assert_raise ArgumentError, ~r/cannot provide both/, fn ->
        NearImage.new(image: "data", image_file: "/path")
      end
    end
  end

  describe "encode_image_file/1" do
    test "encodes file contents to base64" do
      # Create temp file for testing
      path = Path.join(System.tmp_dir!(), "test_image_#{:rand.uniform(10000)}.png")
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47>>)

      result = NearImage.encode_image_file(path)
      assert result == Base.encode64(<<0x89, 0x50, 0x4E, 0x47>>)

      File.rm!(path)
    end

    test "raises on non-existent file" do
      assert_raise File.Error, fn ->
        NearImage.encode_image_file("/nonexistent/path.png")
      end
    end
  end

  describe "get_encoded_image/1" do
    test "returns base64 string as-is" do
      near_image = NearImage.new(image: "base64data")
      assert NearImage.get_encoded_image(near_image) == "base64data"
    end

    test "encodes file when image_file is provided" do
      path = Path.join(System.tmp_dir!(), "test_image_encode_#{:rand.uniform(10000)}.png")
      File.write!(path, "test content")

      near_image = NearImage.new(image_file: path)
      result = NearImage.get_encoded_image(near_image)
      assert result == Base.encode64("test content")

      File.rm!(path)
    end
  end

  describe "to_grpc/1" do
    test "converts to gRPC NearImageSearch struct" do
      near_image = NearImage.new(image: "base64data", certainty: 0.8)

      grpc = NearImage.to_grpc(near_image)

      assert grpc.image == "base64data"
      assert grpc.certainty == 0.8
      refute Map.has_key?(grpc, :distance)
    end

    test "includes target_vectors when provided" do
      near_image = NearImage.new(image: "base64data", target_vectors: ["vec1", "vec2"])

      grpc = NearImage.to_grpc(near_image)

      assert grpc.target_vectors == ["vec1", "vec2"]
    end

    test "excludes nil values" do
      near_image = NearImage.new(image: "base64data")

      grpc = NearImage.to_grpc(near_image)

      assert grpc.image == "base64data"
      refute Map.has_key?(grpc, :certainty)
      refute Map.has_key?(grpc, :distance)
      refute Map.has_key?(grpc, :target_vectors)
    end
  end

  describe "to_graphql/1" do
    test "converts to GraphQL map format" do
      near_image = NearImage.new(image: "base64data", distance: 0.2)

      graphql = NearImage.to_graphql(near_image)

      assert graphql["image"] == "base64data"
      assert graphql["distance"] == 0.2
      refute Map.has_key?(graphql, "certainty")
    end

    test "includes target_vectors when provided" do
      near_image = NearImage.new(image: "base64data", target_vectors: ["image_vec"])

      graphql = NearImage.to_graphql(near_image)

      assert graphql["targetVectors"] == ["image_vec"]
    end
  end
end
