defmodule WeaviateEx.Query.IntegrationTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query
  alias WeaviateEx.Query.GroupBy
  alias WeaviateEx.Query.Rerank

  describe "rerank/2 integration" do
    test "adds rerank to query struct" do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.near_text("machine learning")
        |> Query.rerank(rerank)

      assert query.rerank == rerank
    end

    test "rerank config is correctly stored" do
      rerank = Rerank.new("content", query: "What is AI?")

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.near_text("machine learning")
        |> Query.rerank(rerank)
        |> Query.additional(["id"])

      # Verify the rerank config is properly attached
      assert query.rerank.prop == "content"
      assert query.rerank.query == "What is AI?"

      # Verify the to_graphql output contains expected parts
      graphql_fragment = Rerank.to_graphql(query.rerank)
      assert graphql_fragment =~ "content"
      assert graphql_fragment =~ "What is AI?"
    end

    test "rerank works with near_vector" do
      rerank = Rerank.new("description")

      query =
        Query.get("Article")
        |> Query.near_vector([0.1, 0.2, 0.3])
        |> Query.rerank(rerank)

      assert query.rerank.prop == "description"
      assert query.near_vector.vector == [0.1, 0.2, 0.3]
    end

    test "rerank works with hybrid search" do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning", alpha: 0.7)
        |> Query.rerank(rerank)

      assert query.rerank.prop == "content"
      assert query.hybrid.alpha == 0.7
    end

    test "rerank works with bm25 search" do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.bm25("machine learning")
        |> Query.rerank(rerank)

      assert query.rerank.prop == "content"
      assert query.bm25.query == "machine learning"
    end
  end

  describe "group_by/2 integration" do
    test "adds group_by to query struct" do
      group_by = GroupBy.new("category")

      query =
        Query.get("Article")
        |> Query.near_text("machine learning")
        |> Query.group_by(group_by)

      assert query.group_by == group_by
    end

    test "group_by config is correctly stored" do
      group_by = GroupBy.new("category", objects_per_group: 5, number_of_groups: 10)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.near_text("machine learning")
        |> Query.group_by(group_by)

      # Verify the group_by config is properly attached
      assert query.group_by.path == "category"
      assert query.group_by.objects_per_group == 5
      assert query.group_by.number_of_groups == 10

      # Verify to_graphql produces expected output
      graphql_fragment = GroupBy.to_graphql(query.group_by)
      assert graphql_fragment =~ "category"
      assert graphql_fragment =~ "objectsPerGroup: 5"
      assert graphql_fragment =~ "groups: 10"
    end

    test "group_by works with nested path" do
      group_by = GroupBy.new(["metadata", "type"])

      query =
        Query.get("Article")
        |> Query.near_text("AI")
        |> Query.group_by(group_by)

      # Verify the path is stored correctly
      assert query.group_by.path == ["metadata", "type"]

      # Verify to_graphql handles nested paths
      graphql_fragment = GroupBy.to_graphql(query.group_by)
      assert graphql_fragment =~ ~s("metadata")
      assert graphql_fragment =~ ~s("type")
    end

    test "group_by works with near_vector" do
      group_by = GroupBy.new("category")

      query =
        Query.get("Article")
        |> Query.near_vector([0.1, 0.2, 0.3])
        |> Query.group_by(group_by)

      assert query.group_by.path == "category"
    end

    test "group_by works with hybrid search" do
      group_by = GroupBy.new("category")

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning")
        |> Query.group_by(group_by)

      assert query.group_by.path == "category"
    end
  end

  describe "rerank and group_by together" do
    test "both can be used in same query" do
      rerank = Rerank.new("content", query: "relevance query")
      group_by = GroupBy.new("category", objects_per_group: 3)

      query =
        Query.get("Article")
        |> Query.near_text("machine learning")
        |> Query.rerank(rerank)
        |> Query.group_by(group_by)

      assert query.rerank == rerank
      assert query.group_by == group_by
    end

    test "both configs produce valid GraphQL fragments" do
      rerank = Rerank.new("content")
      group_by = GroupBy.new("category")

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.near_text("AI")
        |> Query.rerank(rerank)
        |> Query.group_by(group_by)

      # Verify both configs are set
      assert %Rerank{} = query.rerank
      assert %GroupBy{} = query.group_by

      # Verify both produce valid GraphQL fragments
      rerank_fragment = Rerank.to_graphql(query.rerank)
      group_by_fragment = GroupBy.to_graphql(query.group_by)

      assert rerank_fragment =~ "content"
      assert group_by_fragment =~ "category"
    end
  end

  describe "query builder maintains structure" do
    test "rerank preserves other query fields" do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.fields(["title", "content"])
        |> Query.limit(10)
        |> Query.offset(5)
        |> Query.near_text("AI", certainty: 0.8)
        |> Query.additional(["id", "distance"])
        |> Query.rerank(rerank)

      assert query.collection == "Article"
      assert query.fields == ["title", "content"]
      assert query.limit == 10
      assert query.offset == 5
      assert query.near_text.certainty == 0.8
      assert query.additional == ["id", "distance"]
      assert query.rerank == rerank
    end

    test "group_by preserves other query fields" do
      group_by = GroupBy.new("category")

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.limit(20)
        |> Query.tenant("TenantA")
        |> Query.hybrid("AI", alpha: 0.6)
        |> Query.group_by(group_by)

      assert query.collection == "Article"
      assert query.limit == 20
      assert query.tenant == "TenantA"
      assert query.hybrid.alpha == 0.6
      assert query.group_by == group_by
    end
  end
end
