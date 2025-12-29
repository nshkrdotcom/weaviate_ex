defmodule WeaviateEx.Types.GeoCoordinateTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.GeoCoordinate

  describe "new/2" do
    test "creates valid coordinate" do
      assert {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
      assert coord.latitude == 52.3676
      assert coord.longitude == 4.9041
    end

    test "creates coordinate at origin" do
      assert {:ok, coord} = GeoCoordinate.new(0.0, 0.0)
      assert coord.latitude == 0.0
      assert coord.longitude == 0.0
    end

    test "creates coordinate at minimum bounds" do
      assert {:ok, coord} = GeoCoordinate.new(-90.0, -180.0)
      assert coord.latitude == -90.0
      assert coord.longitude == -180.0
    end

    test "creates coordinate at maximum bounds" do
      assert {:ok, coord} = GeoCoordinate.new(90.0, 180.0)
      assert coord.latitude == 90.0
      assert coord.longitude == 180.0
    end

    test "accepts integers" do
      assert {:ok, coord} = GeoCoordinate.new(40, -74)
      assert coord.latitude == 40
      assert coord.longitude == -74
    end

    test "rejects latitude below minimum" do
      assert {:error, message} = GeoCoordinate.new(-91.0, 0.0)
      assert message =~ "Latitude must be between -90 and 90"
    end

    test "rejects latitude above maximum" do
      assert {:error, message} = GeoCoordinate.new(91.0, 0.0)
      assert message =~ "Latitude must be between -90 and 90"
    end

    test "rejects longitude below minimum" do
      assert {:error, message} = GeoCoordinate.new(0.0, -181.0)
      assert message =~ "Longitude must be between -180 and 180"
    end

    test "rejects longitude above maximum" do
      assert {:error, message} = GeoCoordinate.new(0.0, 181.0)
      assert message =~ "Longitude must be between -180 and 180"
    end

    test "rejects non-numeric latitude" do
      assert {:error, message} = GeoCoordinate.new("52.3676", 4.9041)
      assert message =~ "must be numbers"
    end

    test "rejects non-numeric longitude" do
      assert {:error, message} = GeoCoordinate.new(52.3676, "4.9041")
      assert message =~ "must be numbers"
    end
  end

  describe "new!/2" do
    test "creates valid coordinate" do
      coord = GeoCoordinate.new!(52.3676, 4.9041)
      assert coord.latitude == 52.3676
      assert coord.longitude == 4.9041
    end

    test "raises on invalid latitude" do
      assert_raise ArgumentError, fn ->
        GeoCoordinate.new!(91.0, 0.0)
      end
    end

    test "raises on invalid longitude" do
      assert_raise ArgumentError, fn ->
        GeoCoordinate.new!(0.0, 181.0)
      end
    end
  end

  describe "to_map/1" do
    test "converts to Weaviate API format" do
      {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)

      assert GeoCoordinate.to_map(coord) == %{
               "latitude" => 52.3676,
               "longitude" => 4.9041
             }
    end
  end

  describe "from_map/1" do
    test "parses from Weaviate API format" do
      map = %{"latitude" => 52.3676, "longitude" => 4.9041}

      assert {:ok, coord} = GeoCoordinate.from_map(map)
      assert coord.latitude == 52.3676
      assert coord.longitude == 4.9041
    end

    test "returns error for invalid format" do
      assert {:error, _} = GeoCoordinate.from_map(%{"lat" => 52.3676})
    end

    test "returns error for invalid values" do
      assert {:error, _} = GeoCoordinate.from_map(%{"latitude" => 91.0, "longitude" => 0.0})
    end
  end
end
