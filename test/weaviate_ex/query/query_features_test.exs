defmodule WeaviateEx.Query.QueryFeaturesTest do
  @moduledoc """
  Tests for advanced query features: auto_limit, after (cursor pagination),
  sort integration, and return_references.

  Following TDD approach - tests written first.
  """

  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Query
  alias WeaviateEx.Query.Sort
  alias WeaviateEx.Query.QueryReference
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "auto_limit/2" do
    test "adds autoLimit parameter to query struct" do
      query =
        Query.get("Article")
        |> Query.auto_limit(3)

      assert query.auto_limit == 3
    end

    test "builds GraphQL query with autoLimit parameter", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "autoLimit: 3"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{"title" => "Article 1"},
                 %{"title" => "Article 2"}
               ]
             }
           }
         }}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.auto_limit(3)

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 2
    end

    test "auto_limit works with near_text search", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "nearText"
        assert query_str =~ "autoLimit: 2"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.near_text("machine learning")
        |> Query.auto_limit(2)

      assert {:ok, []} = Query.execute(query)
    end

    test "auto_limit replaces previous value when called multiple times" do
      query =
        Query.get("Article")
        |> Query.auto_limit(5)
        |> Query.auto_limit(10)

      assert query.auto_limit == 10
    end
  end

  describe "after_cursor/2 cursor pagination" do
    test "adds after parameter to query struct" do
      cursor = "some-cursor-value"

      query =
        Query.get("Article")
        |> Query.after_cursor(cursor)

      assert query.after == cursor
    end

    test "builds GraphQL query with after parameter", %{client: _client} do
      cursor = "WzEyMzQ1NTU1XQ=="

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "after: \"#{cursor}\""

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{"title" => "Article Page 2"}
               ]
             }
           }
         }}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.limit(10)
        |> Query.after_cursor(cursor)

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 1
    end

    test "after_cursor works with limit for cursor-based pagination", %{client: _client} do
      cursor = "last-object-cursor"

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "limit: 20"
        assert query_str =~ "after: \"#{cursor}\""

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.limit(20)
        |> Query.after_cursor(cursor)

      assert {:ok, []} = Query.execute(query)
    end

    test "after_cursor replaces previous cursor when called multiple times" do
      query =
        Query.get("Article")
        |> Query.after_cursor("cursor-1")
        |> Query.after_cursor("cursor-2")

      assert query.after == "cursor-2"
    end

    test "after_cursor works with sort for deterministic pagination", %{client: _client} do
      cursor = "sorted-cursor"

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ "after: \"#{cursor}\""

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort = Sort.by_id(:asc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)
        |> Query.after_cursor(cursor)

      assert {:ok, []} = Query.execute(query)
    end
  end

  describe "sort/2" do
    test "adds sort parameter to query struct" do
      sort = Sort.by_property("title", :asc)

      query =
        Query.get("Article")
        |> Query.sort(sort)

      assert query.sort == sort
    end

    test "builds GraphQL query with single sort", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ ~s("title")
        assert query_str =~ "asc"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{"title" => "AAA Article"},
                 %{"title" => "BBB Article"}
               ]
             }
           }
         }}
      end)

      sort = Sort.by_property("title", :asc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 2
    end

    test "builds GraphQL query with multiple sort criteria", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ ~s("category")
        assert query_str =~ ~s("title")

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort =
        Sort.by_property("category", :asc)
        |> Sort.then_by_property("title", :desc)

      query =
        Query.get("Article")
        |> Query.fields(["title", "category"])
        |> Query.sort(sort)

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with sort by id", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ ~s("id")

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort = Sort.by_id(:asc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)
        |> Query.additional(["id"])

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with sort by creation_time", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ ~s("_creationTimeUnix")
        assert query_str =~ "desc"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort = Sort.by_creation_time(:desc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with sort by update_time", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ ~s("_lastUpdateTimeUnix")

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort = Sort.by_update_time(:asc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)

      assert {:ok, []} = Query.execute(query)
    end

    test "sort replaces previous sort when called multiple times" do
      sort1 = Sort.by_property("title")
      sort2 = Sort.by_property("content")

      query =
        Query.get("Article")
        |> Query.sort(sort1)
        |> Query.sort(sort2)

      assert query.sort == sort2
    end
  end

  describe "return_references/2" do
    test "adds return_references parameter to query struct" do
      ref = QueryReference.new("hasAuthor", return_properties: ["name"])

      query =
        Query.get("Article")
        |> Query.return_references([ref])

      assert query.return_references == [ref]
    end

    test "builds GraphQL query with simple reference", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "hasAuthor"
        assert query_str =~ "... on"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "Test Article",
                   "hasAuthor" => [
                     %{"name" => "John Doe"}
                   ]
                 }
               ]
             }
           }
         }}
      end)

      ref = QueryReference.new("hasAuthor", return_properties: ["name"])

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.return_references([ref])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 1
    end

    test "builds GraphQL query with reference properties", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "hasAuthor"
        assert query_str =~ "name"
        assert query_str =~ "bio"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      ref = QueryReference.new("hasAuthor", return_properties: ["name", "bio"])

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.return_references([ref])

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with nested references", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "hasAuthor"
        assert query_str =~ "hasPublisher"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      nested_ref = QueryReference.new("hasPublisher", return_properties: ["name"])

      ref =
        QueryReference.new("hasAuthor",
          return_properties: ["name"],
          return_references: [nested_ref]
        )

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.return_references([ref])

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with multiple references", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "hasAuthor"
        assert query_str =~ "hasCategory"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      ref1 = QueryReference.new("hasAuthor", return_properties: ["name"])
      ref2 = QueryReference.new("hasCategory", return_properties: ["name"])

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.return_references([ref1, ref2])

      assert {:ok, []} = Query.execute(query)
    end

    test "builds GraphQL query with reference including vector", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "hasAuthor"
        assert query_str =~ "vector"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      ref = QueryReference.new("hasAuthor", return_properties: ["name"], include_vector: true)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.return_references([ref])

      assert {:ok, []} = Query.execute(query)
    end

    test "return_references replaces previous references when called multiple times" do
      ref1 = QueryReference.new("hasAuthor")
      ref2 = QueryReference.new("hasCategory")

      query =
        Query.get("Article")
        |> Query.return_references([ref1])
        |> Query.return_references([ref2])

      assert query.return_references == [ref2]
    end
  end

  describe "combined features" do
    test "builds query with sort, limit, and after_cursor for cursor pagination", %{
      client: _client
    } do
      cursor = "page-cursor"

      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "sort:"
        assert query_str =~ "limit: 10"
        assert query_str =~ "after: \"#{cursor}\""

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      sort = Sort.by_id(:asc)

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.sort(sort)
        |> Query.limit(10)
        |> Query.after_cursor(cursor)

      assert {:ok, []} = Query.execute(query)
    end

    test "builds query with near_text, auto_limit, and references", %{client: _client} do
      Mox.expect(Mock, :request, fn _client, :post, "/v1/graphql", body, _opts ->
        query_str = body["query"] || body[:query]
        assert query_str =~ "nearText"
        assert query_str =~ "autoLimit: 3"
        assert query_str =~ "hasAuthor"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      ref = QueryReference.new("hasAuthor", return_properties: ["name"])

      query =
        Query.get("Article")
        |> Query.fields(["title"])
        |> Query.near_text("machine learning")
        |> Query.auto_limit(3)
        |> Query.return_references([ref])

      assert {:ok, []} = Query.execute(query)
    end
  end
end
