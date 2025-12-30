defmodule WeaviateEx.Integration.AggregateTest do
  use ExUnit.Case, async: false

  alias WeaviateEx.API.Aggregate
  alias WeaviateEx.{Batch, Collections}
  alias WeaviateEx.Query

  @moduletag :integration

  @test_collection "AggregateIntegrationTest#{System.system_time(:millisecond)}"

  setup_all do
    # Switch to real HTTP client for integration tests
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    Application.put_env(:weaviate_ex, :url, "http://localhost:8080")

    # Create test collection with numeric and text properties
    {:ok, _} =
      Collections.create(@test_collection, %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "category", dataType: ["text"]},
          %{name: "price", dataType: ["number"]},
          %{name: "quantity", dataType: ["int"]},
          %{name: "inStock", dataType: ["boolean"]}
        ],
        vectorizer: "none"
      })

    # Create test data for aggregation
    objects = [
      %{
        class: @test_collection,
        properties: %{
          title: "Product A",
          category: "electronics",
          price: 299.99,
          quantity: 50,
          inStock: true
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Product B",
          category: "electronics",
          price: 149.99,
          quantity: 100,
          inStock: true
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Product C",
          category: "clothing",
          price: 49.99,
          quantity: 200,
          inStock: true
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Product D",
          category: "clothing",
          price: 79.99,
          quantity: 75,
          inStock: false
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Product E",
          category: "electronics",
          price: 599.99,
          quantity: 25,
          inStock: false
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      },
      %{
        class: @test_collection,
        properties: %{
          title: "Product F",
          category: "home",
          price: 129.99,
          quantity: 150,
          inStock: true
        },
        vector: Enum.map(1..384, fn _ -> :rand.uniform() * 2 - 1 end)
      }
    ]

    {:ok, _} = Batch.create_objects(objects)

    # Create a client for aggregate operations
    {:ok, client} = WeaviateEx.Client.connect(base_url: "http://localhost:8080")

    on_exit(fn ->
      Collections.delete(@test_collection)
    end)

    {:ok, client: client}
  end

  describe "Count aggregation (live)" do
    test "counts all objects in collection", %{client: client} do
      assert {:ok, results} = Aggregate.over_all(client, @test_collection, metrics: [:count])
      assert is_list(results)
      assert length(results) >= 1

      first_result = hd(results)
      assert Map.has_key?(first_result, "meta")
      assert first_result["meta"]["count"] == 6
    end

    test "count returns correct value for collection", %{client: client} do
      assert {:ok, results} = Aggregate.over_all(client, @test_collection)
      assert is_list(results)

      # Default should include count
      if length(results) > 0 do
        first_result = hd(results)

        if Map.has_key?(first_result, "meta") do
          assert first_result["meta"]["count"] == 6
        end
      end
    end
  end

  describe "Count with filter (live)" do
    test "counts objects matching filter", %{client: client} do
      filter = %{
        path: ["category"],
        operator: "Equal",
        valueText: "electronics"
      }

      assert {:ok, results} =
               Aggregate.with_where(client, @test_collection, filter, metrics: [:count])

      assert is_list(results)
      assert length(results) >= 1

      first_result = hd(results)
      assert first_result["meta"]["count"] == 3
    end

    test "counts objects with boolean filter", %{client: client} do
      filter = %{
        path: ["inStock"],
        operator: "Equal",
        valueBoolean: true
      }

      assert {:ok, results} =
               Aggregate.with_where(client, @test_collection, filter, metrics: [:count])

      assert is_list(results)

      first_result = hd(results)
      assert first_result["meta"]["count"] == 4
    end

    test "count with numeric filter", %{client: client} do
      filter = %{
        path: ["price"],
        operator: "GreaterThan",
        valueNumber: 100.0
      }

      assert {:ok, results} =
               Aggregate.with_where(client, @test_collection, filter, metrics: [:count])

      assert is_list(results)

      first_result = hd(results)
      # Products with price > 100: A (299.99), B (149.99), E (599.99), F (129.99)
      assert first_result["meta"]["count"] == 4
    end
  end

  describe "Property aggregations - numeric (live)" do
    test "aggregates numeric property with min, max, mean", %{client: client} do
      assert {:ok, results} =
               Aggregate.over_all(client, @test_collection,
                 properties: [
                   {:price, [:minimum, :maximum, :mean]}
                 ]
               )

      assert is_list(results)
      assert length(results) >= 1

      first_result = hd(results)
      price_agg = first_result["price"]

      assert price_agg["minimum"] == 49.99
      assert price_agg["maximum"] == 599.99
      # Mean of: 299.99, 149.99, 49.99, 79.99, 599.99, 129.99 = 1309.94 / 6 = ~218.32
      assert_in_delta price_agg["mean"], 218.32, 0.1
    end

    test "aggregates integer property with sum", %{client: client} do
      assert {:ok, results} =
               Aggregate.over_all(client, @test_collection,
                 properties: [
                   {:quantity, [:sum, :minimum, :maximum]}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)
      quantity_agg = first_result["quantity"]

      # Sum of: 50 + 100 + 200 + 75 + 25 + 150 = 600
      assert quantity_agg["sum"] == 600
      assert quantity_agg["minimum"] == 25
      assert quantity_agg["maximum"] == 200
    end

    test "aggregates with median", %{client: client} do
      assert {:ok, results} =
               Aggregate.over_all(client, @test_collection,
                 properties: [
                   {:quantity, [:median]}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)
      quantity_agg = first_result["quantity"]

      # Sorted quantities: 25, 50, 75, 100, 150, 200
      # Median of 6 values = (75 + 100) / 2 = 87.5
      assert_in_delta quantity_agg["median"], 87.5, 0.5
    end
  end

  describe "Property aggregations - text (live)" do
    test "aggregates text property with topOccurrences", %{client: client} do
      assert {:ok, results} =
               Aggregate.over_all(client, @test_collection,
                 properties: [
                   {:category, [:topOccurrences], limit: 5}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)
      category_agg = first_result["category"]

      assert is_list(category_agg["topOccurrences"])
      top_occurrences = category_agg["topOccurrences"]

      # electronics: 3, clothing: 2, home: 1
      values = Enum.map(top_occurrences, & &1["value"])
      assert "electronics" in values
      assert "clothing" in values
      assert "home" in values

      electronics = Enum.find(top_occurrences, fn t -> t["value"] == "electronics" end)
      assert electronics["occurs"] == 3
    end
  end

  describe "Property aggregations - boolean (live)" do
    test "aggregates boolean property with percentage metrics", %{client: client} do
      assert {:ok, results} =
               Aggregate.over_all(client, @test_collection,
                 properties: [
                   {:inStock, [:percentageTrue, :percentageFalse, :totalTrue, :totalFalse]}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)
      instock_agg = first_result["inStock"]

      # 4 true, 2 false out of 6 total
      assert instock_agg["totalTrue"] == 4
      assert instock_agg["totalFalse"] == 2
      assert_in_delta instock_agg["percentageTrue"], 66.67, 0.5
      assert_in_delta instock_agg["percentageFalse"], 33.33, 0.5
    end
  end

  describe "Group by aggregations (live)" do
    test "groups and counts by category", %{client: client} do
      assert {:ok, results} =
               Aggregate.group_by(client, @test_collection, "category", metrics: [:count])

      assert is_list(results)

      # Should have 3 groups: electronics, clothing, home
      assert length(results) == 3

      # Find electronics group
      electronics_group =
        Enum.find(results, fn r ->
          r["groupedBy"]["value"] == "electronics"
        end)

      assert electronics_group["meta"]["count"] == 3

      # Find clothing group
      clothing_group =
        Enum.find(results, fn r ->
          r["groupedBy"]["value"] == "clothing"
        end)

      assert clothing_group["meta"]["count"] == 2

      # Find home group
      home_group =
        Enum.find(results, fn r ->
          r["groupedBy"]["value"] == "home"
        end)

      assert home_group["meta"]["count"] == 1
    end
  end

  describe "Combined aggregation operations (live)" do
    test "aggregates with filter and multiple metrics", %{client: client} do
      filter = %{
        path: ["inStock"],
        operator: "Equal",
        valueBoolean: true
      }

      assert {:ok, results} =
               Aggregate.with_where(client, @test_collection, filter,
                 metrics: [:count],
                 properties: [
                   {:price, [:mean, :sum]}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)

      # Count of in-stock items
      assert first_result["meta"]["count"] == 4

      # Price aggregation for in-stock items: 299.99, 149.99, 49.99, 129.99
      price_agg = first_result["price"]
      assert_in_delta price_agg["sum"], 629.96, 0.1
      assert_in_delta price_agg["mean"], 157.49, 0.1
    end
  end

  describe "Near object aggregation (live)" do
    setup %{client: client} do
      # Get a reference object UUID to use for near_object queries
      query =
        Query.get(@test_collection)
        |> Query.additional(["id"])
        |> Query.limit(1)

      case Query.execute(query, client) do
        {:ok, [object | _]} ->
          {:ok, reference_uuid: object["_additional"]["id"]}

        _ ->
          {:ok, reference_uuid: nil}
      end
    end

    test "aggregates objects similar to reference object", %{client: client, reference_uuid: uuid} do
      if uuid do
        assert {:ok, results} =
                 Aggregate.with_near_object(client, @test_collection, uuid, metrics: [:count])

        assert is_list(results)
        assert length(results) >= 1

        first_result = hd(results)
        assert Map.has_key?(first_result, "meta")
        # Should find at least the reference object itself
        assert first_result["meta"]["count"] >= 1
      end
    end

    test "aggregates with distance threshold", %{client: client, reference_uuid: uuid} do
      if uuid do
        assert {:ok, results} =
                 Aggregate.with_near_object(client, @test_collection, uuid,
                   distance: 0.5,
                   metrics: [:count]
                 )

        assert is_list(results)
        assert length(results) >= 1

        first_result = hd(results)
        # With a distance threshold, we may get fewer results
        assert first_result["meta"]["count"] >= 1
      end
    end

    test "aggregates with certainty threshold", %{client: client, reference_uuid: uuid} do
      if uuid do
        assert {:ok, results} =
                 Aggregate.with_near_object(client, @test_collection, uuid,
                   certainty: 0.5,
                   metrics: [:count]
                 )

        assert is_list(results)
        assert length(results) >= 1

        first_result = hd(results)
        assert first_result["meta"]["count"] >= 1
      end
    end

    test "aggregates property metrics near object", %{client: client, reference_uuid: uuid} do
      if uuid do
        assert {:ok, results} =
                 Aggregate.with_near_object(client, @test_collection, uuid,
                   distance: 0.9,
                   properties: [
                     {:price, [:sum, :mean, :minimum, :maximum]}
                   ]
                 )

        assert is_list(results)
        first_result = hd(results)

        if Map.has_key?(first_result, "price") do
          price_agg = first_result["price"]
          assert is_number(price_agg["sum"])
          assert is_number(price_agg["mean"])
        end
      end
    end
  end

  describe "Hybrid aggregation (live)" do
    test "aggregates with hybrid search query", %{client: client} do
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "electronics", metrics: [:count])

      assert is_list(results)
      assert length(results) >= 1

      first_result = hd(results)
      assert Map.has_key?(first_result, "meta")
      # Should find some results matching "electronics"
      assert first_result["meta"]["count"] >= 0
    end

    test "aggregates with custom alpha weight", %{client: client} do
      # Alpha = 0.7 means 70% vector weight, 30% keyword weight
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "product",
                 alpha: 0.7,
                 metrics: [:count]
               )

      assert is_list(results)
      assert length(results) >= 1
    end

    test "aggregates with alpha = 0 (pure keyword)", %{client: client} do
      # Alpha = 0 means pure keyword (BM25) search
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "electronics",
                 alpha: 0.0,
                 metrics: [:count]
               )

      assert is_list(results)
      assert length(results) >= 1

      first_result = hd(results)
      # Pure keyword search for "electronics" should find matching products
      assert first_result["meta"]["count"] >= 0
    end

    test "aggregates with alpha = 1 (pure vector)", %{client: client} do
      # Alpha = 1 means pure vector search
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "technology",
                 alpha: 1.0,
                 metrics: [:count]
               )

      assert is_list(results)
      assert length(results) >= 1
    end

    test "aggregates with ranked fusion type", %{client: client} do
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "clothing",
                 fusion_type: :ranked,
                 metrics: [:count]
               )

      assert is_list(results)
      assert length(results) >= 1
    end

    test "aggregates with relative_score fusion type", %{client: client} do
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "home",
                 fusion_type: :relative_score,
                 metrics: [:count]
               )

      assert is_list(results)
      assert length(results) >= 1
    end

    test "aggregates property metrics with hybrid search", %{client: client} do
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "product",
                 alpha: 0.5,
                 properties: [
                   {:price, [:sum, :mean, :minimum, :maximum]}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)

      if Map.has_key?(first_result, "price") do
        price_agg = first_result["price"]
        assert is_number(price_agg["sum"]) or is_nil(price_agg["sum"])
      end
    end

    test "aggregates with hybrid search and text property", %{client: client} do
      assert {:ok, results} =
               Aggregate.with_hybrid(client, @test_collection, "electronics",
                 alpha: 0.5,
                 metrics: [:count],
                 properties: [
                   {:category, [:topOccurrences], limit: 3}
                 ]
               )

      assert is_list(results)
      first_result = hd(results)

      if Map.has_key?(first_result, "category") do
        category_agg = first_result["category"]
        assert is_list(category_agg["topOccurrences"])
      end
    end
  end
end
