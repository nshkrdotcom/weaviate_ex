defmodule WeaviateEx.Config.Timeout do
  @moduledoc """
  Timeout configuration for Weaviate client operations.

  Provides different timeout values for different operation types:

  - `:init` - Connection initialization (default: 2s)
  - `:query` - Search and read operations (default: 30s)
  - `:insert` - Write and batch operations (default: 90s)

  ## Examples

      # Use default timeouts
      timeout = Timeout.new()

      # Custom timeouts
      timeout = Timeout.new(
        init: 5_000,
        query: 60_000,
        insert: 120_000
      )

      # Get timeout for specific method
      Timeout.for_method(timeout, :get)
      # => 30_000
  """

  @type t :: %__MODULE__{
          init: pos_integer(),
          query: pos_integer(),
          insert: pos_integer()
        }

  @default_init 2_000
  @default_query 30_000
  @default_insert 90_000

  defstruct init: @default_init,
            query: @default_query,
            insert: @default_insert

  @doc """
  Create a new timeout configuration.

  ## Options

    - `:init` - Connection initialization timeout in milliseconds (default: 2000)
    - `:query` - Query/search timeout in milliseconds (default: 30000)
    - `:insert` - Insert/batch timeout in milliseconds (default: 90000)

  ## Examples

      iex> Timeout.new()
      %Timeout{init: 2000, query: 30000, insert: 90000}

      iex> Timeout.new(query: 60_000)
      %Timeout{init: 2000, query: 60000, insert: 90000}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      init: Keyword.get(opts, :init, @default_init),
      query: Keyword.get(opts, :query, @default_query),
      insert: Keyword.get(opts, :insert, @default_insert)
    }
  end

  @doc """
  Get timeout for HTTP method.

  - `:init` - Returns init timeout
  - `:get` - Returns query timeout
  - `:post`, `:put`, `:patch`, `:delete` - Returns insert timeout

  ## Examples

      iex> timeout = Timeout.new()
      iex> Timeout.for_method(timeout, :get)
      30000

      iex> Timeout.for_method(timeout, :post)
      90000
  """
  @spec for_method(t(), atom()) :: pos_integer()
  def for_method(%__MODULE__{init: init}, :init), do: init
  def for_method(%__MODULE__{query: query}, :get), do: query
  def for_method(%__MODULE__{insert: insert}, :post), do: insert
  def for_method(%__MODULE__{insert: insert}, :put), do: insert
  def for_method(%__MODULE__{insert: insert}, :patch), do: insert
  def for_method(%__MODULE__{insert: insert}, :delete), do: insert
  def for_method(%__MODULE__{query: query}, _method), do: query

  @doc """
  Get timeout for operation type.

  - `:search`, `:query`, `:aggregate` - Returns query timeout
  - `:insert`, `:update`, `:batch` - Returns insert timeout

  ## Examples

      iex> timeout = Timeout.new()
      iex> Timeout.for_operation(timeout, :search)
      30000

      iex> Timeout.for_operation(timeout, :batch)
      90000
  """
  @spec for_operation(t(), atom()) :: pos_integer()
  def for_operation(%__MODULE__{query: query}, op) when op in [:search, :query, :aggregate],
    do: query

  def for_operation(%__MODULE__{insert: insert}, op)
      when op in [:insert, :update, :batch, :delete],
      do: insert

  def for_operation(%__MODULE__{query: query}, _op), do: query
end
