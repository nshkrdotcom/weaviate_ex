defmodule WeaviateEx.GRPC.Services.AggregateTest do
  use ExUnit.Case, async: true

  alias Weaviate.V1.AggregateRequest

  @moduletag :grpc

  describe "AggregateRequest protobuf" do
    test "can create with collection" do
      request = %AggregateRequest{collection: "Article"}
      assert request.collection == "Article"
    end

    test "supports tenant field" do
      request = %AggregateRequest{
        collection: "Article",
        tenant: "tenant-a"
      }

      assert request.tenant == "tenant-a"
    end

    test "supports objects_count field" do
      request = %AggregateRequest{
        collection: "Article",
        objects_count: true
      }

      assert request.objects_count == true
    end

    test "supports aggregations list" do
      request = %AggregateRequest{
        collection: "Article",
        aggregations: []
      }

      assert request.aggregations == []
    end
  end

  describe "AggregateRequest.Aggregation protobuf" do
    test "can create number aggregation" do
      agg = %AggregateRequest.Aggregation{
        property: "wordCount",
        aggregation:
          {:number,
           %AggregateRequest.Aggregation.Number{
             count: true,
             sum: true,
             mean: true
           }}
      }

      assert agg.property == "wordCount"
      assert {:number, _} = agg.aggregation
    end

    test "can create integer aggregation" do
      agg = %AggregateRequest.Aggregation{
        property: "views",
        aggregation:
          {:int,
           %AggregateRequest.Aggregation.Integer{
             count: true,
             minimum: true,
             maximum: true
           }}
      }

      assert agg.property == "views"
      assert {:int, _} = agg.aggregation
    end

    test "can create text aggregation" do
      agg = %AggregateRequest.Aggregation{
        property: "category",
        aggregation:
          {:text,
           %AggregateRequest.Aggregation.Text{
             count: true,
             top_occurences: true,
             top_occurences_limit: 10
           }}
      }

      assert agg.property == "category"
      assert {:text, _} = agg.aggregation
    end

    test "can create boolean aggregation" do
      agg = %AggregateRequest.Aggregation{
        property: "isPublished",
        aggregation:
          {:boolean,
           %AggregateRequest.Aggregation.Boolean{
             count: true,
             total_true: true,
             total_false: true,
             percentage_true: true
           }}
      }

      assert agg.property == "isPublished"
      assert {:boolean, _} = agg.aggregation
    end

    test "can create date aggregation" do
      agg = %AggregateRequest.Aggregation{
        property: "publishedAt",
        aggregation:
          {:date,
           %AggregateRequest.Aggregation.Date{
             count: true,
             minimum: true,
             maximum: true
           }}
      }

      assert agg.property == "publishedAt"
      assert {:date, _} = agg.aggregation
    end
  end

  describe "AggregateRequest.GroupBy protobuf" do
    test "can create with collection and property" do
      group_by = %AggregateRequest.GroupBy{
        collection: "Article",
        property: "category"
      }

      assert group_by.collection == "Article"
      assert group_by.property == "category"
    end
  end

  describe "number aggregations" do
    test "Number struct supports all stats fields" do
      num_agg = %AggregateRequest.Aggregation.Number{
        count: true,
        sum: true,
        mean: true,
        median: true,
        mode: true,
        minimum: true,
        maximum: true
      }

      assert num_agg.count == true
      assert num_agg.sum == true
      assert num_agg.mean == true
      assert num_agg.median == true
      assert num_agg.mode == true
      assert num_agg.minimum == true
      assert num_agg.maximum == true
    end
  end

  describe "text aggregations" do
    test "Text struct supports count and top occurrences" do
      text_agg = %AggregateRequest.Aggregation.Text{
        count: true,
        top_occurences: true,
        top_occurences_limit: 5
      }

      assert text_agg.count == true
      assert text_agg.top_occurences == true
      assert text_agg.top_occurences_limit == 5
    end
  end

  describe "boolean aggregations" do
    test "Boolean struct supports all boolean stats" do
      bool_agg = %AggregateRequest.Aggregation.Boolean{
        count: true,
        total_true: true,
        total_false: true,
        percentage_true: true,
        percentage_false: true
      }

      assert bool_agg.count == true
      assert bool_agg.total_true == true
      assert bool_agg.total_false == true
      assert bool_agg.percentage_true == true
      assert bool_agg.percentage_false == true
    end
  end

  describe "integer aggregations" do
    test "Integer struct supports all stats fields" do
      int_agg = %AggregateRequest.Aggregation.Integer{
        count: true,
        sum: true,
        mean: true,
        median: true,
        mode: true,
        minimum: true,
        maximum: true
      }

      assert int_agg.count == true
      assert int_agg.sum == true
      assert int_agg.minimum == true
      assert int_agg.maximum == true
    end
  end

  describe "date aggregations" do
    test "Date struct supports min, max, and count" do
      date_agg = %AggregateRequest.Aggregation.Date{
        count: true,
        minimum: true,
        maximum: true,
        median: true,
        mode: true
      }

      assert date_agg.count == true
      assert date_agg.minimum == true
      assert date_agg.maximum == true
    end
  end
end
