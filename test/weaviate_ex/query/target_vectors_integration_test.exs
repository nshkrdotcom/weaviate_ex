defmodule WeaviateEx.Query.TargetVectorsIntegrationTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Query
  alias WeaviateEx.Query.TargetVectors

  describe "near_vector with target_vectors" do
    test "accepts single target vector" do
      query =
        Query.get("MultiVectorCollection")
        |> Query.near_vector([0.1, 0.2, 0.3], target_vectors: "title_vector")

      assert query.near_vector.target_vectors == "title_vector"
    end

    test "accepts list of target vectors" do
      query =
        Query.get("MultiVectorCollection")
        |> Query.near_vector([0.1, 0.2, 0.3], target_vectors: ["title_vector", "content_vector"])

      assert query.near_vector.target_vectors == ["title_vector", "content_vector"]
    end

    test "accepts TargetVectors.combine configuration" do
      target =
        TargetVectors.combine(
          ["title_vector", "content_vector"],
          method: :sum
        )

      query =
        Query.get("MultiVectorCollection")
        |> Query.near_vector([0.1, 0.2, 0.3], target_vectors: target)

      assert query.near_vector.target_vectors.method == :sum
    end

    test "accepts TargetVectors.weighted configuration" do
      target =
        TargetVectors.weighted(%{
          "title_vector" => 0.7,
          "content_vector" => 0.3
        })

      query =
        Query.get("MultiVectorCollection")
        |> Query.near_vector([0.1, 0.2, 0.3], target_vectors: target)

      assert query.near_vector.target_vectors.weights["title_vector"] == 0.7
    end
  end

  describe "near_text with target_vectors" do
    test "accepts target vector for named vectors" do
      query =
        Query.get("MultiVectorCollection")
        |> Query.near_text("machine learning", target_vectors: "content_vector")

      assert query.near_text.target_vectors == "content_vector"
    end

    test "combines target vectors with move operations" do
      target = TargetVectors.combine(["title_vector", "content_vector"], method: :average)

      query =
        Query.get("MultiVectorCollection")
        |> Query.near_text("machine learning",
          target_vectors: target,
          move_to: %{concepts: ["AI"], force: 0.5}
        )

      assert query.near_text.target_vectors.method == :average
    end
  end

  describe "near_object with target_vectors" do
    test "accepts target vector" do
      query =
        Query.get("MultiVectorCollection")
        |> Query.near_object("550e8400-e29b-41d4-a716-446655440000",
          target_vectors: "title_vector"
        )

      assert query.near_object.target_vectors == "title_vector"
    end
  end

  describe "TargetVectors.combine/2" do
    test "creates sum combination" do
      target = TargetVectors.combine(["vec1", "vec2"], method: :sum)

      assert target.vectors == ["vec1", "vec2"]
      assert target.method == :sum
    end

    test "creates average combination" do
      target = TargetVectors.combine(["vec1", "vec2"], method: :average)

      assert target.method == :average
    end

    test "creates minimum combination" do
      target = TargetVectors.combine(["vec1", "vec2"], method: :minimum)

      assert target.method == :minimum
    end

    test "raises on invalid method" do
      assert_raise ArgumentError, fn ->
        TargetVectors.combine(["vec1"], method: :invalid)
      end
    end
  end

  describe "TargetVectors.weighted/1" do
    test "creates weighted combination" do
      target =
        TargetVectors.weighted(%{
          "vec1" => 0.8,
          "vec2" => 0.2
        })

      assert target.method == :manual_weights
      assert target.weights == %{"vec1" => 0.8, "vec2" => 0.2}
    end

    test "validates weights sum to approximately 1" do
      # Should not raise - exact sum not required
      target = TargetVectors.weighted(%{"vec1" => 0.6, "vec2" => 0.4})
      assert target.weights["vec1"] == 0.6
    end
  end

  describe "TargetVectors.to_grpc/1" do
    test "converts single target to gRPC format" do
      grpc = TargetVectors.to_grpc("title_vector")

      assert grpc.target_vectors == ["title_vector"]
    end

    test "converts combined targets to gRPC format" do
      target = TargetVectors.combine(["vec1", "vec2"], method: :average)
      grpc = TargetVectors.to_grpc(target)

      assert grpc.target_vectors == ["vec1", "vec2"]
      assert grpc.combination_method == :COMBINATION_METHOD_TYPE_AVERAGE
    end

    test "converts manual weights to gRPC format" do
      target = TargetVectors.weighted(%{"vec1" => 0.7, "vec2" => 0.3})
      grpc = TargetVectors.to_grpc(target)

      assert grpc.combination_method == :COMBINATION_METHOD_TYPE_MANUAL
      assert grpc.weights == %{"vec1" => 0.7, "vec2" => 0.3}
    end
  end

  describe "TargetVectors.normalize/1" do
    test "normalizes nil to nil" do
      assert TargetVectors.normalize(nil) == nil
    end

    test "normalizes string to single vector config" do
      normalized = TargetVectors.normalize("content_vector")

      assert %TargetVectors.Config{} = normalized
      assert normalized.vectors == ["content_vector"]
    end

    test "normalizes list to combined config" do
      normalized = TargetVectors.normalize(["vec1", "vec2"])

      assert %TargetVectors.Config{} = normalized
      assert normalized.vectors == ["vec1", "vec2"]
      assert normalized.method == :sum
    end

    test "passes through Config unchanged" do
      config = TargetVectors.combine(["vec1", "vec2"], method: :average)
      normalized = TargetVectors.normalize(config)

      assert normalized == config
    end
  end
end
