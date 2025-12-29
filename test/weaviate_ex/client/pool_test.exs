defmodule WeaviateEx.Client.PoolTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Client.Pool

  describe "new/1" do
    test "creates pool with default values" do
      pool = Pool.new()

      assert pool.size == 10
      assert pool.overflow == 5
      assert pool.strategy == :lifo
      assert pool.timeout == 5000
      assert pool.idle_timeout == 60_000
      assert pool.max_age == nil
    end

    test "creates pool with custom values" do
      pool =
        Pool.new(
          size: 20,
          overflow: 10,
          strategy: :fifo,
          timeout: 10_000,
          idle_timeout: 120_000,
          max_age: 300_000
        )

      assert pool.size == 20
      assert pool.overflow == 10
      assert pool.strategy == :fifo
      assert pool.timeout == 10_000
      assert pool.idle_timeout == 120_000
      assert pool.max_age == 300_000
    end
  end

  describe "default/0" do
    test "returns default pool configuration" do
      pool = Pool.default()

      assert %Pool{} = pool
      assert pool.size > 0
    end
  end

  describe "default_http/0" do
    test "returns default HTTP pool configuration" do
      pool = Pool.default_http()

      assert %Pool{} = pool
      assert pool.size == 10
    end
  end

  describe "default_grpc/0" do
    test "returns default gRPC pool configuration" do
      pool = Pool.default_grpc()

      assert %Pool{} = pool
      # gRPC typically uses fewer connections
      assert pool.size <= 10
    end
  end

  describe "to_finch_opts/1" do
    test "converts to Finch pool options" do
      pool = Pool.new(size: 15, overflow: 5)
      opts = Pool.to_finch_opts(pool)

      assert opts[:size] == 15
      assert opts[:count] == 1
    end
  end

  describe "to_grpc_opts/1" do
    test "converts to gRPC pool options" do
      pool = Pool.new(size: 5, timeout: 10_000)
      opts = Pool.to_grpc_opts(pool)

      assert is_list(opts)
    end
  end
end
