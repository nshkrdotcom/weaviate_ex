defmodule WeaviateEx.Query.HybridVectorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.HybridVector
  alias WeaviateEx.Query.Move

  describe "near_text/2" do
    test "creates near_text sub-search" do
      sub = HybridVector.near_text("espresso brewing")

      assert sub.type == :near_text
      assert sub.text == "espresso brewing"
    end

    test "creates near_text with move_to" do
      move_to = Move.to(0.5, concepts: ["barista"])
      sub = HybridVector.near_text("espresso brewing", move_to: move_to)

      assert sub.move_to == move_to
    end

    test "creates near_text with certainty" do
      sub = HybridVector.near_text("espresso brewing", certainty: 0.8)

      assert sub.certainty == 0.8
    end

    test "creates near_text with distance" do
      sub = HybridVector.near_text("espresso brewing", distance: 0.2)

      assert sub.distance == 0.2
    end
  end

  describe "near_vector/2" do
    test "creates near_vector sub-search" do
      vector = [0.1, 0.2, 0.3]
      sub = HybridVector.near_vector(vector)

      assert sub.type == :near_vector
      assert sub.vector == vector
    end

    test "creates near_vector with distance" do
      vector = [0.1, 0.2, 0.3]
      sub = HybridVector.near_vector(vector, distance: 0.5)

      assert sub.distance == 0.5
    end

    test "creates near_vector with certainty" do
      vector = [0.1, 0.2, 0.3]
      sub = HybridVector.near_vector(vector, certainty: 0.8)

      assert sub.certainty == 0.8
    end
  end

  describe "to_graphql/1" do
    test "converts near_text to graphql" do
      sub = HybridVector.near_text("espresso brewing")
      graphql = HybridVector.to_graphql(sub)

      assert graphql =~ "nearText:"
      assert graphql =~ ~s("espresso brewing")
    end

    test "converts near_text with move_to to graphql" do
      move_to = Move.to(0.5, concepts: ["barista"])
      sub = HybridVector.near_text("espresso brewing", move_to: move_to)
      graphql = HybridVector.to_graphql(sub)

      assert graphql =~ "moveTo:"
      assert graphql =~ "force: 0.5"
    end

    test "converts near_vector to graphql" do
      sub = HybridVector.near_vector([0.1, 0.2, 0.3], distance: 0.5)
      graphql = HybridVector.to_graphql(sub)

      assert graphql =~ "nearVector:"
      assert graphql =~ "vector:"
      assert graphql =~ "distance: 0.5"
    end
  end
end
