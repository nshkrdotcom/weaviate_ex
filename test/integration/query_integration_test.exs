defmodule WeaviateEx.Integration.QueryTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.{Collections, Query, Batch}

  @moduletag :integration

  @test_collection "QueryIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :http_client, WeaviateEx.HTTPClient.Finch)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]},
          %{name: "category", dataType: ["text"]},
          %{name: "score", dataType: ["int"]}
        ],
        vectorizer: "none"
      })

    # Create test data
    objects =
      for i <- 1..20 do
        category =
          case rem(i, 4) do
            0 -> "ai"
            1 -> "ml"
            2 -> "elixir"
            _ -> "general"
          end

        %{
          class: @test_collection,
          properties: %{
            title: "Article #{i}",
            content: "Content about #{category} topic number #{i}",
            category: category,
            score: i * 10
          },
          vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
        }
      end

    {:ok, _} = Batch.create_objects(objects)

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    :ok
  end

  describe "Query.execute/2 - basic queries (live)" do
    test "executes simple Get query" do
      query =
        Query.get(@test_collection)
        |> Query.fields(["title", "content"])
        |> Query.limit(5)

      assert {:ok, articles} = Query.execute(query)
      assert is_list(articles)
      assert length(articles) == 5
    end

    test "query with limit and offset" do
      query =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(3)
        |> Query.offset(5)

      assert {:ok, articles} = Query.execute(query)
      assert is_list(articles)
      assert length(articles) == 3
    end

    test "query with additional fields" do
      query =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.additional(["id", "vector"])
        |> Query.limit(2)

      assert {:ok, articles} = Query.execute(query)
      assert is_list(articles)

      first = List.first(articles)
      assert first["_additional"]["id"]
      assert first["_additional"]["vector"]
    end
  end

  describe "Query.where/2 - filtering (live)" do
    test "filters with Equal operator" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["category"],
          operator: "Equal",
          valueText: "ai"
        })
        |> Query.fields(["title", "category"])

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      assert length(articles) >= 1
      assert Enum.all?(articles, fn a -> a["category"] == "ai" end)
    end

    test "filters with GreaterThan operator on int field" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["score"],
          operator: "GreaterThan",
          valueInt: 100
        })
        |> Query.fields(["title", "score"])

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      assert length(articles) >= 1
      assert Enum.all?(articles, fn a -> a["score"] > 100 end)
    end
  end

  describe "Query.near_vector/3 - vector search (live)" do
    test "finds similar objects by vector" do
      # Get a reference object first
      {:ok, ref_articles} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.additional(["vector"])
        |> Query.limit(1)
        |> Query.execute()

      ref_object = List.first(ref_articles)
      vector = ref_object["_additional"]["vector"]

      # Now search for similar
      query =
        Query.get(@test_collection)
        |> Query.near_vector(vector, distance: 0.5)
        |> Query.fields(["title"])
        |> Query.additional(["distance"])
        |> Query.limit(3)

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      assert length(articles) >= 1
      # First result should be the same object (distance ~0)
      first = List.first(articles)
      assert first["_additional"]["distance"] < 0.1
    end
  end

  describe "Query.hybrid/3 - hybrid search (live)" do
    test "performs hybrid search" do
      query =
        Query.get(@test_collection)
        |> Query.hybrid("elixir topic", alpha: 0.5)
        |> Query.fields(["title", "content"])
        |> Query.limit(5)

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      # Should return results (may be empty if no good matches)
    end
  end

  describe "Query.bm25/3 - keyword search (live)" do
    test "performs BM25 keyword search" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("Content")
        |> Query.fields(["title", "content"])
        |> Query.limit(5)

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      assert length(articles) >= 1
    end

    test "BM25 search with properties filter" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("Article", properties: ["title"])
        |> Query.fields(["title"])
        |> Query.limit(10)

      assert {:ok, articles} = Query.execute(query)

      assert is_list(articles)
      assert length(articles) >= 1
    end
  end

  describe "Query combined with filters (live)" do
    test "combines where filter with limit" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["category"],
          operator: "Equal",
          valueText: "ml"
        })
        |> Query.fields(["title", "category"])
        |> Query.limit(2)

      assert {:ok, articles} = Query.execute(query)

      assert length(articles) <= 2

      if length(articles) > 0 do
        assert Enum.all?(articles, fn a -> a["category"] == "ml" end)
      end
    end
  end
end
