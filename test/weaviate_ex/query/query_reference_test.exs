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

    test "creates reference with return_metadata as list" do
      ref = QueryReference.new("hasAuthor", return_metadata: [:uuid, :distance])

      assert ref.return_metadata == [:uuid, :distance]
    end

    test "creates reference with return_metadata as :full" do
      ref = QueryReference.new("hasAuthor", return_metadata: :full)

      assert ref.return_metadata == :full
    end

    test "creates reference with return_metadata as :common" do
      ref = QueryReference.new("hasAuthor", return_metadata: :common)

      assert ref.return_metadata == :common
    end

    test "creates reference with all options" do
      nested = QueryReference.new("hasPublisher", return_properties: ["name"])

      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name", "bio"],
          return_references: [nested],
          return_metadata: [:uuid, :distance],
          include_vector: true
        )

      assert ref.link_on == "hasAuthor"
      assert ref.return_properties == ["name", "bio"]
      assert ref.return_references == [nested]
      assert ref.return_metadata == [:uuid, :distance]
      assert ref.include_vector == true
    end
  end

  describe "multi_target/3" do
    test "creates multi-target reference query" do
      ref = QueryReference.multi_target("relatedTo", "Article", return_properties: ["title"])

      assert ref.link_on == "relatedTo"
      assert ref.target_collection == "Article"
      assert ref.return_properties == ["title"]
    end

    test "different targets for same property" do
      article_ref =
        QueryReference.multi_target("relatedTo", "Article", return_properties: ["title"])

      author_ref = QueryReference.multi_target("relatedTo", "Author", return_properties: ["name"])

      assert article_ref.target_collection == "Article"
      assert author_ref.target_collection == "Author"
    end

    test "supports return_metadata option" do
      ref =
        QueryReference.multi_target("mentions", "Person",
          return_properties: ["name"],
          return_metadata: :full
        )

      assert ref.return_metadata == :full
    end

    test "supports nested references" do
      inner_ref = QueryReference.new("worksAt", return_properties: ["companyName"])

      ref =
        QueryReference.multi_target("mentions", "Person",
          return_properties: ["name"],
          return_references: [inner_ref]
        )

      assert length(ref.return_references) == 1
      assert hd(ref.return_references).link_on == "worksAt"
    end
  end

  describe "multi_target?/1" do
    test "returns true for multi-target reference" do
      ref = QueryReference.multi_target("relatedTo", "Article")

      assert QueryReference.multi_target?(ref) == true
    end

    test "returns false for regular reference" do
      ref = QueryReference.new("hasAuthor")

      assert QueryReference.multi_target?(ref) == false
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

    test "converts multi-target reference to graphql" do
      ref = QueryReference.multi_target("relatedTo", "Article", return_properties: ["title"])
      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "relatedTo"
      assert graphql =~ "Article"
      assert graphql =~ "title"
    end

    test "includes return_metadata fields in graphql" do
      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_metadata: [:uuid, :distance, :certainty]
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "_additional"
      assert graphql =~ "id"
      assert graphql =~ "distance"
      assert graphql =~ "certainty"
    end

    test "includes :full metadata fields" do
      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_metadata: :full
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "creationTimeUnix"
      assert graphql =~ "lastUpdateTimeUnix"
    end

    test "includes :common metadata fields" do
      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_metadata: :common
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "id"
      assert graphql =~ "distance"
      assert graphql =~ "certainty"
      assert graphql =~ "score"
    end

    test "combines return_metadata and include_vector" do
      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_metadata: [:uuid, :distance],
          include_vector: true
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "id"
      assert graphql =~ "distance"
      assert graphql =~ "vector"
    end

    test "handles creation_time metadata field" do
      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_metadata: [:creation_time, :last_update_time]
        )

      graphql = QueryReference.to_graphql(ref)

      assert graphql =~ "creationTimeUnix"
      assert graphql =~ "lastUpdateTimeUnix"
    end
  end
end
