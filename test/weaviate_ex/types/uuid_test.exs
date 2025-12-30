defmodule WeaviateEx.Types.UUIDTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.UUID

  describe "generate/0" do
    test "generates a valid UUID" do
      uuid = UUID.generate()
      assert UUID.valid?(uuid)
    end

    test "generates unique UUIDs" do
      uuid1 = UUID.generate()
      uuid2 = UUID.generate()
      assert uuid1 != uuid2
    end

    test "generates lowercase UUID" do
      uuid = UUID.generate()
      assert uuid == String.downcase(uuid)
    end

    test "generates UUID with correct format" do
      uuid = UUID.generate()
      parts = String.split(uuid, "-")
      assert length(parts) == 5
      assert String.length(Enum.at(parts, 0)) == 8
      assert String.length(Enum.at(parts, 1)) == 4
      assert String.length(Enum.at(parts, 2)) == 4
      assert String.length(Enum.at(parts, 3)) == 4
      assert String.length(Enum.at(parts, 4)) == 12
    end
  end

  describe "valid?/1" do
    test "returns true for valid lowercase UUID" do
      assert UUID.valid?("550e8400-e29b-41d4-a716-446655440000")
    end

    test "returns true for valid uppercase UUID" do
      assert UUID.valid?("550E8400-E29B-41D4-A716-446655440000")
    end

    test "returns true for valid mixed case UUID" do
      assert UUID.valid?("550e8400-E29B-41d4-A716-446655440000")
    end

    test "returns false for invalid format" do
      refute UUID.valid?("not-a-uuid")
      refute UUID.valid?("550e8400e29b41d4a716446655440000")
      refute UUID.valid?("550e8400-e29b-41d4-a716")
      refute UUID.valid?("")
    end

    test "returns false for UUID with wrong segment lengths" do
      refute UUID.valid?("550e840-e29b-41d4-a716-446655440000")
      refute UUID.valid?("550e8400-e29-41d4-a716-446655440000")
    end
  end

  describe "validate/1" do
    test "returns {:ok, normalized_uuid} for valid UUID" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.validate("550e8400-e29b-41d4-a716-446655440000")
    end

    test "normalizes to lowercase" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.validate("550E8400-E29B-41D4-A716-446655440000")
    end

    test "returns error for invalid UUID" do
      assert {:error, "Invalid UUID format: not-a-uuid"} = UUID.validate("not-a-uuid")
    end
  end

  describe "from_string/2" do
    test "generates deterministic UUID from namespace and name" do
      uuid1 = UUID.from_string("Article", "my-unique-id")
      uuid2 = UUID.from_string("Article", "my-unique-id")
      assert uuid1 == uuid2
    end

    test "generates different UUIDs for different names" do
      uuid1 = UUID.from_string("Article", "id-1")
      uuid2 = UUID.from_string("Article", "id-2")
      assert uuid1 != uuid2
    end

    test "generates different UUIDs for different namespaces" do
      uuid1 = UUID.from_string("Article", "my-id")
      uuid2 = UUID.from_string("Post", "my-id")
      assert uuid1 != uuid2
    end

    test "generates valid UUID format" do
      uuid = UUID.from_string("Article", "my-id")
      assert UUID.valid?(uuid)
    end
  end

  describe "extract_from_beacon/1" do
    test "extracts UUID from simple beacon URL" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.extract_from_beacon(
                 "weaviate://localhost/550e8400-e29b-41d4-a716-446655440000"
               )
    end

    test "extracts UUID from beacon URL with collection" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.extract_from_beacon(
                 "weaviate://localhost/Article/550e8400-e29b-41d4-a716-446655440000"
               )
    end

    test "normalizes UUID to lowercase" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.extract_from_beacon(
                 "weaviate://localhost/550E8400-E29B-41D4-A716-446655440000"
               )
    end

    test "returns error for invalid beacon URL" do
      assert {:error, _} = UUID.extract_from_beacon("https://example.com/uuid")
    end

    test "returns error for invalid UUID in beacon" do
      assert {:error, _} = UUID.extract_from_beacon("weaviate://localhost/not-a-valid-uuid")
    end

    test "returns error for empty path" do
      assert {:error, _} = UUID.extract_from_beacon("weaviate://localhost/")
    end

    test "extracts UUID from deeply nested beacon URL" do
      # Some older Weaviate versions may have multiple path segments
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               UUID.extract_from_beacon(
                 "weaviate://localhost/Article/Author/550e8400-e29b-41d4-a716-446655440000"
               )
    end
  end
end
