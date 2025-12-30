defmodule WeaviateEx.Batch.VectorIndexing do
  @moduledoc """
  Wait for vector indexing completion after batch operations.

  When objects are inserted via batch operations, their vectors are indexed
  asynchronously. This module provides functions to wait for indexing completion,
  ensuring all vectors are queryable before continuing.

  ## Features

  - Poll shard status until vectors are indexed
  - Configurable timeout and poll interval
  - Support for specific shards or all collection shards
  - Failure tolerance with configurable retry limits

  ## Example

      alias WeaviateEx.Batch.VectorIndexing

      # After batch insert, wait for indexing
      {:ok, _} = WeaviateEx.Batch.create_objects(client, objects)
      :ok = VectorIndexing.wait_for_indexing(client, "Article")

      # Wait for specific tenant shard
      :ok = VectorIndexing.wait_for_indexing(client, "Article",
        tenant: "tenant-a",
        timeout: 120_000,
        poll_interval: 500
      )

      # Check if a specific shard is ready
      {:ok, true} = VectorIndexing.shard_ready?(client, "Article", "shard-0")
  """

  alias WeaviateEx.API.Cluster
  alias WeaviateEx.Client
  alias WeaviateEx.Cluster.Shard
  alias WeaviateEx.Error

  @type shard_spec :: %{
          collection: String.t(),
          tenant: String.t() | nil
        }

  @type opts :: keyword()

  @default_poll_interval 250
  @default_timeout 60_000
  @default_max_failures 5

  @doc """
  Wait for all vectors to be indexed.

  Polls shard status until all shards have an empty vector queue,
  indicating all vectors have been indexed and are queryable.

  ## Options

  - `:timeout` - Maximum wait time in milliseconds (default: 60_000)
  - `:poll_interval` - Milliseconds between status checks (default: 250)
  - `:how_many_failures` - Number of consecutive failures before giving up (default: 5)
  - `:tenant` - Filter to specific tenant (optional)

  ## Examples

      # Wait for all shards in a collection
      :ok = VectorIndexing.wait_for_indexing(client, "Article")

      # Wait with custom timeout
      :ok = VectorIndexing.wait_for_indexing(client, "Article", timeout: 120_000)

      # Wait for specific tenant
      :ok = VectorIndexing.wait_for_indexing(client, "Article", tenant: "tenant-a")

  ## Returns

  - `:ok` - All vectors indexed
  - `{:error, :timeout}` - Timed out waiting for indexing
  - `{:error, {:max_failures_exceeded, last_error}}` - Too many consecutive failures
  """
  @spec wait_for_indexing(Client.t(), String.t(), opts()) :: :ok | {:error, term()}
  def wait_for_indexing(client, collection, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    max_failures = Keyword.get(opts, :how_many_failures, @default_max_failures)
    tenant = Keyword.get(opts, :tenant)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_indexing(
      client,
      collection,
      tenant,
      poll_interval,
      max_failures,
      deadline,
      0,
      nil
    )
  end

  @doc """
  Wait for specific shards to have vectors indexed.

  Similar to `wait_for_indexing/3` but accepts a list of shard specifications.

  ## Examples

      shards = [
        %{collection: "Article", tenant: nil},
        %{collection: "Product", tenant: "tenant-a"}
      ]
      :ok = VectorIndexing.wait_for_shards(client, shards)

  ## Returns

  - `:ok` - All specified shards have vectors indexed
  - `{:error, :timeout}` - Timed out waiting
  - `{:error, term()}` - Other error
  """
  @spec wait_for_shards(Client.t(), [shard_spec()], opts()) :: :ok | {:error, term()}
  def wait_for_shards(client, shards, opts \\ []) when is_list(shards) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    max_failures = Keyword.get(opts, :how_many_failures, @default_max_failures)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_shards(client, shards, poll_interval, max_failures, deadline, 0, nil)
  end

  @doc """
  Check if a shard is ready for queries.

  A shard is ready when its vector queue is empty, meaning all vectors
  have been indexed.

  ## Examples

      {:ok, true} = VectorIndexing.shard_ready?(client, "Article", "shard-0")
      {:ok, false} = VectorIndexing.shard_ready?(client, "Article", "shard-0")

  ## Returns

  - `{:ok, boolean()}` - Whether shard is ready
  - `{:error, Error.t()}` - Error fetching shard status
  """
  @spec shard_ready?(Client.t(), String.t(), String.t()) ::
          {:ok, boolean()} | {:error, Error.t()}
  def shard_ready?(client, collection, shard_name) do
    case Cluster.shards(client, collection) do
      {:ok, shards} ->
        shard = Enum.find(shards, &(&1.name == shard_name))

        if shard do
          {:ok, Shard.vectors_indexed?(shard)}
        else
          {:error, Error.exception(type: :not_found, message: "Shard not found: #{shard_name}")}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get the vector queue status for all shards in a collection.

  Returns a list of shards with their current vector queue sizes.

  ## Examples

      {:ok, statuses} = VectorIndexing.get_queue_status(client, "Article")
      for status <- statuses do
        IO.puts("\#{status.name}: \#{status.vector_queue_size} vectors pending")
      end

  ## Returns

  - `{:ok, [Shard.t()]}` - List of shards with queue status
  - `{:error, Error.t()}` - Error fetching status
  """
  @spec get_queue_status(Client.t(), String.t()) :: {:ok, [Shard.t()]} | {:error, Error.t()}
  def get_queue_status(client, collection) do
    Cluster.shards(client, collection)
  end

  @doc """
  Get the total pending vector count across all shards.

  ## Examples

      {:ok, 1500} = VectorIndexing.total_pending_vectors(client, "Article")

  ## Returns

  - `{:ok, non_neg_integer()}` - Total pending vectors
  - `{:error, Error.t()}` - Error fetching status
  """
  @spec total_pending_vectors(Client.t(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, Error.t()}
  def total_pending_vectors(client, collection) do
    case Cluster.shards(client, collection) do
      {:ok, shards} ->
        total =
          shards
          |> Enum.map(& &1.vector_queue_size)
          |> Enum.sum()

        {:ok, total}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Check if all vectors are indexed for a collection.

  ## Examples

      {:ok, true} = VectorIndexing.all_indexed?(client, "Article")

  ## Returns

  - `{:ok, boolean()}` - Whether all vectors are indexed
  - `{:error, Error.t()}` - Error fetching status
  """
  @spec all_indexed?(Client.t(), String.t()) :: {:ok, boolean()} | {:error, Error.t()}
  def all_indexed?(client, collection) do
    case total_pending_vectors(client, collection) do
      {:ok, 0} -> {:ok, true}
      {:ok, _} -> {:ok, false}
      {:error, _} = error -> error
    end
  end

  # Private helpers

  defp do_wait_for_indexing(
         client,
         collection,
         tenant,
         poll_interval,
         max_failures,
         deadline,
         failure_count,
         last_error
       ) do
    now = System.monotonic_time(:millisecond)

    cond do
      now >= deadline ->
        {:error, :timeout}

      failure_count >= max_failures ->
        {:error, {:max_failures_exceeded, last_error}}

      true ->
        case check_collection_shards(client, collection, tenant) do
          {:ok, true} ->
            :ok

          {:ok, false} ->
            Process.sleep(poll_interval)

            do_wait_for_indexing(
              client,
              collection,
              tenant,
              poll_interval,
              max_failures,
              deadline,
              0,
              nil
            )

          {:error, error} ->
            Process.sleep(poll_interval)

            do_wait_for_indexing(
              client,
              collection,
              tenant,
              poll_interval,
              max_failures,
              deadline,
              failure_count + 1,
              error
            )
        end
    end
  end

  defp check_collection_shards(client, collection, tenant) do
    case Cluster.shards(client, collection) do
      {:ok, shards} ->
        filtered_shards = filter_shards_by_tenant(shards, tenant)
        all_ready = Enum.all?(filtered_shards, &Shard.vectors_indexed?/1)
        {:ok, all_ready}

      {:error, _} = error ->
        error
    end
  end

  defp filter_shards_by_tenant(shards, nil), do: shards

  defp filter_shards_by_tenant(shards, tenant) do
    Enum.filter(shards, fn shard -> String.contains?(shard.name, tenant) end)
  end

  defp do_wait_for_shards(
         client,
         shards,
         poll_interval,
         max_failures,
         deadline,
         failure_count,
         last_error
       ) do
    now = System.monotonic_time(:millisecond)

    cond do
      now >= deadline ->
        {:error, :timeout}

      failure_count >= max_failures ->
        {:error, {:max_failures_exceeded, last_error}}

      true ->
        case check_all_shards_ready(client, shards) do
          {:ok, true} ->
            :ok

          {:ok, false} ->
            Process.sleep(poll_interval)

            do_wait_for_shards(
              client,
              shards,
              poll_interval,
              max_failures,
              deadline,
              0,
              nil
            )

          {:error, error} ->
            Process.sleep(poll_interval)

            do_wait_for_shards(
              client,
              shards,
              poll_interval,
              max_failures,
              deadline,
              failure_count + 1,
              error
            )
        end
    end
  end

  defp check_all_shards_ready(client, shard_specs) do
    results =
      Enum.reduce_while(shard_specs, {:ok, true}, fn spec, _acc ->
        case check_collection_shards(client, spec.collection, spec[:tenant]) do
          {:ok, true} -> {:cont, {:ok, true}}
          {:ok, false} -> {:halt, {:ok, false}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    results
  end
end
