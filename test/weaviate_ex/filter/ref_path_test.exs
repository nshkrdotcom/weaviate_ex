defmodule WeaviateEx.Filter.RefPathTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Filter
  alias WeaviateEx.Filter.RefPath

  describe "through/2" do
    test "creates single-level reference path" do
      path = RefPath.through("hasAuthor", "Author")

      assert path.segments == [{"hasAuthor", "Author"}]
    end

    test "chains multiple reference levels" do
      path =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")

      assert path.segments == [
               {"hasAuthor", "Author"},
               {"worksAt", "Company"}
             ]
    end

    test "chains three levels deep" do
      path =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.through("locatedIn", "City")

      assert length(path.segments) == 3
    end
  end

  describe "property/4" do
    test "terminates path with property filter" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("name", :equal, "John")

      assert filter[:path] == ["hasAuthor", "Author", "name"]
      assert filter[:operator] == :equal
      assert filter[:value_text] == "John"
    end

    test "deep path to property" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("name", :equal, "Acme Inc")

      assert filter[:path] == ["hasAuthor", "Author", "worksAt", "Company", "name"]
    end

    test "supports integer values" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("age", :greater_than, 30)

      assert filter[:value_int] == 30
    end

    test "supports boolean values" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("verified", :equal, true)

      assert filter[:value_boolean] == true
    end

    test "supports float values" do
      filter =
        RefPath.through("hasProduct", "Product")
        |> RefPath.property("price", :less_than, 99.99)

      assert filter[:value_number] == 99.99
    end

    test "supports string array values" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("tags", :contains_any, ["tech", "science"])

      assert filter[:value_text_array] == ["tech", "science"]
    end
  end

  describe "build_path/2" do
    test "builds path from segments and property" do
      segments = [{"hasAuthor", "Author"}, {"worksAt", "Company"}]
      path = RefPath.build_path(segments, "industry")

      assert path == ["hasAuthor", "Author", "worksAt", "Company", "industry"]
    end

    test "handles single segment" do
      segments = [{"hasAuthor", "Author"}]
      path = RefPath.build_path(segments, "name")

      assert path == ["hasAuthor", "Author", "name"]
    end
  end

  describe "to_path/1" do
    test "returns path without final property" do
      ref_path = RefPath.through("hasAuthor", "Author")
      path = RefPath.to_path(ref_path)

      assert path == ["hasAuthor", "Author"]
    end

    test "returns deep path" do
      ref_path =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")

      path = RefPath.to_path(ref_path)

      assert path == ["hasAuthor", "Author", "worksAt", "Company"]
    end
  end

  describe "depth/1" do
    test "returns depth of single reference" do
      path = RefPath.through("hasAuthor", "Author")

      assert RefPath.depth(path) == 1
    end

    test "returns depth of multiple references" do
      path =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.through("locatedIn", "City")

      assert RefPath.depth(path) == 3
    end
  end

  describe "integration with Filter combinators" do
    test "combines ref path filter with AND" do
      author_filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("verified", :equal, true)

      category_filter = Filter.equal("category", "tech")

      combined = Filter.all_of([author_filter, category_filter])

      assert combined[:operator] == :and
      assert length(combined[:operands]) == 2
    end

    test "combines ref path filter with OR" do
      tech_author =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("industry", :equal, "Technology")

      science_author =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("industry", :equal, "Science")

      combined = Filter.any_of([tech_author, science_author])

      assert combined[:operator] == :or
    end

    test "nested ref path filters" do
      filter =
        Filter.all_of([
          RefPath.through("hasAuthor", "Author")
          |> RefPath.property("verified", :equal, true),
          RefPath.through("hasCategory", "Category")
          |> RefPath.property("name", :equal, "Tech")
        ])

      assert filter[:operator] == :and
      assert length(filter[:operands]) == 2

      [author_filter, category_filter] = filter[:operands]
      assert author_filter[:path] == ["hasAuthor", "Author", "verified"]
      assert category_filter[:path] == ["hasCategory", "Category", "name"]
    end
  end

  describe "to_graphql/1 conversion" do
    test "converts ref path filter to GraphQL" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.property("name", :equal, "John")

      gql = Filter.to_graphql(filter)

      assert gql[:path] == ["hasAuthor", "Author", "name"]
      assert gql[:operator] == "Equal"
      assert gql[:valueText] == "John"
    end

    test "converts deep ref path filter to GraphQL" do
      filter =
        RefPath.through("hasAuthor", "Author")
        |> RefPath.through("worksAt", "Company")
        |> RefPath.property("industry", :equal, "Technology")

      gql = Filter.to_graphql(filter)

      assert gql[:path] == ["hasAuthor", "Author", "worksAt", "Company", "industry"]
    end
  end
end
