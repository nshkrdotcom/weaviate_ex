defmodule WeaviateEx.Query.NearMediaTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.NearMedia

  @media_types [:audio, :video, :thermal, :depth, :imu]

  describe "new/2" do
    for type <- @media_types do
      test "creates near_media query for #{type}" do
        result = NearMedia.new(unquote(type), media: "base64data")

        assert result.type == unquote(type)
        assert result.media == "base64data"
      end
    end

    test "raises on invalid media type" do
      assert_raise ArgumentError, ~r/invalid media type/, fn ->
        NearMedia.new(:invalid, media: "data")
      end
    end

    test "accepts certainty threshold" do
      result = NearMedia.new(:audio, media: "data", certainty: 0.7)
      assert result.certainty == 0.7
    end

    test "accepts distance threshold" do
      result = NearMedia.new(:video, media: "data", distance: 0.3)
      assert result.distance == 0.3
    end

    test "accepts media_file path" do
      result = NearMedia.new(:audio, media_file: "/path/to/audio.wav")
      assert result.media_file == "/path/to/audio.wav"
    end

    test "accepts target_vectors" do
      result = NearMedia.new(:audio, media: "data", target_vectors: ["audio_vec"])
      assert result.target_vectors == ["audio_vec"]
    end

    test "raises on missing media source" do
      assert_raise ArgumentError, ~r/must provide either :media or :media_file/, fn ->
        NearMedia.new(:audio, [])
      end
    end

    test "raises on both media sources provided" do
      assert_raise ArgumentError, ~r/cannot provide both/, fn ->
        NearMedia.new(:audio, media: "data", media_file: "/path")
      end
    end
  end

  describe "media_types/0" do
    test "returns all supported media types" do
      assert NearMedia.media_types() == [:audio, :video, :thermal, :depth, :imu]
    end
  end

  describe "encode_media_file/1" do
    test "encodes file contents to base64" do
      path = Path.join(System.tmp_dir!(), "test_media_#{:rand.uniform(10000)}.wav")
      File.write!(path, "audio content")

      result = NearMedia.encode_media_file(path)
      assert result == Base.encode64("audio content")

      File.rm!(path)
    end

    test "raises on non-existent file" do
      assert_raise File.Error, fn ->
        NearMedia.encode_media_file("/nonexistent/path.wav")
      end
    end
  end

  describe "get_encoded_media/1" do
    test "returns base64 string as-is" do
      near_media = NearMedia.new(:audio, media: "base64data")
      assert NearMedia.get_encoded_media(near_media) == "base64data"
    end

    test "encodes file when media_file is provided" do
      path = Path.join(System.tmp_dir!(), "test_media_encode_#{:rand.uniform(10000)}.wav")
      File.write!(path, "audio content")

      near_media = NearMedia.new(:audio, media_file: path)
      result = NearMedia.get_encoded_media(near_media)
      assert result == Base.encode64("audio content")

      File.rm!(path)
    end
  end

  describe "to_grpc/1" do
    test "converts to gRPC format with correct type" do
      near_media = NearMedia.new(:thermal, media: "data", certainty: 0.8)

      grpc = NearMedia.to_grpc(near_media)

      assert grpc.media == "data"
      assert grpc.type == :MEDIA_TYPE_THERMAL
      assert grpc.certainty == 0.8
    end

    test "maps all media types correctly" do
      expected_mappings = %{
        audio: :MEDIA_TYPE_AUDIO,
        video: :MEDIA_TYPE_VIDEO,
        thermal: :MEDIA_TYPE_THERMAL,
        depth: :MEDIA_TYPE_DEPTH,
        imu: :MEDIA_TYPE_IMU
      }

      for {type, expected_grpc_type} <- expected_mappings do
        near_media = NearMedia.new(type, media: "data")
        grpc = NearMedia.to_grpc(near_media)
        assert grpc.type == expected_grpc_type, "Expected #{type} to map to #{expected_grpc_type}"
      end
    end

    test "includes target_vectors when provided" do
      near_media = NearMedia.new(:audio, media: "data", target_vectors: ["vec1"])

      grpc = NearMedia.to_grpc(near_media)

      assert grpc.target_vectors == ["vec1"]
    end

    test "excludes nil values" do
      near_media = NearMedia.new(:depth, media: "data")

      grpc = NearMedia.to_grpc(near_media)

      assert grpc.media == "data"
      assert grpc.type == :MEDIA_TYPE_DEPTH
      refute Map.has_key?(grpc, :certainty)
      refute Map.has_key?(grpc, :distance)
      refute Map.has_key?(grpc, :target_vectors)
    end
  end

  describe "to_graphql/1" do
    test "converts to GraphQL format" do
      near_media = NearMedia.new(:depth, media: "data", distance: 0.2)

      graphql = NearMedia.to_graphql(near_media)

      assert graphql["media"] == "data"
      assert graphql["type"] == "depth"
      assert graphql["distance"] == 0.2
    end

    test "includes target_vectors when provided" do
      near_media = NearMedia.new(:video, media: "data", target_vectors: ["video_vec"])

      graphql = NearMedia.to_graphql(near_media)

      assert graphql["targetVectors"] == ["video_vec"]
    end

    test "excludes nil values" do
      near_media = NearMedia.new(:imu, media: "data")

      graphql = NearMedia.to_graphql(near_media)

      assert graphql["media"] == "data"
      assert graphql["type"] == "imu"
      refute Map.has_key?(graphql, "certainty")
      refute Map.has_key?(graphql, "distance")
      refute Map.has_key?(graphql, "targetVectors")
    end
  end
end
