defmodule WeaviateEx.Types.ReferenceTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.Reference

  describe "to/3" do
    test "creates reference with collection and id" do
      ref = Reference.to("Author", "uuid-123")

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == []
    end

    test "creates reference with target vectors" do
      ref = Reference.to("Author", "uuid-123", target_vectors: ["title_vector", "content_vector"])

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == ["title_vector", "content_vector"]
    end
  end

  describe "multi_target/3" do
    test "creates reference with target vectors" do
      ref = Reference.multi_target("Author", "uuid-123", ["title_vector", "content_vector"])

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == ["title_vector", "content_vector"]
    end
  end

  describe "from_beacon/1" do
    test "creates reference from beacon with collection" do
      ref = Reference.from_beacon("weaviate://localhost/Author/uuid-123")

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == []
    end

    test "creates reference from beacon without collection" do
      ref = Reference.from_beacon("weaviate://localhost/uuid-123")

      assert ref.beacon == "weaviate://localhost/uuid-123"
      assert ref.target_collection == nil
      assert ref.target_vectors == []
    end
  end

  describe "from_map/1" do
    test "creates reference from API response map with collection" do
      ref = Reference.from_map(%{"beacon" => "weaviate://localhost/Author/uuid-123"})

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == []
    end

    test "creates reference from API response map without collection" do
      ref = Reference.from_map(%{"beacon" => "weaviate://localhost/uuid-123"})

      assert ref.beacon == "weaviate://localhost/uuid-123"
      assert ref.target_collection == nil
      assert ref.target_vectors == []
    end

    test "creates reference with target vectors from API response" do
      ref =
        Reference.from_map(%{
          "beacon" => "weaviate://localhost/Author/uuid-123",
          "targetVectors" => ["title_vector"]
        })

      assert ref.beacon == "weaviate://localhost/Author/uuid-123"
      assert ref.target_collection == "Author"
      assert ref.target_vectors == ["title_vector"]
    end
  end

  describe "to_map/1" do
    test "converts reference to map without target vectors" do
      ref = Reference.to("Author", "uuid-123")
      map = Reference.to_map(ref)

      assert map == %{"beacon" => "weaviate://localhost/Author/uuid-123"}
    end

    test "converts reference to map with target vectors" do
      ref = Reference.to("Author", "uuid-123", target_vectors: ["title_vector"])
      map = Reference.to_map(ref)

      assert map == %{
               "beacon" => "weaviate://localhost/Author/uuid-123",
               "targetVectors" => ["title_vector"]
             }
    end
  end

  describe "extract_id/1" do
    test "extracts id from reference" do
      ref = Reference.to("Author", "550e8400-e29b-41d4-a716-446655440000")
      {:ok, id} = Reference.extract_id(ref)

      assert id == "550e8400-e29b-41d4-a716-446655440000"
    end
  end

  describe "extract_collection/1" do
    test "extracts collection from reference with target_collection" do
      ref = Reference.to("Author", "uuid-123")
      {:ok, collection} = Reference.extract_collection(ref)

      assert collection == "Author"
    end

    test "extracts collection from beacon when target_collection is nil" do
      ref = %Reference{beacon: "weaviate://localhost/Author/uuid-123", target_collection: nil}
      {:ok, collection} = Reference.extract_collection(ref)

      assert collection == "Author"
    end

    test "returns error when no collection in beacon" do
      ref = %Reference{beacon: "weaviate://localhost/uuid-123", target_collection: nil}
      {:error, _reason} = Reference.extract_collection(ref)
    end
  end
end
