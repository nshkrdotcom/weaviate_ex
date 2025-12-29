defmodule WeaviateEx.Query.QueryReferenceTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.QueryReference

  describe "new/2" do
    test "creates reference with link_on only" do
      ref = QueryReference.new("hasAuthor")

      assert ref.link_on == "hasAuthor"
      assert ref.return_properties == nil
      assert ref.return_references == nil
      assert ref.include_vector == false
    end

    test "creates reference with return_properties" do
      ref = QueryReference.new("hasAuthor", return_properties: ["name", "bio"])

      assert ref.return_properties == ["name", "bio"]
    end

    test "creates reference with nested references" do
      nested = QueryReference.new("hasPublisher")
      ref = QueryReference.new("hasAuthor", return_references: [nested])

      assert ref.return_references == [nested]
    end

    test "creates reference with include_vector" do
      ref = QueryReference.new("hasAuthor", include_vector: true)

      assert ref.include_vector == true
    end

    test "creates reference with all options" do
      nested = QueryReference.new("hasPublisher", return_properties: ["name"])

      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name", "bio"],
          return_references: [nested],
          include_vector: true
        )

      assert ref.link_on == "hasAuthor"
      assert ref.return_properties == ["name", "bio"]
      assert ref.return_references == [nested]
      assert ref.include_vector == true
    end
  end

  describe "to_graphql/1" do
    test "converts simple reference to graphql" do
      ref = QueryReference.new("hasAuthor")
      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "hasAuthor"
    end

    test "converts reference with properties to graphql" do
      ref = QueryReference.new("hasAuthor", return_properties: ["name", "bio"])
      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "hasAuthor"
      assert graphql =~ "name"
      assert graphql =~ "bio"
    end

    test "converts nested reference to graphql" do
      nested = QueryReference.new("hasPublisher", return_properties: ["name"])

      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_references: [nested]
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "hasAuthor"
      assert graphql =~ "hasPublisher"
    end

    test "converts reference with include_vector to graphql" do
      ref = QueryReference.new("hasAuthor", return_properties: ["name"], include_vector: true)
      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "vector"
    end
  end
end
