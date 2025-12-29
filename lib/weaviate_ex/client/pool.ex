defmodule WeaviateEx.Client.Pool do
  @moduledoc """
  Connection pool configuration for HTTP and gRPC connections.

  Provides configuration structs for managing connection pools to optimize
  performance and resource usage.

  ## Example

      # Create custom pool config
      http_pool = Pool.new(size: 20, overflow: 10, timeout: 10_000)

      # Use with client creation
      {:ok, client} = Client.new(
        base_url: "http://localhost:8080",
        http_pool: http_pool
      )

      # Or use presets
      {:ok, client} = Client.new(
        base_url: "http://localhost:8080",
        http_pool: Pool.default_http(),
        grpc_pool: Pool.default_grpc()
      )
  """

  @type strategy :: :fifo | :lifo

  @type t :: %__MODULE__{
          size: pos_integer(),
          overflow: non_neg_integer(),
          strategy: strategy(),
          timeout: pos_integer(),
          idle_timeout: pos_integer(),
          max_age: pos_integer() | nil
        }

  defstruct size: 10,
            overflow: 5,
            strategy: :lifo,
            timeout: 5000,
            idle_timeout: 60_000,
            max_age: nil

  @doc """
  Create a new pool configuration.

  ## Options

    * `:size` - Number of connections in the pool (default: 10)
    * `:overflow` - Maximum overflow connections (default: 5)
    * `:strategy` - Connection selection strategy, `:fifo` or `:lifo` (default: `:lifo`)
    * `:timeout` - Checkout timeout in milliseconds (default: 5000)
    * `:idle_timeout` - Idle connection timeout in milliseconds (default: 60000)
    * `:max_age` - Maximum connection age before recycling (default: nil, no limit)

  ## Example

      Pool.new(size: 20, overflow: 10, timeout: 10_000)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      size: Keyword.get(opts, :size, 10),
      overflow: Keyword.get(opts, :overflow, 5),
      strategy: Keyword.get(opts, :strategy, :lifo),
      timeout: Keyword.get(opts, :timeout, 5000),
      idle_timeout: Keyword.get(opts, :idle_timeout, 60_000),
      max_age: Keyword.get(opts, :max_age)
    }
  end

  @doc """
  Returns default pool configuration.

  ## Example

      pool = Pool.default()
  """
  @spec default() :: t()
  def default, do: new()

  @doc """
  Returns default pool configuration optimized for HTTP/Finch connections.

  HTTP pools typically benefit from more connections for parallel requests.

  ## Example

      pool = Pool.default_http()
  """
  @spec default_http() :: t()
  def default_http do
    new(
      size: 10,
      overflow: 5,
      strategy: :lifo,
      timeout: 5000,
      idle_timeout: 60_000
    )
  end

  @doc """
  Returns default pool configuration optimized for gRPC connections.

  gRPC connections are multiplexed, so fewer connections are typically needed.

  ## Example

      pool = Pool.default_grpc()
  """
  @spec default_grpc() :: t()
  def default_grpc do
    new(
      size: 5,
      overflow: 2,
      strategy: :lifo,
      timeout: 10_000,
      idle_timeout: 120_000
    )
  end

  @doc """
  Convert pool configuration to Finch pool options.

  ## Example

      opts = Pool.to_finch_opts(pool)
      # Returns: [size: 10, count: 1]
  """
  @spec to_finch_opts(t()) :: keyword()
  def to_finch_opts(%__MODULE__{} = pool) do
    [
      size: pool.size,
      count: 1
    ]
  end

  @doc """
  Convert pool configuration to gRPC channel options.

  ## Example

      opts = Pool.to_grpc_opts(pool)
  """
  @spec to_grpc_opts(t()) :: keyword()
  def to_grpc_opts(%__MODULE__{} = pool) do
    [
      pool_size: pool.size,
      timeout: pool.timeout
    ]
  end
end
