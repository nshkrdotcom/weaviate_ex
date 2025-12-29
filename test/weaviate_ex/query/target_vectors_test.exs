defmodule WeaviateEx.Query.TargetVectorsTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.TargetVectors

  describe "single/1" do
    test "creates single target vector" do
      target = TargetVectors.single("content_vector")

      assert target == "content_vector"
    end
  end

  describe "sum/1" do
    test "creates sum combination" do
      target = TargetVectors.sum(["title_vector", "content_vector"])

      assert target == {:sum, ["title_vector", "content_vector"]}
    end
  end

  describe "average/1" do
    test "creates average combination" do
      target = TargetVectors.average(["title_vector", "content_vector"])

      assert target == {:average, ["title_vector", "content_vector"]}
    end
  end

  describe "minimum/1" do
    test "creates minimum combination" do
      target = TargetVectors.minimum(["title_vector", "content_vector"])

      assert target == {:minimum, ["title_vector", "content_vector"]}
    end
  end

  describe "manual_weights/1" do
    test "creates manual weights combination" do
      weights = %{"title_vector" => 0.7, "content_vector" => 0.3}
      target = TargetVectors.manual_weights(weights)

      assert target == {:manual_weights, weights}
    end
  end

  describe "relative_score/1" do
    test "creates relative score combination" do
      weights = %{"title_vector" => 0.6, "content_vector" => 0.4}
      target = TargetVectors.relative_score(weights)

      assert target == {:relative_score, weights}
    end
  end

  describe "to_graphql/1" do
    test "converts single to graphql" do
      target = TargetVectors.single("content_vector")
      graphql = TargetVectors.to_graphql(target)

      assert graphql == ~s("content_vector")
    end

    test "converts sum to graphql" do
      target = TargetVectors.sum(["title_vector", "content_vector"])
      graphql = TargetVectors.to_graphql(target)

      assert graphql =~ "combinationMethod: sum"
      assert graphql =~ ~s("title_vector")
      assert graphql =~ ~s("content_vector")
    end

    test "converts average to graphql" do
      target = TargetVectors.average(["title_vector", "content_vector"])
      graphql = TargetVectors.to_graphql(target)

      assert graphql =~ "combinationMethod: average"
    end

    test "converts minimum to graphql" do
      target = TargetVectors.minimum(["title_vector", "content_vector"])
      graphql = TargetVectors.to_graphql(target)

      assert graphql =~ "combinationMethod: minimum"
    end

    test "converts manual_weights to graphql" do
      target = TargetVectors.manual_weights(%{"title" => 0.7, "content" => 0.3})
      graphql = TargetVectors.to_graphql(target)

      assert graphql =~ "combinationMethod: manualWeights"
      assert graphql =~ "weights:"
    end

    test "converts relative_score to graphql" do
      target = TargetVectors.relative_score(%{"title" => 0.6, "content" => 0.4})
      graphql = TargetVectors.to_graphql(target)

      assert graphql =~ "combinationMethod: relativeScore"
      assert graphql =~ "weights:"
    end
  end
end
