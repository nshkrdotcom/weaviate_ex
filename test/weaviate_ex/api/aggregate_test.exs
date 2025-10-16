defmodule WeaviateEx.API.AggregateTest do
  @moduledoc """
  Tests for aggregation operations (Phase 2.2).

  Following TDD approach - tests written first, then stub, then implementation.
  """

  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Aggregate
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "over_all/3" do
    test "aggregates entire collection with count metric", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/graphql"
        assert body["query"] =~ "Aggregate"
        assert body["query"] =~ "Article"
        assert body["query"] =~ "meta"
        assert body["query"] =~ "count"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 150}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} = Aggregate.over_all(client, "Article", metrics: [:count])
      assert is_list(results)
      assert length(results) == 1
      assert hd(results)["meta"]["count"] == 150
    end

    test "aggregates with multiple numeric metrics", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        # Should request sum, mean, max, min for price
        assert body["query"] =~ "price"
        assert body["query"] =~ "sum"
        assert body["query"] =~ "mean"
        assert body["query"] =~ "maximum"
        assert body["query"] =~ "minimum"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Product" => [
                 %{
                   "price" => %{
                     "sum" => 15_000.50,
                     "mean" => 150.00,
                     "maximum" => 999.99,
                     "minimum" => 9.99,
                     "count" => 100
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.over_all(client, "Product",
                 properties: [
                   {:price, [:sum, :mean, :maximum, :minimum, :count]}
                 ]
               )

      assert length(results) == 1
      result = hd(results)
      assert result["price"]["sum"] == 15_000.50
      assert result["price"]["mean"] == 150.00
    end

    test "aggregates text property with topOccurrences", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "category"
        assert body["query"] =~ "topOccurrences"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "category" => %{
                     "topOccurrences" => [
                       %{"value" => "technology", "occurs" => 45},
                       %{"value" => "science", "occurs" => 32},
                       %{"value" => "business", "occurs" => 23}
                     ]
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.over_all(client, "Article",
                 properties: [
                   {:category, [:topOccurrences], limit: 3}
                 ]
               )

      result = hd(results)
      top_categories = result["category"]["topOccurrences"]
      assert length(top_categories) == 3
      assert hd(top_categories)["value"] == "technology"
    end

    test "handles empty collection aggregation", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 0}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} = Aggregate.over_all(client, "Article", metrics: [:count])
      assert hd(results)["meta"]["count"] == 0
    end

    test "handles connection error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
               Aggregate.over_all(client, "Article")
    end
  end

  describe "with_near_text/4" do
    test "aggregates with semantic search context", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "Aggregate"
        assert body["query"] =~ "nearText"
        assert body["query"] =~ "artificial intelligence"
        assert body["query"] =~ "meta"
        assert body["query"] =~ "count"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 42}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.with_near_text(client, "Article", "artificial intelligence",
                 metrics: [:count]
               )

      assert hd(results)["meta"]["count"] == 42
    end

    test "aggregates with near_text and certainty threshold", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearText"
        assert body["query"] =~ "certainty"
        assert body["query"] =~ "0.7"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 15}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.with_near_text(client, "Article", "machine learning",
                 certainty: 0.7,
                 metrics: [:count]
               )

      assert hd(results)["meta"]["count"] == 15
    end

    test "aggregates metrics on semantically similar results", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearText"
        assert body["query"] =~ "views"
        assert body["query"] =~ "mean"
        assert body["query"] =~ "sum"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "views" => %{
                     "mean" => 1250.5,
                     "sum" => 50_020,
                     "count" => 40
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.with_near_text(client, "Article", "popular topics",
                 properties: [
                   {:views, [:mean, :sum, :count]}
                 ]
               )

      result = hd(results)
      assert result["views"]["mean"] == 1250.5
      assert result["views"]["count"] == 40
    end
  end

  describe "with_near_vector/4" do
    test "aggregates with vector similarity search", %{client: client} do
      vector = Enum.map(1..1536, fn _ -> :rand.uniform() end)

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "Aggregate"
        assert body["query"] =~ "nearVector"
        assert body["query"] =~ "vector:"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 25}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.with_near_vector(client, "Article", vector, metrics: [:count])

      assert hd(results)["meta"]["count"] == 25
    end
  end

  describe "with_where/4" do
    test "aggregates with filter conditions", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "Aggregate"
        assert body["query"] =~ "where"
        assert body["query"] =~ "status"
        assert body["query"] =~ "published"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "meta" => %{"count" => 87}
                 }
               ]
             }
           }
         }}
      end)

      filter = %{
        path: ["status"],
        operator: "Equal",
        valueText: "published"
      }

      assert {:ok, results} =
               Aggregate.with_where(client, "Article", filter, metrics: [:count])

      assert hd(results)["meta"]["count"] == 87
    end
  end

  describe "group_by/4" do
    test "aggregates results grouped by property", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "Aggregate"
        assert body["query"] =~ "groupedBy"
        assert body["query"] =~ "category"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "groupedBy" => %{"value" => "technology"},
                   "meta" => %{"count" => 45}
                 },
                 %{
                   "groupedBy" => %{"value" => "science"},
                   "meta" => %{"count" => 32}
                 },
                 %{
                   "groupedBy" => %{"value" => "business"},
                   "meta" => %{"count" => 23}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.group_by(client, "Article", "category", metrics: [:count])

      assert length(results) == 3
      assert Enum.at(results, 0)["groupedBy"]["value"] == "technology"
      assert Enum.at(results, 0)["meta"]["count"] == 45
    end

    test "groups by property with aggregated metrics", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "groupedBy"
        assert body["query"] =~ "author"
        assert body["query"] =~ "views"
        assert body["query"] =~ "mean"
        assert body["query"] =~ "sum"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => [
                 %{
                   "groupedBy" => %{"value" => "John Doe"},
                   "views" => %{"mean" => 2500.0, "sum" => 25_000},
                   "meta" => %{"count" => 10}
                 },
                 %{
                   "groupedBy" => %{"value" => "Jane Smith"},
                   "views" => %{"mean" => 3200.0, "sum" => 32_000},
                   "meta" => %{"count" => 10}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.group_by(client, "Article", "author",
                 properties: [
                   {:views, [:mean, :sum]}
                 ],
                 metrics: [:count]
               )

      assert length(results) == 2
      first_group = Enum.at(results, 0)
      assert first_group["groupedBy"]["value"] == "John Doe"
      assert first_group["views"]["mean"] == 2500.0
    end

    test "groups by nested property path", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "groupedBy"
        # Nested path: author.name
        assert body["query"] =~ ~r/author.*name/

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Article" => []
             }
           }
         }}
      end)

      assert {:ok, []} =
               Aggregate.group_by(client, "Article", "author.name", metrics: [:count])
    end
  end

  describe "all available metrics" do
    test "supports all numeric metrics", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        # All numeric aggregation metrics
        assert body["query"] =~ "count"
        assert body["query"] =~ "sum"
        assert body["query"] =~ "mean"
        assert body["query"] =~ "median"
        assert body["query"] =~ "mode"
        assert body["query"] =~ "maximum"
        assert body["query"] =~ "minimum"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "Product" => [
                 %{
                   "price" => %{
                     "count" => 100,
                     "sum" => 10_000.0,
                     "mean" => 100.0,
                     "median" => 95.0,
                     "mode" => 89.99,
                     "maximum" => 999.99,
                     "minimum" => 9.99
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.over_all(client, "Product",
                 properties: [
                   {:price, [:count, :sum, :mean, :median, :mode, :maximum, :minimum]}
                 ]
               )

      result = hd(results)
      assert result["price"]["count"] == 100
      assert result["price"]["mean"] == 100.0
      assert result["price"]["median"] == 95.0
    end

    test "supports boolean aggregation with percentage", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "isActive"
        assert body["query"] =~ "percentageTrue"
        assert body["query"] =~ "percentageFalse"
        assert body["query"] =~ "totalTrue"
        assert body["query"] =~ "totalFalse"

        {:ok,
         %{
           "data" => %{
             "Aggregate" => %{
               "User" => [
                 %{
                   "isActive" => %{
                     "count" => 200,
                     "percentageTrue" => 75.5,
                     "percentageFalse" => 24.5,
                     "totalTrue" => 151,
                     "totalFalse" => 49
                   }
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               Aggregate.over_all(client, "User",
                 properties: [
                   {:isActive,
                    [:count, :percentageTrue, :percentageFalse, :totalTrue, :totalFalse]}
                 ]
               )

      result = hd(results)
      assert result["isActive"]["percentageTrue"] == 75.5
      assert result["isActive"]["totalTrue"] == 151
    end
  end
end
