defmodule WeaviateEx.Query.MoveTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.Move

  describe "to/2" do
    test "creates move with force and concepts" do
      move = Move.to(0.5, concepts: ["summer", "beach"])

      assert move.force == 0.5
      assert move.concepts == ["summer", "beach"]
      assert move.objects == nil
    end

    test "creates move with force and objects" do
      move = Move.to(0.25, objects: ["uuid-1", "uuid-2"])

      assert move.force == 0.25
      assert move.objects == ["uuid-1", "uuid-2"]
      assert move.concepts == nil
    end

    test "creates move with both concepts and objects" do
      move = Move.to(0.3, concepts: ["summer"], objects: ["uuid-1"])

      assert move.force == 0.3
      assert move.concepts == ["summer"]
      assert move.objects == ["uuid-1"]
    end
  end

  describe "to_graphql/1" do
    test "converts move with concepts to graphql format" do
      move = Move.to(0.5, concepts: ["summer", "beach"])
      graphql = Move.to_graphql(move)

      assert graphql =~ "force: 0.5"
      assert graphql =~ "concepts:"
      assert graphql =~ ~s("summer")
      assert graphql =~ ~s("beach")
    end

    test "converts move with objects to graphql format" do
      move = Move.to(0.25, objects: ["uuid-1"])
      graphql = Move.to_graphql(move)

      assert graphql =~ "force: 0.25"
      assert graphql =~ "objects:"
      assert graphql =~ ~s("uuid-1")
    end

    test "converts move with both to graphql format" do
      move = Move.to(0.3, concepts: ["summer"], objects: ["uuid-1"])
      graphql = Move.to_graphql(move)

      assert graphql =~ "force: 0.3"
      assert graphql =~ "concepts:"
      assert graphql =~ "objects:"
    end
  end
end
