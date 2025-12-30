defmodule WeaviateEx.Types.DeserializeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.{Blob, Deserialize, GeoCoordinate, PhoneNumber}

  describe "DateTime deserialization" do
    test "parses ISO8601 string to DateTime" do
      {:ok, result} = Deserialize.deserialize("2024-01-01T12:30:45Z", :date)

      assert result == ~U[2024-01-01 12:30:45Z]
    end

    test "parses ISO8601 with microseconds" do
      {:ok, result} = Deserialize.deserialize("2024-01-01T12:30:45.123456Z", :date)

      assert result == ~U[2024-01-01 12:30:45.123456Z]
    end

    test "handles timezone offsets" do
      {:ok, result} = Deserialize.deserialize("2024-01-01T12:30:45+02:00", :date)

      # DateTime.from_iso8601 normalizes to UTC
      assert result.hour == 10
      assert result.utc_offset == 0
    end

    test "parses NaiveDateTime when no timezone" do
      {:ok, result} = Deserialize.deserialize("2024-01-01T12:30:45", :date)

      assert result == ~N[2024-01-01 12:30:45]
    end

    test "returns error for invalid date string" do
      {:error, reason} = Deserialize.deserialize("not-a-date", :date)

      assert reason =~ "Failed to parse date"
    end

    test "handles nil value" do
      {:ok, result} = Deserialize.deserialize(nil, :date)

      assert result == nil
    end
  end

  describe "GeoCoordinate deserialization" do
    test "converts map to GeoCoordinate struct (string keys)" do
      {:ok, result} =
        Deserialize.deserialize(
          %{"latitude" => 52.3676, "longitude" => 4.9041},
          :geo_coordinates
        )

      assert %GeoCoordinate{latitude: 52.3676, longitude: 4.9041} = result
    end

    test "converts map to GeoCoordinate struct (atom keys)" do
      {:ok, result} =
        Deserialize.deserialize(
          %{latitude: 40.7128, longitude: -74.0060},
          :geo_coordinates
        )

      assert %GeoCoordinate{latitude: 40.7128, longitude: -74.0060} = result
    end

    test "preserves float precision" do
      {:ok, result} =
        Deserialize.deserialize(
          %{"latitude" => 40.7127753, "longitude" => -74.0059728},
          :geo_coordinates
        )

      assert result.latitude == 40.7127753
      assert result.longitude == -74.0059728
    end

    test "handles negative coordinates" do
      {:ok, result} =
        Deserialize.deserialize(
          %{"latitude" => -33.8688, "longitude" => 151.2093},
          :geo_coordinates
        )

      assert result.latitude == -33.8688
      assert result.longitude == 151.2093
    end
  end

  describe "PhoneNumber deserialization" do
    test "parses phone number response to Output struct" do
      input = %{
        "input" => "+1 650-253-0000",
        "valid" => true,
        "countryCode" => 1,
        "internationalFormatted" => "+1 650-253-0000"
      }

      {:ok, result} = Deserialize.deserialize(input, :phone_number)

      assert %PhoneNumber.Output{} = result
      assert result.input == "+1 650-253-0000"
      assert result.valid == true
      assert result.country_code == 1
    end

    test "handles minimal phone response" do
      {:ok, result} = Deserialize.deserialize(%{"input" => "555-1234"}, :phone_number)

      assert result.input == "555-1234"
    end
  end

  describe "Blob deserialization" do
    test "decodes base64 string to Blob struct" do
      {:ok, result} = Deserialize.deserialize("SGVsbG8sIFdvcmxkIQ==", :blob)

      assert %Blob{data: "Hello, World!"} = result
    end

    test "handles empty base64" do
      {:ok, result} = Deserialize.deserialize("", :blob)

      assert %Blob{data: ""} = result
    end

    test "returns error for invalid base64" do
      result = Deserialize.deserialize("not-valid-base64!!!", :blob)

      assert result == :error
    end
  end

  describe "auto deserialization" do
    test "detects geo coordinates" do
      {:ok, result} =
        Deserialize.deserialize(
          %{"latitude" => 52.37, "longitude" => 4.90},
          :auto
        )

      assert %GeoCoordinate{} = result
    end

    test "detects phone number response" do
      {:ok, result} =
        Deserialize.deserialize(
          %{"input" => "+1 555-1234", "valid" => true},
          :auto
        )

      assert %PhoneNumber.Output{} = result
    end

    test "detects ISO8601 date string" do
      {:ok, result} = Deserialize.deserialize("2024-01-01T00:00:00Z", :auto)

      assert %DateTime{} = result
    end

    test "passes through primitives unchanged" do
      {:ok, string} = Deserialize.deserialize("hello", :auto)
      {:ok, number} = Deserialize.deserialize(42, :auto)
      {:ok, bool} = Deserialize.deserialize(true, :auto)

      assert string == "hello"
      assert number == 42
      assert bool == true
    end
  end

  describe "deserialize_properties/2" do
    test "deserializes multiple properties with schema" do
      props = %{
        "created_at" => "2024-01-01T00:00:00Z",
        "location" => %{"latitude" => 52.37, "longitude" => 4.90},
        "title" => "Test Article"
      }

      schema = %{
        "created_at" => :date,
        "location" => :geo_coordinates
      }

      {:ok, result} = Deserialize.deserialize_properties(props, schema)

      assert %DateTime{} = result["created_at"]
      assert %GeoCoordinate{} = result["location"]
      assert result["title"] == "Test Article"
    end

    test "passes through properties without schema hint" do
      props = %{"title" => "Hello", "count" => 42}
      schema = %{}

      {:ok, result} = Deserialize.deserialize_properties(props, schema)

      assert result["title"] == "Hello"
      assert result["count"] == 42
    end

    test "returns error on deserialization failure" do
      props = %{"date" => "not-a-date"}
      schema = %{"date" => :date}

      {:error, reason} = Deserialize.deserialize_properties(props, schema)

      assert reason =~ "Error deserializing date"
    end
  end

  describe "auto_deserialize/1" do
    test "auto-deserializes all properties" do
      props = %{
        "created_at" => "2024-01-01T00:00:00Z",
        "location" => %{"latitude" => 52.37, "longitude" => 4.90},
        "phone" => %{"input" => "+1 555-1234"},
        "title" => "Plain string"
      }

      {:ok, result} = Deserialize.auto_deserialize(props)

      assert %DateTime{} = result["created_at"]
      assert %GeoCoordinate{} = result["location"]
      assert %PhoneNumber.Output{} = result["phone"]
      assert result["title"] == "Plain string"
    end
  end

  describe "deserialize!/2" do
    test "returns value on success" do
      result = Deserialize.deserialize!("2024-01-01T00:00:00Z", :date)

      assert %DateTime{} = result
    end

    test "raises on failure" do
      assert_raise ArgumentError, ~r/Failed to parse date/, fn ->
        Deserialize.deserialize!("not-a-date", :date)
      end
    end
  end

  describe "deserialize_properties!/2" do
    test "returns map on success" do
      props = %{"date" => "2024-01-01T00:00:00Z"}
      schema = %{"date" => :date}

      result = Deserialize.deserialize_properties!(props, schema)

      assert %DateTime{} = result["date"]
    end

    test "raises on failure" do
      props = %{"date" => "invalid"}
      schema = %{"date" => :date}

      assert_raise ArgumentError, ~r/Error deserializing date/, fn ->
        Deserialize.deserialize_properties!(props, schema)
      end
    end
  end
end
