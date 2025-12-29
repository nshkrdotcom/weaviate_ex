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
      rerank = Rerank.new("content", query: "What is machine learning?")

      assert rerank.prop == "content"
      assert rerank.query == "What is machine learning?"
    end
  end

  describe "to_graphql/1" do
    test "converts to GraphQL format with property only" do
      rerank = Rerank.new("content")
      result = Rerank.to_graphql(rerank)

      assert result == ~s({property: "content"})
    end

    test "converts to GraphQL format with property and query" do
      rerank = Rerank.new("content", query: "deep learning")
      result = Rerank.to_graphql(rerank)

      assert result == ~s({property: "content", query: "deep learning"})
    end

    test "escapes special characters in property" do
      rerank = Rerank.new("has\"quote")
      result = Rerank.to_graphql(rerank)

      assert result == ~s({property: "has\\"quote"})
    end

    test "escapes special characters in query" do
      rerank = Rerank.new("content", query: "what is \"AI\"?")
      result = Rerank.to_graphql(rerank)

      assert result == ~s({property: "content", query: "what is \\"AI\\"?"})
    end

    test "escapes newlines in query" do
      rerank = Rerank.new("content", query: "line1\nline2")
      result = Rerank.to_graphql(rerank)

      assert result == ~s({property: "content", query: "line1\\nline2"})
    end
  end

  describe "to_map/1" do
    test "converts to map format without query" do
      rerank = Rerank.new("content")
      result = Rerank.to_map(rerank)

      assert result == %{property: "content"}
    end

    test "converts to map format with query" do
      rerank = Rerank.new("content", query: "deep learning")
      result = Rerank.to_map(rerank)

      assert result == %{property: "content", query: "deep learning"}
    end
  end

  describe "valid?/1" do
    test "returns true for valid rerank with property" do
      rerank = Rerank.new("content")
      assert Rerank.valid?(rerank) == true
    end

    test "returns true for valid rerank with property and query" do
      rerank = Rerank.new("content", query: "test")
      assert Rerank.valid?(rerank) == true
    end

    test "returns false for nil property" do
      rerank = %Rerank{prop: nil}
      assert Rerank.valid?(rerank) == false
    end

    test "returns false for empty property" do
      rerank = %Rerank{prop: ""}
      assert Rerank.valid?(rerank) == false
    end
  end
end
