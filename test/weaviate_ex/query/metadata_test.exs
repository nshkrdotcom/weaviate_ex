defmodule WeaviateEx.Query.MetadataTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.Metadata

  describe "full/0" do
    test "returns all metadata fields" do
      fields = Metadata.full()

      assert "id" in fields
      assert "creationTimeUnix" in fields
      assert "lastUpdateTimeUnix" in fields
      assert "distance" in fields
      assert "certainty" in fields
      assert "score" in fields
      assert "explainScore" in fields
      assert "isConsistent" in fields
    end
  end

  describe "select/1" do
    test "returns selected fields" do
      fields = Metadata.select(["id", "distance"])

      assert fields == ["id", "distance"]
    end
  end

  describe "common/0" do
    test "returns commonly used fields" do
      fields = Metadata.common()

      assert "id" in fields
      assert "distance" in fields
      assert "certainty" in fields
      assert "score" in fields
    end
  end

  describe "timestamps/0" do
    test "returns timestamp fields" do
      fields = Metadata.timestamps()

      assert "creationTimeUnix" in fields
      assert "lastUpdateTimeUnix" in fields
    end
  end

  describe "to_graphql/1" do
    test "converts metadata fields to graphql format" do
      fields = Metadata.select(["id", "distance"])
      graphql = Metadata.to_graphql(fields)

      assert graphql == "id distance"
    end

    test "converts full metadata to graphql format" do
      fields = Metadata.full()
      graphql = Metadata.to_graphql(fields)

      assert graphql =~ "id"
      assert graphql =~ "distance"
      assert graphql =~ "explainScore"
    end
  end
end
