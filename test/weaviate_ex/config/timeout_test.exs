defmodule WeaviateEx.Config.TimeoutTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.Timeout

  describe "new/1" do
    test "creates timeout config with defaults" do
      timeout = Timeout.new()

      assert timeout.init == 2_000
      assert timeout.query == 30_000
      assert timeout.insert == 90_000
    end

    test "accepts custom init timeout" do
      timeout = Timeout.new(init: 5_000)

      assert timeout.init == 5_000
      assert timeout.query == 30_000
      assert timeout.insert == 90_000
    end

    test "accepts custom query timeout" do
      timeout = Timeout.new(query: 60_000)

      assert timeout.query == 60_000
    end

    test "accepts custom insert timeout" do
      timeout = Timeout.new(insert: 120_000)

      assert timeout.insert == 120_000
    end

    test "accepts all custom timeouts" do
      timeout = Timeout.new(init: 1_000, query: 10_000, insert: 50_000)

      assert timeout.init == 1_000
      assert timeout.query == 10_000
      assert timeout.insert == 50_000
    end
  end

  describe "for_method/2" do
    test "returns init timeout for init operations" do
      timeout = Timeout.new(init: 5_000)

      assert Timeout.for_method(timeout, :init) == 5_000
    end

    test "returns query timeout for GET requests" do
      timeout = Timeout.new(query: 30_000)

      assert Timeout.for_method(timeout, :get) == 30_000
    end

    test "returns insert timeout for POST requests" do
      timeout = Timeout.new(insert: 90_000)

      assert Timeout.for_method(timeout, :post) == 90_000
    end

    test "returns insert timeout for PUT requests" do
      timeout = Timeout.new(insert: 90_000)

      assert Timeout.for_method(timeout, :put) == 90_000
    end

    test "returns insert timeout for PATCH requests" do
      timeout = Timeout.new(insert: 90_000)

      assert Timeout.for_method(timeout, :patch) == 90_000
    end

    test "returns insert timeout for DELETE requests" do
      timeout = Timeout.new(insert: 90_000)

      assert Timeout.for_method(timeout, :delete) == 90_000
    end

    test "returns query timeout for unknown methods" do
      timeout = Timeout.new(query: 30_000)

      assert Timeout.for_method(timeout, :unknown) == 30_000
    end
  end

  describe "for_operation/2" do
    test "returns query timeout for search operations" do
      timeout = Timeout.new(query: 30_000)

      assert Timeout.for_operation(timeout, :search) == 30_000
      assert Timeout.for_operation(timeout, :query) == 30_000
      assert Timeout.for_operation(timeout, :aggregate) == 30_000
    end

    test "returns insert timeout for write operations" do
      timeout = Timeout.new(insert: 90_000)

      assert Timeout.for_operation(timeout, :insert) == 90_000
      assert Timeout.for_operation(timeout, :update) == 90_000
      assert Timeout.for_operation(timeout, :batch) == 90_000
    end
  end
end
