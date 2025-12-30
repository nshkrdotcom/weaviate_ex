defmodule WeaviateEx.Types.SerializableTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.{Blob, GeoCoordinate, PhoneNumber, Serializable}

  describe "DateTime serialization" do
    test "serializes DateTime to ISO8601" do
      dt = ~U[2024-01-01 12:30:45.123456Z]
      assert Serializable.serialize(dt) == "2024-01-01T12:30:45.123456Z"
    end

    test "serializes DateTime with different timezones" do
      dt = ~U[2024-12-31 23:59:59Z]
      assert Serializable.serialize(dt) == "2024-12-31T23:59:59Z"
    end

    test "handles DateTime at epoch" do
      dt = ~U[1970-01-01 00:00:00Z]
      assert Serializable.serialize(dt) == "1970-01-01T00:00:00Z"
    end
  end

  describe "NaiveDateTime serialization" do
    test "serializes NaiveDateTime to ISO8601 without Z suffix" do
      dt = ~N[2024-01-01 12:30:45.123456]
      assert Serializable.serialize(dt) == "2024-01-01T12:30:45.123456"
    end

    test "serializes NaiveDateTime without microseconds" do
      dt = ~N[2024-06-15 08:00:00]
      assert Serializable.serialize(dt) == "2024-06-15T08:00:00"
    end
  end

  describe "Date serialization" do
    test "serializes Date as midnight UTC" do
      d = ~D[2024-01-01]
      assert Serializable.serialize(d) == "2024-01-01T00:00:00Z"
    end

    test "serializes Date at end of year" do
      d = ~D[2024-12-31]
      assert Serializable.serialize(d) == "2024-12-31T00:00:00Z"
    end

    test "handles leap year dates" do
      d = ~D[2024-02-29]
      assert Serializable.serialize(d) == "2024-02-29T00:00:00Z"
    end
  end

  describe "GeoCoordinate serialization" do
    test "serializes to latitude/longitude map" do
      {:ok, geo} = GeoCoordinate.new(52.3676, 4.9041)
      result = Serializable.serialize(geo)

      assert result == %{"latitude" => 52.3676, "longitude" => 4.9041}
    end

    test "preserves float precision" do
      {:ok, geo} = GeoCoordinate.new(40.7127753, -74.0059728)
      result = Serializable.serialize(geo)

      assert result["latitude"] == 40.7127753
      assert result["longitude"] == -74.0059728
    end

    test "handles negative coordinates" do
      {:ok, geo} = GeoCoordinate.new(-33.8688, 151.2093)
      result = Serializable.serialize(geo)

      assert result == %{"latitude" => -33.8688, "longitude" => 151.2093}
    end

    test "handles zero coordinates" do
      {:ok, geo} = GeoCoordinate.new(0.0, 0.0)
      result = Serializable.serialize(geo)

      assert result == %{"latitude" => 0.0, "longitude" => 0.0}
    end

    test "handles boundary coordinates" do
      {:ok, geo} = GeoCoordinate.new(90.0, 180.0)
      result = Serializable.serialize(geo)

      assert result == %{"latitude" => 90.0, "longitude" => 180.0}
    end
  end

  describe "PhoneNumber serialization" do
    test "serializes with input only when no country" do
      phone = PhoneNumber.new("+1 650-253-0000")
      result = Serializable.serialize(phone)

      assert result == %{"input" => "+1 650-253-0000"}
    end

    test "serializes with input and defaultCountry" do
      phone = PhoneNumber.new("650-253-0000", default_country: "US")
      result = Serializable.serialize(phone)

      assert result == %{"input" => "650-253-0000", "defaultCountry" => "US"}
    end

    test "handles international format" do
      phone = PhoneNumber.new("+49 30 12345678", default_country: "DE")
      result = Serializable.serialize(phone)

      assert result == %{"input" => "+49 30 12345678", "defaultCountry" => "DE"}
    end

    test "handles nil country code" do
      phone = %PhoneNumber{number: "555-1234", default_country: nil}
      result = Serializable.serialize(phone)

      assert result == %{"input" => "555-1234"}
    end
  end

  describe "Blob serialization" do
    test "base64 encodes binary data" do
      blob = Blob.new("Hello, World!")
      result = Serializable.serialize(blob)

      assert result == "SGVsbG8sIFdvcmxkIQ=="
    end

    test "handles empty binary" do
      blob = Blob.new("")
      result = Serializable.serialize(blob)

      assert result == ""
    end

    test "handles binary with special characters" do
      blob = Blob.new(<<0, 1, 2, 3, 255, 254, 253>>)
      result = Serializable.serialize(blob)

      # Verify it's valid base64 by decoding
      {:ok, decoded} = Base.decode64(result)
      assert decoded == <<0, 1, 2, 3, 255, 254, 253>>
    end

    test "handles nil data" do
      blob = %Blob{data: nil}
      result = Serializable.serialize(blob)

      assert result == nil
    end

    test "handles large binary data" do
      # 1KB of random-ish data
      data = :crypto.strong_rand_bytes(1024)
      blob = Blob.new(data)
      result = Serializable.serialize(blob)

      # Verify roundtrip
      {:ok, decoded} = Base.decode64(result)
      assert decoded == data
    end
  end
end
