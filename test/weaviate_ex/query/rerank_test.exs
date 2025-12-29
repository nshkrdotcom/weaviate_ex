defmodule WeaviateEx.Query.RerankTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.Rerank

  describe "new/2" do
    test "creates rerank with property only" do
      rerank = Rerank.new("content")

      assert rerank.prop == "content"
      assert rerank.query == nil
    end

    test "creates rerank with property and query" do
      rerank = Rerank.new("content", query: "deep learning applications")

      assert rerank.prop == "content"
      assert rerank.query == "deep learning applications"
    end
  end

  describe "to_graphql/1" do
    test "converts rerank with property only to graphql" do
      rerank = Rerank.new("content")
      graphql = Rerank.to_graphql(rerank)

      assert graphql =~ ~s(property: "content")
      refute graphql =~ "query:"
    end

    test "converts rerank with property and query to graphql" do
      rerank = Rerank.new("content", query: "deep learning")
      graphql = Rerank.to_graphql(rerank)

      assert graphql =~ ~s(property: "content")
      assert graphql =~ ~s(query: "deep learning")
    end
  end
end
