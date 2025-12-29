defmodule WeaviateEx.API.Cluster do
  @moduledoc """
  Cluster management operations.

  Provides visibility into Weaviate cluster state, node health, and shard
  replication operations.

  ## Node Operations

  - `nodes/2` - Get all nodes with optional verbosity
  - `statistics/1` - Get cluster statistics

  ## Shard Operations

  - `shards/2` - Get shard status for a collection

  ## Replication Operations

  - `replicate/4` - Initiate shard replication
  - `list_replications/2` - List all replication operations
  - `get_replication/3` - Get specific replication status
  - `cancel_replication/2` - Cancel running replication
  - `delete_replication/2` - Delete completed replication record

  ## Examples

      # Get all nodes
      {:ok, nodes} = Cluster.nodes(client)

      # Get nodes with shard info for specific collection
      {:ok, nodes} = Cluster.nodes(client, collection: "Article", output: :verbose)

      # Get sharding state for collection
      {:ok, shards} = Cluster.shards(client, "Article")

      # Replicate a shard to another node
      {:ok, op} = Cluster.replicate(client, "Article", "shard-1",
        source: "node-1",
        target: "node-2",
        type: :copy
      )

      # Check replication status
      {:ok, op} = Cluster.get_replication(client, "uuid-123")
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Cluster.{Node, Replication, Shard}
  alias WeaviateEx.Error

  @type output_verbosity :: :minimal | :verbose
  @type opts :: keyword()

  @doc """
  Get cluster nodes.

  Returns information about all nodes in the cluster including their
  status, version, and optionally shard information.

  ## Options

  - `:collection` - Filter by collection (shows shards for that collection)
  - `:output` - Verbosity level (`:minimal` or `:verbose`)

  ## Examples

      # Get all nodes with minimal info
      {:ok, nodes} = Cluster.nodes(client)

      # Get nodes with verbose info including stats
      {:ok, nodes} = Cluster.nodes(client, output: :verbose)

      # Get nodes with shard info for specific collection
      {:ok, nodes} = Cluster.nodes(client, collection: "Article")

  ## Returns

  - `{:ok, [Node.t()]}` - List of nodes
  - `{:error, Error.t()}` - Error if request fails
  """
  @spec nodes(Client.t(), opts()) :: {:ok, [Node.t()]} | {:error, Error.t()}
  def nodes(client, opts \\ []) do
    collection = Keyword.get(opts, :collection)
    output = Keyword.get(opts, :output, :minimal)

    path = build_nodes_path(collection, output)

    case Client.request(client, :get, path, nil, []) do
      {:ok, %{"nodes" => nodes_data}} ->
        nodes = Enum.map(nodes_data, &Node.from_api/1)
        {:ok, nodes}

      {:ok, nodes_data} when is_list(nodes_data) ->
        nodes = Enum.map(nodes_data, &Node.from_api/1)
        {:ok, nodes}

      {:error, _} = error ->
        error
    end
  end

  defp build_nodes_path(nil, :minimal), do: "/v1/nodes"
  defp build_nodes_path(nil, :verbose), do: "/v1/nodes?output=verbose"
  defp build_nodes_path(collection, :minimal), do: "/v1/nodes?class=#{collection}"

  defp build_nodes_path(collection, :verbose),
    do: "/v1/nodes?class=#{collection}&output=verbose"

  @doc """
  Get shards for a collection.

  Returns shard status including vector queue depth for monitoring
  async vectorization progress.

  ## Examples

      {:ok, shards} = Cluster.shards(client, "Article")

      # Check if all vectors are indexed
      Enum.all?(shards, &Shard.vectors_indexed?/1)

      # Check if all shards are ready
      Enum.all?(shards, &Shard.ready?/1)

  ## Returns

  - `{:ok, [Shard.t()]}` - List of shards
  - `{:error, Error.t()}` - Error if collection not found
  """
  @spec shards(Client.t(), String.t()) :: {:ok, [Shard.t()]} | {:error, Error.t()}
  def shards(client, collection) do
    case Client.request(client, :get, "/v1/schema/#{collection}/shards", nil, []) do
      {:ok, shards_data} when is_list(shards_data) ->
        shards =
          shards_data
          |> Enum.map(&Shard.from_api/1)
          |> Enum.map(fn shard -> %{shard | collection: collection} end)

        {:ok, shards}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get cluster statistics.

  Returns cluster-wide statistics including resource usage and
  performance metrics.

  ## Examples

      {:ok, stats} = Cluster.statistics(client)

  ## Returns

  - `{:ok, map()}` - Cluster statistics
  - `{:error, Error.t()}` - Error if request fails
  """
  @spec statistics(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def statistics(client) do
    Client.request(client, :get, "/v1/cluster/statistics", nil, [])
  end

  @doc """
  Initiate shard replication.

  Copies or moves a shard from one node to another.

  ## Options

  - `:source` - Source node name (required)
  - `:target` - Target node name (required)
  - `:type` - Replication type (`:copy` or `:move`, default: `:copy`)

  ## Examples

      # Copy shard to another node
      {:ok, op} = Cluster.replicate(client, "Article", "shard-0",
        source: "node-1",
        target: "node-2",
        type: :copy
      )

      # Move shard to another node (removes from source)
      {:ok, op} = Cluster.replicate(client, "Article", "shard-0",
        source: "node-1",
        target: "node-2",
        type: :move
      )

  ## Returns

  - `{:ok, Replication.Operation.t()}` - Created operation
  - `{:error, Error.t()}` - Error if replication fails
  """
  @spec replicate(Client.t(), String.t(), String.t(), opts()) ::
          {:ok, Replication.Operation.t()} | {:error, Error.t()}
  def replicate(client, collection, shard, opts) do
    source = Keyword.fetch!(opts, :source)
    target = Keyword.fetch!(opts, :target)
    type = Keyword.get(opts, :type, :copy)

    payload = %{
      "collection" => collection,
      "shard" => shard,
      "sourceNode" => source,
      "targetNode" => target,
      "type" => Replication.type_to_api(type)
    }

    case Client.request(client, :post, "/v1/cluster/replications", payload, []) do
      {:ok, data} ->
        {:ok, Replication.Operation.from_api(data)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  List all replication operations.

  Returns all pending, running, and completed replication operations.

  ## Options

  - `:collection` - Filter by collection
  - `:shard` - Filter by shard
  - `:target_node` - Filter by target node

  ## Examples

      # List all replications
      {:ok, ops} = Cluster.list_replications(client)

      # Filter by collection
      {:ok, ops} = Cluster.list_replications(client, collection: "Article")

      # Filter by target node
      {:ok, ops} = Cluster.list_replications(client, target_node: "node-2")

  ## Returns

  - `{:ok, [Replication.Operation.t()]}` - List of operations
  - `{:error, Error.t()}` - Error if request fails
  """
  @spec list_replications(Client.t(), opts()) ::
          {:ok, [Replication.Operation.t()]} | {:error, Error.t()}
  def list_replications(client, opts \\ []) do
    query_params = build_replication_query_params(opts)
    path = build_path_with_query("/v1/cluster/replications", query_params)

    case Client.request(client, :get, path, nil, []) do
      {:ok, data} when is_list(data) ->
        ops = Enum.map(data, &Replication.Operation.from_api/1)
        {:ok, ops}

      {:ok, %{"replications" => data}} when is_list(data) ->
        ops = Enum.map(data, &Replication.Operation.from_api/1)
        {:ok, ops}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  defp build_replication_query_params(opts) do
    []
    |> maybe_add_param(:collection, Keyword.get(opts, :collection))
    |> maybe_add_param(:shard, Keyword.get(opts, :shard))
    |> maybe_add_param(:targetNode, Keyword.get(opts, :target_node))
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: [{key, value} | params]

  defp build_path_with_query(path, []), do: path

  defp build_path_with_query(path, params) do
    query = URI.encode_query(params)
    "#{path}?#{query}"
  end

  @doc """
  Get a specific replication operation.

  ## Options

  - `:include_history` - Include operation history (default: false)

  ## Examples

      {:ok, op} = Cluster.get_replication(client, "uuid-123")

      # With operation history
      {:ok, op} = Cluster.get_replication(client, "uuid-123", include_history: true)

  ## Returns

  - `{:ok, Replication.Operation.t()}` - Operation details
  - `{:error, Error.t()}` - Error if not found
  """
  @spec get_replication(Client.t(), String.t(), opts()) ::
          {:ok, Replication.Operation.t()} | {:error, Error.t()}
  def get_replication(client, operation_id, opts \\ []) do
    include_history = Keyword.get(opts, :include_history, false)

    path =
      if include_history do
        "/v1/cluster/replications/#{operation_id}?includeHistory=true"
      else
        "/v1/cluster/replications/#{operation_id}"
      end

    case Client.request(client, :get, path, nil, []) do
      {:ok, data} ->
        {:ok, Replication.Operation.from_api(data)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Cancel a replication operation.

  Can only cancel operations that are still in progress (pending or running).

  ## Examples

      :ok = Cluster.cancel_replication(client, "uuid-123")

  ## Returns

  - `:ok` - Operation cancelled
  - `{:error, Error.t()}` - Error if cancellation fails
  """
  @spec cancel_replication(Client.t(), String.t()) :: :ok | {:error, Error.t()}
  def cancel_replication(client, operation_id) do
    case Client.request(
           client,
           :post,
           "/v1/cluster/replications/#{operation_id}/cancel",
           nil,
           []
         ) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Delete a completed replication operation record.

  Can only delete operations that are complete (completed, failed, or cancelled).

  ## Examples

      :ok = Cluster.delete_replication(client, "uuid-123")

  ## Returns

  - `:ok` - Record deleted
  - `{:error, Error.t()}` - Error if deletion fails
  """
  @spec delete_replication(Client.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete_replication(client, operation_id) do
    case Client.request(client, :delete, "/v1/cluster/replications/#{operation_id}", nil, []) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Wait for all replications to complete.

  Polls replication status until all operations are complete.

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 1000)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000)
  - `:collection` - Only wait for replications of this collection

  ## Examples

      :ok = Cluster.wait_for_replications(client)
      :ok = Cluster.wait_for_replications(client, collection: "Article", timeout: 60_000)

  ## Returns

  - `:ok` - All replications complete
  - `{:error, :timeout}` - Timed out waiting
  - `{:error, {:failed, [Replication.Operation.t()]}}` - Some replications failed
  """
  @spec wait_for_replications(Client.t(), opts()) ::
          :ok | {:error, :timeout | {:failed, [Replication.Operation.t()]}}
  def wait_for_replications(client, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 1000)
    timeout = Keyword.get(opts, :timeout, 300_000)
    collection = Keyword.get(opts, :collection)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_replications(client, collection, poll_interval, deadline)
  end

  defp do_wait_for_replications(client, collection, poll_interval, deadline) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      {:error, :timeout}
    else
      filter_opts = if collection, do: [collection: collection], else: []
      check_and_wait(client, collection, poll_interval, deadline, filter_opts)
    end
  end

  defp check_and_wait(client, collection, poll_interval, deadline, filter_opts) do
    case list_replications(client, filter_opts) do
      {:ok, ops} ->
        handle_replication_status(client, collection, poll_interval, deadline, ops)

      {:error, _reason} ->
        Process.sleep(poll_interval)
        do_wait_for_replications(client, collection, poll_interval, deadline)
    end
  end

  defp handle_replication_status(client, collection, poll_interval, deadline, ops) do
    {in_progress, completed} = Enum.split_with(ops, &Replication.Operation.in_progress?/1)
    failed = Enum.filter(completed, fn op -> op.status == :failed end)

    cond do
      Enum.any?(failed) ->
        {:error, {:failed, failed}}

      Enum.empty?(in_progress) ->
        :ok

      true ->
        Process.sleep(poll_interval)
        do_wait_for_replications(client, collection, poll_interval, deadline)
    end
  end
end
