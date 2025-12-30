defmodule WeaviateEx.Aggregate.MetricsTest do
  @moduledoc """
  Tests for Aggregate.Metrics helper module.
  """

  use ExUnit.Case, async: true

  alias WeaviateEx.Aggregate.Metrics

  describe "count/0" do
    test "returns :count atom" do
      assert Metrics.count() == :count
    end
  end

  describe "text/2" do
    test "returns default topOccurrences metric" do
      assert {property, metrics, _opts} = Metrics.text("category")
      assert property == "category"
      assert :topOccurrences in metrics
    end

    test "includes count when specified" do
      {_property, metrics, _opts} = Metrics.text("category", count: true)
      assert :count in metrics
    end

    test "sets limit for topOccurrences" do
      {_property, metrics, opts} = Metrics.text("category", top_occurrences: 5)
      assert :topOccurrences in metrics
      assert opts[:limit] == 5
    end

    test "works with atom property name" do
      {property, _metrics, _opts} = Metrics.text(:category)
      assert property == :category
    end
  end

  describe "number/2" do
    test "returns default count metric when no options" do
      {property, metrics} = Metrics.number("price")
      assert property == "price"
      assert :count in metrics
    end

    test "includes sum when specified" do
      {_property, metrics} = Metrics.number("price", sum: true)
      assert :sum in metrics
    end

    test "includes mean when specified" do
      {_property, metrics} = Metrics.number("price", mean: true)
      assert :mean in metrics
    end

    test "includes median when specified" do
      {_property, metrics} = Metrics.number("price", median: true)
      assert :median in metrics
    end

    test "includes mode when specified" do
      {_property, metrics} = Metrics.number("price", mode: true)
      assert :mode in metrics
    end

    test "includes minimum when specified" do
      {_property, metrics} = Metrics.number("price", minimum: true)
      assert :minimum in metrics
    end

    test "includes maximum when specified" do
      {_property, metrics} = Metrics.number("price", maximum: true)
      assert :maximum in metrics
    end

    test "includes multiple metrics" do
      {_property, metrics} =
        Metrics.number("price", sum: true, mean: true, minimum: true, maximum: true)

      assert :sum in metrics
      assert :mean in metrics
      assert :minimum in metrics
      assert :maximum in metrics
    end

    test "works with atom property name" do
      {property, _metrics} = Metrics.number(:price, sum: true)
      assert property == :price
    end
  end

  describe "integer/2" do
    test "behaves same as number" do
      {property, metrics} = Metrics.integer("quantity", sum: true, mean: true)
      assert property == "quantity"
      assert :sum in metrics
      assert :mean in metrics
    end
  end

  describe "boolean/2" do
    test "returns all boolean metrics by default" do
      {property, metrics} = Metrics.boolean("inStock")
      assert property == "inStock"
      assert :percentageTrue in metrics
      assert :percentageFalse in metrics
      assert :totalTrue in metrics
      assert :totalFalse in metrics
    end

    test "includes only specified metrics" do
      {_property, metrics} =
        Metrics.boolean("inStock",
          percentage_true: true,
          percentage_false: true
        )

      assert :percentageTrue in metrics
      assert :percentageFalse in metrics
      refute :totalTrue in metrics
      refute :totalFalse in metrics
    end

    test "includes count when specified" do
      {_property, metrics} = Metrics.boolean("inStock", count: true)
      assert :count in metrics
    end

    test "works with atom property name" do
      {property, _metrics} = Metrics.boolean(:is_active)
      assert property == :is_active
    end
  end

  describe "date/2" do
    test "returns default minimum and maximum metrics" do
      {property, metrics} = Metrics.date("createdAt")
      assert property == "createdAt"
      assert :minimum in metrics
      assert :maximum in metrics
    end

    test "includes count when specified" do
      {_property, metrics} = Metrics.date("createdAt", count: true)
      assert :count in metrics
    end

    test "includes median when specified" do
      {_property, metrics} = Metrics.date("createdAt", median: true)
      assert :median in metrics
    end

    test "includes mode when specified" do
      {_property, metrics} = Metrics.date("createdAt", mode: true)
      assert :mode in metrics
    end

    test "includes minimum when specified" do
      {_property, metrics} = Metrics.date("createdAt", minimum: true)
      assert :minimum in metrics
    end

    test "includes maximum when specified" do
      {_property, metrics} = Metrics.date("createdAt", maximum: true)
      assert :maximum in metrics
    end

    test "works with atom property name" do
      {property, _metrics} = Metrics.date(:created_at, minimum: true)
      assert property == :created_at
    end
  end
end
