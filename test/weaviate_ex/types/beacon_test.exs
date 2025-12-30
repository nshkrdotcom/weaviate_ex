defmodule WeaviateEx.Types.BeaconTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.Beacon

  describe "parse/1" do
    test "parses beacon with collection and uuid" do
      result = Beacon.parse("weaviate://localhost/Person/550e8400-e29b-41d4-a716-446655440000")

      assert result.collection == "Person"
      assert result.uuid == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "parses beacon without collection (uuid only)" do
      result = Beacon.parse("weaviate://localhost/550e8400-e29b-41d4-a716-446655440000")

      assert result.collection == nil
      assert result.uuid == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "handles different collection names" do
      result = Beacon.parse("weaviate://localhost/Organization/abc-123")

      assert result.collection == "Organization"
      assert result.uuid == "abc-123"
    end

    test "handles invalid format gracefully" do
      result = Beacon.parse("invalid-beacon")

      assert result.collection == nil
      assert result.uuid == "invalid-beacon"
    end

    test "handles https URL format gracefully" do
      result = Beacon.parse("https://example.com/object/123")

      assert result.collection == nil
      assert result.uuid == "https://example.com/object/123"
    end

    test "handles empty string" do
      result = Beacon.parse("")

      assert result.collection == nil
      assert result.uuid == ""
    end
  end

  describe "build/2" do
    test "builds beacon from uuid only" do
      beacon = Beacon.build("550e8400-e29b-41d4-a716-446655440000")

      assert beacon == "weaviate://localhost/550e8400-e29b-41d4-a716-446655440000"
    end

    test "builds beacon with collection and uuid" do
      beacon = Beacon.build("550e8400-e29b-41d4-a716-446655440000", "Person")

      assert beacon == "weaviate://localhost/Person/550e8400-e29b-41d4-a716-446655440000"
    end

    test "builds beacon with nil collection (uuid only)" do
      beacon = Beacon.build("abc-123", nil)

      assert beacon == "weaviate://localhost/abc-123"
    end
  end

  describe "to_map/1 and to_map/2" do
    test "creates beacon map from uuid" do
      result = Beacon.to_map("550e8400-e29b-41d4-a716-446655440000")

      assert result == %{"beacon" => "weaviate://localhost/550e8400-e29b-41d4-a716-446655440000"}
    end

    test "creates beacon map with collection" do
      result = Beacon.to_map("550e8400-e29b-41d4-a716-446655440000", "Person")

      assert result == %{
               "beacon" => "weaviate://localhost/Person/550e8400-e29b-41d4-a716-446655440000"
             }
    end
  end

  describe "extract_uuid/1" do
    test "extracts uuid from full beacon" do
      {:ok, uuid} =
        Beacon.extract_uuid("weaviate://localhost/Person/550e8400-e29b-41d4-a716-446655440000")

      assert uuid == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "extracts uuid from beacon without collection" do
      {:ok, uuid} =
        Beacon.extract_uuid("weaviate://localhost/550e8400-e29b-41d4-a716-446655440000")

      assert uuid == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "returns error for invalid beacon" do
      {:error, reason} = Beacon.extract_uuid("not-a-beacon")

      assert reason =~ "Invalid"
    end
  end

  describe "extract_collection/1" do
    test "extracts collection from beacon with collection" do
      {:ok, collection} =
        Beacon.extract_collection(
          "weaviate://localhost/Person/550e8400-e29b-41d4-a716-446655440000"
        )

      assert collection == "Person"
    end

    test "returns error when beacon has no collection" do
      {:error, reason} =
        Beacon.extract_collection("weaviate://localhost/550e8400-e29b-41d4-a716-446655440000")

      assert reason =~ "No collection"
    end

    test "returns error for invalid beacon" do
      {:error, reason} = Beacon.extract_collection("not-a-beacon")

      assert reason =~ "Invalid"
    end
  end

  describe "valid?/1" do
    test "returns true for valid beacon with collection" do
      assert Beacon.valid?("weaviate://localhost/Person/uuid-123")
    end

    test "returns true for valid beacon without collection" do
      assert Beacon.valid?("weaviate://localhost/uuid-123")
    end

    test "returns false for invalid format" do
      refute Beacon.valid?("not-a-beacon")
    end

    test "returns false for empty string" do
      refute Beacon.valid?("")
    end

    test "returns false for https url" do
      refute Beacon.valid?("https://example.com/uuid")
    end
  end

  describe "roundtrip" do
    test "parse and build maintain data integrity with collection" do
      original = "weaviate://localhost/Person/abc-123"
      parsed = Beacon.parse(original)
      rebuilt = Beacon.build(parsed.uuid, parsed.collection)

      assert rebuilt == original
    end

    test "parse and build maintain data integrity without collection" do
      original = "weaviate://localhost/abc-123"
      parsed = Beacon.parse(original)
      rebuilt = Beacon.build(parsed.uuid, parsed.collection)

      assert rebuilt == original
    end
  end
end
