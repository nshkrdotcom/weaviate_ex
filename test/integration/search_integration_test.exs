defmodule WeaviateEx.Integration.SearchTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.{Batch, Collections, Query}

  @moduletag :integration

  @test_collection "SearchIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection with text properties for BM25 search
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]},
          %{name: "category", dataType: ["text"]},
          %{name: "rank", dataType: ["int"]}
        ],
        vectorizer: "none"
      })

    # Create test data with vectors
    objects =
      for i <- 1..15 do
        category =
          case rem(i, 3) do
            0 -> "technology"
            1 -> "science"
            _ -> "general"
          end

        %{
          class: @test_collection,
          properties: %{
            title: "Article #{i}: Introduction to #{category}",
            content:
              "This is content about #{category}. Article number #{i} covers important topics.",
            category: category,
            rank: i
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

  describe "BM25 keyword search (live)" do
    test "performs basic BM25 search with query parameter" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("technology")
        |> Query.fields(["title", "content", "category"])
        |> Query.limit(10)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) >= 1

      # Results should contain matches for "technology"
      assert Enum.any?(results, fn r ->
               String.contains?(r["title"], "technology") or
                 String.contains?(r["content"], "technology") or
                 r["category"] == "technology"
             end)
    end

    test "BM25 search with specific properties" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("Article", properties: ["title"])
        |> Query.fields(["title", "category"])
        |> Query.limit(5)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) >= 1

      # All results should have "Article" in title
      assert Enum.all?(results, fn r -> String.contains?(r["title"], "Article") end)
    end

    test "BM25 search with no matches returns empty list" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("xyznonexistent999")
        |> Query.fields(["title"])
        |> Query.limit(10)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert results == []
    end
  end

  describe "Vector search - near_vector (live)" do
    test "performs near_vector search with distance threshold" do
      # First get a reference vector from an existing object
      {:ok, ref_results} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.additional(["vector"])
        |> Query.limit(1)
        |> Query.execute()

      assert length(ref_results) >= 1
      ref_object = List.first(ref_results)
      ref_vector = ref_object["_additional"]["vector"]

      # Now search for similar objects using the vector
      query =
        Query.get(@test_collection)
        |> Query.near_vector(ref_vector, distance: 0.8)
        |> Query.fields(["title", "category"])
        |> Query.additional(["distance"])
        |> Query.limit(5)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) >= 1

      # First result should be the same object with distance ~0
      first = List.first(results)
      assert first["_additional"]["distance"] < 0.1
    end

    test "near_vector search with certainty threshold" do
      # Get a reference vector
      {:ok, ref_results} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.additional(["vector"])
        |> Query.limit(1)
        |> Query.execute()

      ref_vector = hd(ref_results)["_additional"]["vector"]

      query =
        Query.get(@test_collection)
        |> Query.near_vector(ref_vector, certainty: 0.5)
        |> Query.fields(["title"])
        |> Query.additional(["certainty"])
        |> Query.limit(3)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) >= 1
    end
  end

  describe "Pagination - limit and offset (live)" do
    test "limit restricts number of results" do
      query =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(3)

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 3
    end

    test "offset skips results" do
      # First get all results
      {:ok, all_results} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(10)
        |> Query.execute()

      # Then get with offset
      {:ok, offset_results} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(10)
        |> Query.offset(3)
        |> Query.execute()

      # Offset results should have fewer items
      assert length(offset_results) == length(all_results) - 3
    end

    test "limit and offset together for pagination" do
      # Page 1
      {:ok, page1} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(5)
        |> Query.offset(0)
        |> Query.execute()

      # Page 2
      {:ok, page2} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.limit(5)
        |> Query.offset(5)
        |> Query.execute()

      assert length(page1) == 5
      assert length(page2) >= 1

      # Pages should have different content
      page1_titles = Enum.map(page1, & &1["title"])
      page2_titles = Enum.map(page2, & &1["title"])
      assert MapSet.disjoint?(MapSet.new(page1_titles), MapSet.new(page2_titles))
    end
  end

  describe "Combined search operations (live)" do
    test "BM25 search with limit and offset" do
      query =
        Query.get(@test_collection)
        |> Query.bm25("Article")
        |> Query.fields(["title", "category"])
        |> Query.limit(3)
        |> Query.offset(2)

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "near_vector search with limit" do
      # Get reference vector
      {:ok, ref_results} =
        Query.get(@test_collection)
        |> Query.fields(["title"])
        |> Query.additional(["vector"])
        |> Query.limit(1)
        |> Query.execute()

      ref_vector = hd(ref_results)["_additional"]["vector"]

      query =
        Query.get(@test_collection)
        |> Query.near_vector(ref_vector)
        |> Query.fields(["title"])
        |> Query.limit(2)

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 2
    end
  end
end
