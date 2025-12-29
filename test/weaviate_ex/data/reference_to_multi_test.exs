defmodule WeaviateEx.Data.ReferenceToMultiTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Data.ReferenceToMulti

  describe "new/2" do
    test "creates reference with single uuid" do
      ref = ReferenceToMulti.new("Category", "cat-uuid")

      assert ref.target_collection == "Category"
      assert ref.uuids == "cat-uuid"
    end

    test "creates reference with multiple uuids" do
      ref = ReferenceToMulti.new("Category", ["uuid1", "uuid2"])

      assert ref.target_collection == "Category"
      assert ref.uuids == ["uuid1", "uuid2"]
    end
  end

  describe "to_beacons/1" do
    test "converts single uuid to beacon list" do
      ref = ReferenceToMulti.new("Category", "cat-uuid")
      beacons = ReferenceToMulti.to_beacons(ref)

      assert beacons == [%{"beacon" => "weaviate://localhost/Category/cat-uuid"}]
    end

    test "converts multiple uuids to beacon list" do
      ref = ReferenceToMulti.new("Category", ["uuid1", "uuid2"])
      beacons = ReferenceToMulti.to_beacons(ref)

      assert length(beacons) == 2
      assert Enum.at(beacons, 0) == %{"beacon" => "weaviate://localhost/Category/uuid1"}
      assert Enum.at(beacons, 1) == %{"beacon" => "weaviate://localhost/Category/uuid2"}
    end
  end

  describe "to_map/1" do
    test "converts to map format" do
      ref = ReferenceToMulti.new("Category", "cat-uuid")
      map = ReferenceToMulti.to_map(ref)

      assert map == %{target_collection: "Category", uuids: "cat-uuid"}
    end
  end
end
