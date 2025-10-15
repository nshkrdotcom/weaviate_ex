defmodule WeaviateEx.QueryTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.TestHelpers
  alias WeaviateEx.{Query, Fixtures}

  setup :verify_on_exit!
  setup :setup_http_client

  describe "get/1 and execute/2" do
    test "builds and executes a simple Get query" do
      expect_http_request_with_body(:post, "/v1/graphql", :any, fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title", "content"])
        |> Query.limit(10)

      assert {:ok, result} = Query.execute(query)
      assert result["data"]["Get"]["Article"]
    end

    test "builds query with additional fields" do
      expect_http_request_with_body(:post, "/v1/graphql", :any, fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.additional(["id", "certainty"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "near_text/3" do
    test "builds near_text vector search query" do
      expect_http_request_with_body(:post, "/v1/graphql", "nearText", fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
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
    test "builds near_vector search query" do
      expect_http_request_with_body(:post, "/v1/graphql", "nearVector", fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
      end)

      query =
        Query.get("Article")
        |> Query.near_vector([0.1, 0.2, 0.3], certainty: 0.8)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "hybrid/3" do
    test "builds hybrid search query" do
      expect_http_request_with_body(:post, "/v1/graphql", "hybrid", fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
      end)

      query =
        Query.get("Article")
        |> Query.hybrid("machine learning", alpha: 0.5)
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "bm25/3" do
    test "builds BM25 keyword search query" do
      expect_http_request_with_body(:post, "/v1/graphql", "bm25", fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
      end)

      query =
        Query.get("Article")
        |> Query.bm25("machine learning")
        |> Query.fields(["title"])

      assert {:ok, _result} = Query.execute(query)
    end
  end

  describe "where/2" do
    test "builds query with where filter" do
      expect_http_request_with_body(:post, "/v1/graphql", "where", fn ->
        mock_success_response(Fixtures.graphql_response_fixture())
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

  describe "integration tests" do
    @tag :integration
    test "executes real GraphQL query" do
      if integration_mode?() do
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
