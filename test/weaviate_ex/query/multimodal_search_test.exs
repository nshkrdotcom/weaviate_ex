defmodule WeaviateEx.Query.MultimodalSearchTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query
  alias WeaviateEx.Query.{NearImage, NearMedia}

  # Create temporary test files for file-based tests
  setup do
    tmp_dir = System.tmp_dir!()
    random_suffix = :rand.uniform(100_000)

    image_path = Path.join(tmp_dir, "test_image_#{random_suffix}.jpg")
    audio_path = Path.join(tmp_dir, "test_audio_#{random_suffix}.wav")
    video_path = Path.join(tmp_dir, "test_video_#{random_suffix}.mp4")

    # Create test files with mock content
    File.write!(image_path, "mock image content")
    File.write!(audio_path, "mock audio content")
    File.write!(video_path, "mock video content")

    on_exit(fn ->
      File.rm(image_path)
      File.rm(audio_path)
      File.rm(video_path)
    end)

    %{
      image_path: image_path,
      audio_path: audio_path,
      video_path: video_path,
      base64_data: Base.encode64("test data")
    }
  end

  describe "with_near_image/3" do
    test "builds query with base64 image data", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data)

      assert %NearImage{} = query.near_image
      assert query.near_image.image == base64_data
    end

    test "builds query with file path", %{image_path: image_path} do
      query =
        Query.get("Products")
        |> Query.with_near_image(image_path)

      assert %NearImage{} = query.near_image
      assert query.near_image.image == Base.encode64("mock image content")
    end

    test "accepts raw binary data" do
      binary = <<0xFF, 0xD8, 0xFF, 0xE0>>

      query =
        Query.get("Products")
        |> Query.with_near_image(binary)

      assert %NearImage{} = query.near_image
      assert query.near_image.image == Base.encode64(binary)
    end

    test "passes certainty option", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data, certainty: 0.8)

      assert query.near_image.certainty == 0.8
    end

    test "passes distance option", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data, distance: 0.2)

      assert query.near_image.distance == 0.2
    end

    test "passes target_vectors option", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data, target_vectors: ["image_vector"])

      assert query.near_image.target_vectors == ["image_vector"]
    end
  end

  describe "with_near_audio/3" do
    test "builds query with base64 audio data", %{base64_data: base64_data} do
      query =
        Query.get("Podcasts")
        |> Query.with_near_audio(base64_data)

      assert %NearMedia{type: :audio} = query.near_media
      assert query.near_media.media == base64_data
    end

    test "builds query with file path", %{audio_path: audio_path} do
      query =
        Query.get("Podcasts")
        |> Query.with_near_audio(audio_path)

      assert %NearMedia{type: :audio} = query.near_media
      assert query.near_media.media == Base.encode64("mock audio content")
    end

    test "passes certainty option", %{base64_data: base64_data} do
      query =
        Query.get("Podcasts")
        |> Query.with_near_audio(base64_data, certainty: 0.7)

      assert query.near_media.certainty == 0.7
    end
  end

  describe "with_near_video/3" do
    test "builds query with base64 video data", %{base64_data: base64_data} do
      query =
        Query.get("Videos")
        |> Query.with_near_video(base64_data)

      assert %NearMedia{type: :video} = query.near_media
      assert query.near_media.media == base64_data
    end

    test "builds query with file path", %{video_path: video_path} do
      query =
        Query.get("Videos")
        |> Query.with_near_video(video_path)

      assert %NearMedia{type: :video} = query.near_media
      assert query.near_media.media == Base.encode64("mock video content")
    end

    test "passes distance option", %{base64_data: base64_data} do
      query =
        Query.get("Videos")
        |> Query.with_near_video(base64_data, distance: 0.3)

      assert query.near_media.distance == 0.3
    end
  end

  describe "with_near_thermal/3" do
    test "builds query with thermal data", %{base64_data: base64_data} do
      query =
        Query.get("ThermalImages")
        |> Query.with_near_thermal(base64_data)

      assert %NearMedia{type: :thermal} = query.near_media
      assert query.near_media.media == base64_data
    end

    test "passes target_vectors option", %{base64_data: base64_data} do
      query =
        Query.get("ThermalImages")
        |> Query.with_near_thermal(base64_data, target_vectors: ["thermal_vec"])

      assert query.near_media.target_vectors == ["thermal_vec"]
    end
  end

  describe "with_near_depth/3" do
    test "builds query with depth map data", %{base64_data: base64_data} do
      query =
        Query.get("DepthMaps")
        |> Query.with_near_depth(base64_data)

      assert %NearMedia{type: :depth} = query.near_media
      assert query.near_media.media == base64_data
    end

    test "passes certainty and distance options", %{base64_data: base64_data} do
      query =
        Query.get("DepthMaps")
        |> Query.with_near_depth(base64_data, certainty: 0.9, distance: 0.1)

      assert query.near_media.certainty == 0.9
      assert query.near_media.distance == 0.1
    end
  end

  describe "with_near_imu/3" do
    test "builds query with IMU data", %{base64_data: base64_data} do
      query =
        Query.get("SensorData")
        |> Query.with_near_imu(base64_data)

      assert %NearMedia{type: :imu} = query.near_media
      assert query.near_media.media == base64_data
    end
  end

  describe "with_near_media/4" do
    test "handles image type (uses NearImage)", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_media(:image, base64_data)

      assert %NearImage{} = query.near_image
      assert query.near_image.image == base64_data
      assert is_nil(query.near_media)
    end

    test "handles audio type (uses NearMedia)", %{base64_data: base64_data} do
      query =
        Query.get("Podcasts")
        |> Query.with_near_media(:audio, base64_data)

      assert %NearMedia{type: :audio} = query.near_media
      assert query.near_media.media == base64_data
      assert is_nil(query.near_image)
    end

    test "handles all non-image media types", %{base64_data: base64_data} do
      for type <- [:audio, :video, :thermal, :depth, :imu] do
        query =
          Query.get("Media")
          |> Query.with_near_media(type, base64_data)

        assert %NearMedia{type: ^type} = query.near_media,
               "Expected near_media type to be #{type}"
      end
    end

    test "rejects invalid media type", %{base64_data: base64_data} do
      assert_raise ArgumentError, ~r/Invalid media type/, fn ->
        Query.get("Products")
        |> Query.with_near_media(:invalid, base64_data)
      end
    end

    test "passes all options to underlying struct", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_media(:video, base64_data,
          certainty: 0.8,
          distance: 0.2,
          target_vectors: ["video_vec"]
        )

      assert query.near_media.certainty == 0.8
      assert query.near_media.distance == 0.2
      assert query.near_media.target_vectors == ["video_vec"]
    end
  end

  describe "error handling" do
    test "raises ArgumentError for non-existent file" do
      nonexistent_path = "/nonexistent/path/to/image.jpg"

      assert_raise ArgumentError, ~r/Failed to prepare media/, fn ->
        Query.get("Products")
        |> Query.with_near_image(nonexistent_path)
      end
    end
  end

  describe "chaining with other query methods" do
    test "chains with fields", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data)
        |> Query.fields(["name", "description"])

      assert query.fields == ["name", "description"]
      assert %NearImage{} = query.near_image
    end

    test "chains with limit and offset", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data)
        |> Query.limit(10)
        |> Query.offset(5)

      assert query.limit == 10
      assert query.offset == 5
    end

    test "chains with tenant", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data)
        |> Query.tenant("TenantA")

      assert query.tenant == "TenantA"
    end

    test "chains with additional metadata", %{base64_data: base64_data} do
      query =
        Query.get("Products")
        |> Query.with_near_image(base64_data, certainty: 0.8)
        |> Query.additional(["id", "distance", "certainty"])

      assert query.additional == ["id", "distance", "certainty"]
    end
  end
end
