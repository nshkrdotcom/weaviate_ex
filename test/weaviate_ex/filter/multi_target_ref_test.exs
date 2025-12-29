defmodule WeaviateEx.Filter.MultiTargetRefTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Filter
  alias WeaviateEx.Filter.MultiTargetRef
  alias WeaviateEx.Filter.RefPath

  describe "new/2" do
    test "creates multi-target reference filter config" do
      ref = MultiTargetRef.new("relatedTo", "Article")

      assert ref.property == "relatedTo"
      assert ref.target == "Article"
    end
  end

  describe "where/4" do
    test "creates filter for specific target collection" do
      filter =
        MultiTargetRef.new("relatedTo", "Article")
        |> MultiTargetRef.where("title", :equal, "Test Article")

      assert filter[:path] == ["relatedTo", "Article", "title"]
      assert filter[:target_collection] == "Article"
      assert filter[:operator] == :equal
      assert filter[:value_text] == "Test Article"
    end

    test "can filter different target collections" do
      article_filter =
        MultiTargetRef.new("relatedTo", "Article")
        |> MultiTargetRef.where("title", :like, "Tech*")

      author_filter =
        MultiTargetRef.new("relatedTo", "Author")
        |> MultiTargetRef.where("name", :equal, "John")

      assert article_filter[:target_collection] == "Article"
      assert author_filter[:target_collection] == "Author"
    end

    test "supports integer values" do
      filter =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.where("age", :greater_than, 30)

      assert filter[:value_int] == 30
    end

    test "supports boolean values" do
      filter =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.where("verified", :equal, true)

      assert filter[:value_boolean] == true
    end

    test "supports float values" do
      filter =
        MultiTargetRef.new("relatedTo", "Product")
        |> MultiTargetRef.where("price", :less_than, 99.99)

      assert filter[:value_number] == 99.99
    end
  end

  describe "deep_where/2" do
    test "supports deep paths into multi-target reference" do
      filter =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.deep_where(fn path ->
          path
          |> RefPath.through("worksAt", "Company")
          |> RefPath.property("name", :equal, "Acme")
        end)

      assert filter[:path] == ["mentions", "Person", "worksAt", "Company", "name"]
      assert filter[:target_collection] == "Person"
    end

    test "supports multi-level deep paths" do
      filter =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.deep_where(fn path ->
          path
          |> RefPath.through("worksAt", "Company")
          |> RefPath.through("locatedIn", "City")
          |> RefPath.property("population", :greater_than, 1_000_000)
        end)

      assert filter[:path] == [
               "mentions",
               "Person",
               "worksAt",
               "Company",
               "locatedIn",
               "City",
               "population"
             ]
    end
  end

  describe "as_ref_path/1" do
    test "converts to RefPath for chaining" do
      ref_path =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.as_ref_path()

      assert %RefPath{} = ref_path
      assert ref_path.segments == [{"mentions", "Person"}]
    end

    test "allows chaining with RefPath functions" do
      filter =
        MultiTargetRef.new("mentions", "Person")
        |> MultiTargetRef.as_ref_path()
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("name", :equal, "Acme")

      assert filter[:path] == ["mentions", "Person", "worksAt", "Company", "name"]
    end
  end

  describe "integration with Filter combinators" do
    test "combines multi-target ref filters with AND" do
      article_filter =
        MultiTargetRef.new("relatedTo", "Article")
        |> MultiTargetRef.where("status", :equal, "published")

      person_filter =
        MultiTargetRef.new("relatedTo", "Person")
        |> MultiTargetRef.where("verified", :equal, true)

      combined = Filter.all_of([article_filter, person_filter])

      assert combined[:operator] == :and
      assert length(combined[:operands]) == 2
    end

    test "combines with regular filters" do
      ref_filter =
        MultiTargetRef.new("mentions", "Organization")
        |> MultiTargetRef.where("name", :like, "Acme*")

      status_filter = Filter.equal("status", "active")

      combined = Filter.all_of([ref_filter, status_filter])

      assert combined[:operator] == :and
    end
  end

  describe "to_graphql/1 conversion" do
    test "converts multi-target ref filter to GraphQL" do
      filter =
        MultiTargetRef.new("relatedTo", "Author")
        |> MultiTargetRef.where("verified", :equal, true)

      gql = Filter.to_graphql(filter)

      assert gql[:path] == ["relatedTo", "Author", "verified"]
      assert gql[:operator] == "Equal"
      assert gql[:valueBoolean] == true
    end

    test "converts deep multi-target filter to GraphQL" do
      filter =
        MultiTargetRef.new("mentions", "Organization")
        |> MultiTargetRef.deep_where(fn path ->
          path
          |> RefPath.through("locatedIn", "City")
          |> RefPath.property("name", :like, "New*")
        end)

      gql = Filter.to_graphql(filter)

      assert gql[:path] == ["mentions", "Organization", "locatedIn", "City", "name"]
      assert gql[:operator] == "Like"
    end
  end
end
