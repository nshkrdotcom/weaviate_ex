defmodule WeaviateEx.Query.BM25OperatorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.BM25Operator

  describe "or_/1" do
    test "creates OR operator with minimum match" do
      operator = BM25Operator.or_(2)

      assert operator.type == :or
      assert operator.minimum_should_match == 2
    end
  end

  describe "and_/0" do
    test "creates AND operator" do
      operator = BM25Operator.and_()

      assert operator.type == :and
      assert operator.minimum_should_match == nil
    end
  end

  describe "to_graphql/1" do
    test "converts OR operator to graphql" do
      operator = BM25Operator.or_(2)
      graphql = BM25Operator.to_graphql(operator)

      assert graphql =~ "operator: Or"
      assert graphql =~ "minimumShouldMatch: 2"
    end

    test "converts AND operator to graphql" do
      operator = BM25Operator.and_()
      graphql = BM25Operator.to_graphql(operator)

      assert graphql =~ "operator: And"
      refute graphql =~ "minimumShouldMatch"
    end
  end
end
