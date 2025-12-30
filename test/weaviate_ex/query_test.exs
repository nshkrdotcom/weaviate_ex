defmodule WeaviateEx.QueryTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.{Fixtures, Query}
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "get/1 and execute/2" do
    test "builds and executes a simple Get query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", _body, _opts ->
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title", "content"])
        |> Query.limit(10)

      assert {:ok, result} = Query.execute(query)
      # Query.execute/2 now returns the parsed collection results directly
      assert is_list(result)
      assert length(result) == 2
    end

    test "builds query with additional fields", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", _body, _opts ->
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.additional(["id", "certainty"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "near_text/3" do
    test "builds near_text vector search query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearText"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.near_text("artificial intelligence", certainty: 0.7)
        |> Query.fields(["title"])
        |> Query.limit(5)

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "near_vector/3" do
    test "builds near_vector search query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearVector"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.near_vector([0.1, 0.2, 0.3], certainty: 0.8)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "hybrid/3" do
    test "builds hybrid search query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "hybrid"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning", alpha: 0.5)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds hybrid search with max_vector_distance", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "hybrid"
        assert body_str =~ "maxVectorDistance"
        assert body_str =~ "0.5"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning", alpha: 0.75, max_vector_distance: 0.5)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds hybrid search with bm25_operator AND", %{client: _client} do
      alias WeaviateEx.Query.BM25Operator

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "hybrid"
        assert body_str =~ "bm25SearchOperator"
        assert body_str =~ "And"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning AI", bm25_operator: BM25Operator.and_())
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds hybrid search with bm25_operator OR with minimum match", %{client: _client} do
      alias WeaviateEx.Query.BM25Operator

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "hybrid"
        assert body_str =~ "bm25SearchOperator"
        assert body_str =~ "Or"
        assert body_str =~ "minimumShouldMatch"
        assert body_str =~ "2"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning AI", bm25_operator: BM25Operator.or_(2))
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds hybrid search with both max_vector_distance and bm25_operator", %{
      client: _client
    } do
      alias WeaviateEx.Query.BM25Operator

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "hybrid"
        assert body_str =~ "maxVectorDistance"
        assert body_str =~ "bm25SearchOperator"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning",
          alpha: 0.7,
          max_vector_distance: 0.3,
          bm25_operator: BM25Operator.and_()
        )
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "bm25/3" do
    test "builds BM25 keyword search query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "bm25"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.bm25("machine learning")
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "where/2" do
    test "builds query with where filter", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "where"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("Article")
        |> Query.where(%{
          path: ["title"],
          operator: "Equal",
          valueText: "Test"
        })
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "near_text with Move" do
    alias WeaviateEx.Query.Move

    test "builds near_text query with move_to", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearText"
        assert body_str =~ "moveTo"
        assert body_str =~ "summer"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      move_to = Move.to(0.5, concepts: ["summer", "beach"])

      query =
        Query.get("Article")
        |> Query.near_text("vacation", move_to: move_to)
        |> Query.fields(["title"])
        |> Query.limit(5)

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds near_text query with move_away", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearText"
        assert body_str =~ "moveAwayFrom"
        assert body_str =~ "winter"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      move_away = Move.to(0.3, concepts: ["winter", "cold"])

      query =
        Query.get("Article")
        |> Query.near_text("vacation", move_away: move_away)
        |> Query.fields(["title"])
        |> Query.limit(5)

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds near_text query with both move_to and move_away", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearText"
        assert body_str =~ "moveTo"
        assert body_str =~ "moveAwayFrom"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      move_to = Move.to(0.5, concepts: ["summer"])
      move_away = Move.to(0.25, concepts: ["winter"])

      query =
        Query.get("Article")
        |> Query.near_text("vacation",
          certainty: 0.7,
          move_to: move_to,
          move_away: move_away
        )
        |> Query.fields(["title"])
        |> Query.limit(5)

      assert {:ok, _result} = Query.execute(query)
    end

    test "builds near_text query with move_to using objects", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearText"
        assert body_str =~ "moveTo"
        assert body_str =~ "objects"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      move_to = Move.to(0.5, objects: ["550e8400-e29b-41d4-a716-446655440000"])

      query =
        Query.get("Article")
        |> Query.near_text("vacation", move_to: move_to)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "near_image/2" do
    alias WeaviateEx.Query.NearImage

    test "builds near_image search query with base64 data", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearImage"
        assert body_str =~ "base64imagedata"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("ImageCollection")
        |> Query.near_image(image: "base64imagedata", certainty: 0.8)
        |> Query.fields(["name"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "creates NearImage struct with correct values" do
      query =
        Query.get("ImageCollection")
        |> Query.near_image(image: "data", certainty: 0.9, target_vectors: ["image_vec"])

      assert %NearImage{} = query.near_image
      assert query.near_image.image == "data"
      assert query.near_image.certainty == 0.9
      assert query.near_image.target_vectors == ["image_vec"]
    end
  end

  describe "near_media/3" do
    alias WeaviateEx.Query.NearMedia

    test "builds near_media search query for audio", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "nearMedia"
        assert body_str =~ "base64audiodata"
        assert body_str =~ "audio"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      query =
        Query.get("MediaCollection")
        |> Query.near_media(:audio, media: "base64audiodata", certainty: 0.7)
        |> Query.fields(["name"])

      assert {:ok, _result} = Query.execute(query)
    end

    test "creates NearMedia struct with correct type and values" do
      query =
        Query.get("MediaCollection")
        |> Query.near_media(:video, media: "data", distance: 0.3)

      assert %NearMedia{} = query.near_media
      assert query.near_media.type == :video
      assert query.near_media.media == "data"
      assert query.near_media.distance == 0.3
    end

    test "supports all media types" do
      for type <- [:audio, :video, :thermal, :depth, :imu] do
        query =
          Query.get("MediaCollection")
          |> Query.near_media(type, media: "data")

        assert query.near_media.type == type
      end
    end
  end

  describe "rerank/2" do
    alias WeaviateEx.Query.Rerank

    test "adds rerank to query", %{client: _client} do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.near_text("machine learning")
        |> Query.rerank(rerank)

      assert query.rerank == rerank
      assert query.rerank.prop == "content"
    end

    test "rerank with custom query", %{client: _client} do
      rerank = Rerank.new("content", query: "What is machine learning?")

      query =
        Query.get("Article")
        |> Query.near_text("AI")
        |> Query.rerank(rerank)

      assert query.rerank.prop == "content"
      assert query.rerank.query == "What is machine learning?"
    end

    test "preserves other query params with rerank", %{client: _client} do
      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.near_text("machine learning", certainty: 0.7)
        |> Query.fields(["title", "content"])
        |> Query.limit(10)
        |> Query.rerank(rerank)

      assert query.rerank == rerank
      assert query.near_text.concepts == ["machine learning"]
      assert query.near_text.certainty == 0.7
      assert query.fields == ["title", "content"]
      assert query.limit == 10
    end

    test "builds GraphQL query with rerank", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "rerank"
        assert body_str =~ "content"
        assert body_str =~ "score"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      rerank = Rerank.new("content")

      query =
        Query.get("Article")
        |> Query.near_text("machine learning")
        |> Query.fields(["title"])
        |> Query.rerank(rerank)

      # Force HTTP mode by not using client
      assert {:ok, _result} = Query.execute(query)
    end

    test "builds GraphQL query with rerank and custom query", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        body_str = Jason.encode!(body)
        assert body_str =~ "rerank"
        assert body_str =~ "content"
        assert body_str =~ "deep learning"
        {:ok, Fixtures.graphql_response_fixture()}
      end)

      rerank = Rerank.new("content", query: "deep learning")

      query =
        Query.get("Article")
        |> Query.hybrid("AI", alpha: 0.5)
        |> Query.fields(["title"])
        |> Query.rerank(rerank)

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "integration tests" do
    @tag :integration
    test "executes real GraphQL query" do
      if WeaviateEx.TestHelpers.integration_mode?() do
        query =
          Query.get("Article")
          |> Query.fields(["title"])
          |> Query.limit(5)

        assert {:ok, result} = Query.execute(query)
        assert result["data"]["Get"]
      else
        assert true
      end
    end
  end
end
