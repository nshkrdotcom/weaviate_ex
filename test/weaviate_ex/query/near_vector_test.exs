defmodule WeaviateEx.Query.NearVectorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query.NearVector

  describe "single/2" do
    test "creates single vector config" do
      vector = [0.1, 0.2, 0.3]
      result = NearVector.single(vector)

      assert result == %{vector: [0.1, 0.2, 0.3]}
    end

    test "accepts certainty option" do
      result = NearVector.single([0.1, 0.2], certainty: 0.8)

      assert result[:vector] == [0.1, 0.2]
      assert result[:certainty] == 0.8
    end

    test "accepts distance option" do
      result = NearVector.single([0.1, 0.2], distance: 0.3)

      assert result[:vector] == [0.1, 0.2]
      assert result[:distance] == 0.3
    end

    test "accepts target_vectors option" do
      result = NearVector.single([0.1, 0.2], target_vectors: ["title", "content"])

      assert result[:vector] == [0.1, 0.2]
      assert result[:target_vectors] == ["title", "content"]
    end
  end

  describe "list_of_vectors/2" do
    test "creates list of vectors config" do
      vec1 = [0.1, 0.2]
      vec2 = [0.3, 0.4]
      result = NearVector.list_of_vectors([vec1, vec2])

      assert result[:vectors] == [[0.1, 0.2], [0.3, 0.4]]
    end

    test "accepts certainty option" do
      result = NearVector.list_of_vectors([[0.1]], certainty: 0.7)

      assert result[:certainty] == 0.7
    end
  end

  describe "per_target/2" do
    test "creates per-target vector config" do
      targets = %{
        "title_vector" => [0.1, 0.2],
        "content_vector" => [0.3, 0.4]
      }

      result = NearVector.per_target(targets)

      assert result[:targets] == targets
    end

    test "accepts combination_method option" do
      result = NearVector.per_target(%{"a" => [0.1]}, combination_method: :average)

      assert result[:combination_method] == "average"
    end

    test "accepts certainty and distance options" do
      result =
        NearVector.per_target(%{"a" => [0.1]},
          certainty: 0.8,
          distance: 0.2
        )

      assert result[:certainty] == 0.8
      assert result[:distance] == 0.2
    end
  end

  describe "weighted_targets/2" do
    test "creates weighted targets config" do
      weighted_list = [
        {"title", [0.1, 0.2], 0.7},
        {"content", [0.3, 0.4], 0.3}
      ]

      result = NearVector.weighted_targets(weighted_list)

      assert result[:weighted_targets]["title"][:vector] == [0.1, 0.2]
      assert result[:weighted_targets]["title"][:weight] == 0.7
      assert result[:weighted_targets]["content"][:vector] == [0.3, 0.4]
      assert result[:weighted_targets]["content"][:weight] == 0.3
    end
  end

  describe "to_api/1" do
    test "converts single vector config" do
      config = NearVector.single([0.1, 0.2], certainty: 0.8)
      result = NearVector.to_api(config)

      assert result["vector"] == [0.1, 0.2]
      assert result["certainty"] == 0.8
    end

    test "converts list of vectors config" do
      config = NearVector.list_of_vectors([[0.1], [0.2]])
      result = NearVector.to_api(config)

      assert result["vectors"] == [[0.1], [0.2]]
    end

    test "converts per-target config" do
      config = NearVector.per_target(%{"title" => [0.1]}, combination_method: :sum)
      result = NearVector.to_api(config)

      assert result["targetVectors"] == %{"title" => [0.1]}
      assert result["combinationMethod"] == "sum"
    end
  end
end
