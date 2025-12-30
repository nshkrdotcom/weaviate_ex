defmodule WeaviateEx.Protocol.HTTP.TimeoutTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.Timeout
  alias WeaviateEx.Protocol.HTTP.Timeout, as: HTTPTimeout

  describe "for_operation/2" do
    test "returns query timeout for :query operation" do
      config = Timeout.new(query: 30_000)
      assert HTTPTimeout.for_operation(config, :query) == 30_000
    end

    test "returns insert timeout for :insert operation" do
      config = Timeout.new(insert: 90_000)
      assert HTTPTimeout.for_operation(config, :insert) == 90_000
    end

    test "returns init timeout for :init operation" do
      config = Timeout.new(init: 2_000)
      assert HTTPTimeout.for_operation(config, :init) == 2_000
    end

    test "returns extended timeout for :batch operation" do
      config = Timeout.new(insert: 90_000)
      timeout = HTTPTimeout.for_operation(config, :batch)
      # Batch should be insert * 10
      assert timeout == 900_000
    end

    test "returns query timeout for :search operation" do
      config = Timeout.new(query: 30_000)
      assert HTTPTimeout.for_operation(config, :search) == 30_000
    end

    test "returns query timeout for :aggregate operation" do
      config = Timeout.new(query: 30_000)
      assert HTTPTimeout.for_operation(config, :aggregate) == 30_000
    end

    test "returns insert timeout for :update operation" do
      config = Timeout.new(insert: 90_000)
      assert HTTPTimeout.for_operation(config, :update) == 90_000
    end

    test "returns insert timeout for :delete operation" do
      config = Timeout.new(insert: 90_000)
      assert HTTPTimeout.for_operation(config, :delete) == 90_000
    end

    test "uses default for unknown operation" do
      config = Timeout.new(query: 30_000)
      assert HTTPTimeout.for_operation(config, :unknown_operation) == 30_000
    end

    test "uses default config when nil is passed" do
      timeout = HTTPTimeout.for_operation(nil, :query)
      assert timeout == 30_000
    end
  end

  describe "batch_multiplier/0" do
    test "returns the batch timeout multiplier" do
      assert HTTPTimeout.batch_multiplier() == 10
    end
  end

  describe "operation_category/1" do
    test "returns :query for query operations" do
      assert HTTPTimeout.operation_category(:query) == :query
      assert HTTPTimeout.operation_category(:search) == :query
      assert HTTPTimeout.operation_category(:aggregate) == :query
      assert HTTPTimeout.operation_category(:get) == :query
    end

    test "returns :insert for write operations" do
      assert HTTPTimeout.operation_category(:insert) == :insert
      assert HTTPTimeout.operation_category(:update) == :insert
      assert HTTPTimeout.operation_category(:delete) == :insert
      assert HTTPTimeout.operation_category(:create) == :insert
    end

    test "returns :batch for batch operation" do
      assert HTTPTimeout.operation_category(:batch) == :batch
    end

    test "returns :init for init operation" do
      assert HTTPTimeout.operation_category(:init) == :init
    end

    test "returns :query for unknown operations" do
      assert HTTPTimeout.operation_category(:unknown) == :query
    end
  end
end
