defmodule WeaviateEx.QueryTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks
  alias WeaviateEx.{Query, Fixtures}
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
