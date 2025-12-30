defmodule WeaviateEx.Protocol.HTTP.Timeout do
  @moduledoc """
  Per-operation timeout calculation based on operation type.

  This module extends `WeaviateEx.Config.Timeout` with operation-specific
  timeout logic, including extended timeouts for batch operations.

  ## Operation Types

  - `:query`, `:search`, `:aggregate`, `:get` - Use query timeout (default: 30s)
  - `:insert`, `:update`, `:delete`, `:create` - Use insert timeout (default: 90s)
  - `:batch` - Uses insert timeout × 10 for large batch operations
  - `:init` - Uses init timeout for connection initialization (default: 2s)

  ## Usage

      alias WeaviateEx.Config.Timeout
      alias WeaviateEx.Protocol.HTTP.Timeout, as: HTTPTimeout

      config = Timeout.new(query: 30_000, insert: 90_000)

      HTTPTimeout.for_operation(config, :query)   # => 30_000
      HTTPTimeout.for_operation(config, :batch)   # => 900_000 (10x insert)
  """

  alias WeaviateEx.Config.Timeout

  @batch_multiplier 10

  @type operation ::
          :query
          | :search
          | :aggregate
          | :get
          | :insert
          | :update
          | :delete
          | :create
          | :batch
          | :init
          | atom()

  @doc """
  Get the timeout for a specific operation type.

  Batch operations automatically get an extended timeout (insert × 10).

  ## Examples

      config = Timeout.new()

      HTTPTimeout.for_operation(config, :query)
      # => 30_000

      HTTPTimeout.for_operation(config, :insert)
      # => 90_000

      HTTPTimeout.for_operation(config, :batch)
      # => 900_000 (insert × 10)
  """
  @spec for_operation(Timeout.t() | nil, operation()) :: pos_integer()
  def for_operation(nil, operation) do
    for_operation(Timeout.new(), operation)
  end

  def for_operation(%Timeout{} = config, :batch) do
    config.insert * @batch_multiplier
  end

  def for_operation(%Timeout{} = config, operation) do
    case operation_category(operation) do
      :query -> config.query
      :insert -> config.insert
      :init -> config.init
      :batch -> config.insert * @batch_multiplier
    end
  end

  @doc """
  Returns the multiplier applied to batch operation timeouts.

  Batch operations use `insert_timeout × batch_multiplier` to allow
  time for processing large numbers of objects.

  ## Examples

      HTTPTimeout.batch_multiplier()
      # => 10
  """
  @spec batch_multiplier() :: pos_integer()
  def batch_multiplier, do: @batch_multiplier

  @doc """
  Categorize an operation into its timeout category.

  Returns one of: `:query`, `:insert`, `:batch`, or `:init`.

  ## Examples

      HTTPTimeout.operation_category(:search)
      # => :query

      HTTPTimeout.operation_category(:update)
      # => :insert

      HTTPTimeout.operation_category(:batch)
      # => :batch
  """
  @spec operation_category(operation()) :: :query | :insert | :batch | :init
  def operation_category(:query), do: :query
  def operation_category(:search), do: :query
  def operation_category(:aggregate), do: :query
  def operation_category(:get), do: :query
  def operation_category(:insert), do: :insert
  def operation_category(:update), do: :insert
  def operation_category(:delete), do: :insert
  def operation_category(:create), do: :insert
  def operation_category(:batch), do: :batch
  def operation_category(:init), do: :init
  def operation_category(_unknown), do: :query
end
