defmodule WeaviateEx.Config.ConnectionTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.Connection

  describe "new/1" do
    test "creates connection config with defaults" do
      config = Connection.new([])

      assert config.pool_size == 10
      assert config.max_connections == 100
      assert config.pool_timeout == 5_000
    end

    test "accepts custom pool_size" do
      config = Connection.new(pool_size: 20)

      assert config.pool_size == 20
    end

    test "accepts custom max_connections" do
      config = Connection.new(max_connections: 200)

      assert config.max_connections == 200
    end

    test "accepts custom pool_timeout" do
      config = Connection.new(pool_timeout: 10_000)

      assert config.pool_timeout == 10_000
    end

    test "validates pool_size is positive" do
      assert_raise ArgumentError, fn ->
        Connection.new(pool_size: 0)
      end
    end

    test "validates max_connections is positive" do
      assert_raise ArgumentError, fn ->
        Connection.new(max_connections: 0)
      end
    end
  end

  describe "to_finch_opts/1" do
    test "converts to Finch pool options" do
      config = Connection.new(pool_size: 15, pool_timeout: 8_000)

      opts = Connection.to_finch_opts(config)

      assert opts[:size] == 15
      assert opts[:pool_timeout] == 8_000
    end

    test "calculates pool count from max_connections" do
      config = Connection.new(pool_size: 10, max_connections: 50)

      opts = Connection.to_finch_opts(config)

      assert opts[:count] == 5
    end

    test "includes max idle time for Finch connections" do
      config = Connection.new(max_idle_time: 45_000)

      opts = Connection.to_finch_opts(config)

      assert opts[:conn_max_idle_time] == 45_000
    end
  end

  describe "to_grpc_opts/1" do
    test "converts to gRPC channel options" do
      config = Connection.new(max_connections: 50, max_idle_time: 30_000)

      opts = Connection.to_grpc_opts(config)

      assert is_list(opts)
      assert opts[:idle_timeout] == 30_000
    end
  end
end
