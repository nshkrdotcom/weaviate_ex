defmodule WeaviateEx.Integration.FilterTest do
  use ExUnit.Case, async: false
  alias WeaviateEx.{Batch, Collections, Query}

  @moduletag :integration

  @test_collection "FilterIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection with various data types for filtering
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "category", dataType: ["text"]},
          %{name: "score", dataType: ["int"]},
          %{name: "rating", dataType: ["number"]},
          %{name: "published", dataType: ["boolean"]},
          %{name: "tags", dataType: ["text[]"]}
        ],
        vectorizer: "none"
      })

    # Create diverse test data for filtering
    objects = [
      %{
        class: @test_collection,
        properties: %{
          title: "Alpha Article",
          category: "technology",
          score: 100,
          rating: 4.5,
          published: true,
          tags: ["tech", "software"]
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Beta Guide",
          category: "technology",
          score: 85,
          rating: 3.8,
          published: true,
          tags: ["tech", "guide"]
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Gamma Tutorial",
          category: "science",
          score: 92,
          rating: 4.2,
          published: false,
          tags: ["science", "research"]
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Delta Report",
          category: "science",
          score: 45,
          rating: 2.5,
          published: true,
          tags: ["science", "analysis"]
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Epsilon Overview",
          category: "business",
          score: 78,
          rating: 3.9,
          published: false,
          tags: ["business", "overview"]
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      }
    ]

    {:ok, _} = Batch.create_objects(objects)

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    :ok
  end

  describe "Equal operator on text (live)" do
    test "filters by exact text match" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["category"],
          operator: "Equal",
          valueText: "technology"
        })
        |> Query.fields(["title", "category"])

      assert {:ok, results} = Query.execute(query)
      assert is_list(results)
      assert length(results) == 2
      assert Enum.all?(results, fn r -> r["category"] == "technology" end)
    end

    test "filters by exact text match on title" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["title"],
          operator: "Equal",
          valueText: "Alpha Article"
        })
        |> Query.fields(["title", "score"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 1
      assert hd(results)["title"] == "Alpha Article"
    end

    test "returns empty for non-matching Equal filter" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["category"],
          operator: "Equal",
          valueText: "nonexistent"
        })
        |> Query.fields(["title"])

      assert {:ok, results} = Query.execute(query)
      assert results == []
    end
  end

  describe "GreaterThan operator on numbers (live)" do
    test "filters integers with GreaterThan" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["score"],
          operator: "GreaterThan",
          valueInt: 80
        })
        |> Query.fields(["title", "score"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> r["score"] > 80 end)
    end

    test "filters with GreaterThanEqual" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["score"],
          operator: "GreaterThanEqual",
          valueInt: 92
        })
        |> Query.fields(["title", "score"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> r["score"] >= 92 end)
    end

    test "filters floats with GreaterThan using valueNumber" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["rating"],
          operator: "GreaterThan",
          valueNumber: 4.0
        })
        |> Query.fields(["title", "rating"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> r["rating"] > 4.0 end)
    end
  end

  describe "Like operator (wildcard) (live)" do
    test "filters with wildcard prefix" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["title"],
          operator: "Like",
          valueText: "*Article"
        })
        |> Query.fields(["title"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> String.ends_with?(r["title"], "Article") end)
    end

    test "filters with wildcard suffix" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["title"],
          operator: "Like",
          valueText: "Alpha*"
        })
        |> Query.fields(["title"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      assert Enum.all?(results, fn r -> String.starts_with?(r["title"], "Alpha") end)
    end

    test "filters with wildcard in middle" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["title"],
          operator: "Like",
          valueText: "*a*"
        })
        |> Query.fields(["title"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1
      # All results should contain 'a' (case-insensitive behavior may vary)
    end
  end

  describe "Boolean filters (live)" do
    test "filters by boolean true" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["published"],
          operator: "Equal",
          valueBoolean: true
        })
        |> Query.fields(["title", "published"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 3
      assert Enum.all?(results, fn r -> r["published"] == true end)
    end

    test "filters by boolean false" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["published"],
          operator: "Equal",
          valueBoolean: false
        })
        |> Query.fields(["title", "published"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 2
      assert Enum.all?(results, fn r -> r["published"] == false end)
    end
  end

  describe "AND/OR combinations (live)" do
    test "filters with AND operator" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          operator: "And",
          operands: [
            %{path: ["category"], operator: "Equal", valueText: "technology"},
            %{path: ["score"], operator: "GreaterThan", valueInt: 80}
          ]
        })
        |> Query.fields(["title", "category", "score"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1

      assert Enum.all?(results, fn r ->
               r["category"] == "technology" and r["score"] > 80
             end)
    end

    test "filters with OR operator" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          operator: "Or",
          operands: [
            %{path: ["category"], operator: "Equal", valueText: "technology"},
            %{path: ["category"], operator: "Equal", valueText: "business"}
          ]
        })
        |> Query.fields(["title", "category"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 3

      assert Enum.all?(results, fn r ->
               r["category"] == "technology" or r["category"] == "business"
             end)
    end

    test "filters with nested AND and OR" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          operator: "And",
          operands: [
            %{path: ["published"], operator: "Equal", valueBoolean: true},
            %{
              operator: "Or",
              operands: [
                %{path: ["category"], operator: "Equal", valueText: "technology"},
                %{path: ["score"], operator: "GreaterThan", valueInt: 90}
              ]
            }
          ]
        })
        |> Query.fields(["title", "category", "score", "published"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1

      assert Enum.all?(results, fn r ->
               r["published"] == true and
                 (r["category"] == "technology" or r["score"] > 90)
             end)
    end

    test "filters with LessThan in combination" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          operator: "And",
          operands: [
            %{path: ["score"], operator: "GreaterThan", valueInt: 40},
            %{path: ["score"], operator: "LessThan", valueInt: 90}
          ]
        })
        |> Query.fields(["title", "score"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) >= 1

      assert Enum.all?(results, fn r ->
               r["score"] > 40 and r["score"] < 90
             end)
    end
  end

  describe "NotEqual operator (live)" do
    test "filters with NotEqual on text" do
      query =
        Query.get(@test_collection)
        |> Query.where(%{
          path: ["category"],
          operator: "NotEqual",
          valueText: "technology"
        })
        |> Query.fields(["title", "category"])

      assert {:ok, results} = Query.execute(query)
      assert length(results) == 3
      assert Enum.all?(results, fn r -> r["category"] != "technology" end)
    end
  end
end
