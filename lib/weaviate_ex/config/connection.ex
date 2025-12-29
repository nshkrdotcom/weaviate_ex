defmodule WeaviateEx.Config.Connection do
  @moduledoc """
  Connection pool configuration for HTTP and gRPC connections.

  Fine-tune connection settings for high-load production scenarios.

  ## Examples

      # Create client with custom connection pool
      {:ok, client} = Client.connect(
        base_url: "http://localhost:8080",
        connection: Connection.new(
          pool_size: 20,
          max_connections: 200,
          pool_timeout: 10_000
        )
      )

      # Or pass options directly
      {:ok, client} = Client.connect(
        base_url: "http://localhost:8080",
        connection: [
          pool_size: 20,
          max_connections: 200
        ]
      )
  """

  @type t :: %__MODULE__{
          pool_size: pos_integer(),
          max_connections: pos_integer(),
          pool_timeout: pos_integer(),
          max_idle_time: pos_integer()
        }

  @default_pool_size 10
  @default_max_connections 100
  @default_pool_timeout 5_000
  @default_max_idle_time 60_000

  defstruct pool_size: @default_pool_size,
            max_connections: @default_max_connections,
            pool_timeout: @default_pool_timeout,
            max_idle_time: @default_max_idle_time

  @doc """
  Create a new connection configuration.

  ## Options

    * `:pool_size` - Number of connections to keep in pool (default: 10)
    * `:max_connections` - Maximum total connections (default: 100)
    * `:pool_timeout` - Timeout for acquiring connection from pool in ms (default: 5000)
    * `:max_idle_time` - Max idle time before closing connection in ms (default: 60000)

  ## Examples

      Connection.new(pool_size: 20, max_connections: 200)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)
    max_connections = Keyword.get(opts, :max_connections, @default_max_connections)
    pool_timeout = Keyword.get(opts, :pool_timeout, @default_pool_timeout)
    max_idle_time = Keyword.get(opts, :max_idle_time, @default_max_idle_time)

    if pool_size <= 0 do
      raise ArgumentError, "pool_size must be positive, got: #{pool_size}"
    end

    if max_connections <= 0 do
      raise ArgumentError, "max_connections must be positive, got: #{max_connections}"
    end

    %__MODULE__{
      pool_size: pool_size,
      max_connections: max_connections,
      pool_timeout: pool_timeout,
      max_idle_time: max_idle_time
    }
  end

  @doc """
  Convert to Finch pool options.

  ## Examples

      config = Connection.new(pool_size: 15)
      opts = Connection.to_finch_opts(config)
      # => [size: 15, count: 6, pool_timeout: 5000]
  """
  @spec to_finch_opts(t()) :: keyword()
  def to_finch_opts(%__MODULE__{} = config) do
    [
      size: config.pool_size,
      count: div(config.max_connections, config.pool_size),
      pool_timeout: config.pool_timeout
    ]
  end

  @doc """
  Convert to gRPC channel options.

  ## Examples

      config = Connection.new(max_connections: 50)
      opts = Connection.to_grpc_opts(config)
  """
  @spec to_grpc_opts(t()) :: keyword()
  def to_grpc_opts(%__MODULE__{} = config) do
    [
      pool_size: config.pool_size,
      idle_timeout: config.max_idle_time
    ]
  end
end
