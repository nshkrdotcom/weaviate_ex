defmodule WeaviateEx.Reconfigure do
  @moduledoc """
  Type-safe configuration update builders for collections.

  This module provides builder functions for creating configuration updates
  that can be passed to `Collections.update/3`. Each function returns a map
  with the proper API structure.

  ## Example

      alias WeaviateEx.Reconfigure

      # Update inverted index settings
      updates = Reconfigure.inverted_index(bm25: [b: 0.8, k1: 1.5])

      {:ok, _} = WeaviateEx.Collections.update(client, "Article", updates)

      # Update replication factor
      updates = Reconfigure.replication(factor: 5)

      # Combine multiple updates
      updates =
        Reconfigure.inverted_index(bm25: [b: 0.8])
        |> Map.merge(Reconfigure.replication(factor: 3))

      {:ok, _} = WeaviateEx.Collections.update(client, "Article", updates)
  """

  @doc """
  Build an inverted index configuration update.

  ## Options

  - `:bm25` - BM25 parameters: `[b: float, k1: float]`
  - `:cleanup_interval_seconds` - Seconds between cleanup runs
  - `:stopwords` - Stopword configuration: `[preset: string, additions: [string], removals: [string]]`
  - `:index_null_state` - Whether to index null values (boolean)
  - `:index_property_length` - Whether to index property length (boolean)
  - `:index_timestamps` - Whether to index timestamps (boolean)

  ## Examples

      # Update BM25 parameters
      Reconfigure.inverted_index(bm25: [b: 0.8, k1: 1.5])

      # Update cleanup interval
      Reconfigure.inverted_index(cleanup_interval_seconds: 120)

      # Multiple settings
      Reconfigure.inverted_index(
        bm25: [b: 0.75],
        cleanup_interval_seconds: 60,
        index_null_state: true
      )
  """
  @spec inverted_index(keyword()) :: map()
  def inverted_index(opts \\ []) do
    config =
      opts
      |> Enum.reduce(%{}, &apply_inverted_index_opt/2)

    %{"invertedIndexConfig" => config}
  end

  defp apply_inverted_index_opt({:bm25, bm25_opts}, config) do
    Map.put(config, "bm25", build_bm25(bm25_opts))
  end

  defp apply_inverted_index_opt({:cleanup_interval_seconds, val}, config) do
    Map.put(config, "cleanupIntervalSeconds", val)
  end

  defp apply_inverted_index_opt({:stopwords, sw_opts}, config) do
    Map.put(config, "stopwords", build_stopwords(sw_opts))
  end

  defp apply_inverted_index_opt({:index_null_state, val}, config) do
    Map.put(config, "indexNullState", val)
  end

  defp apply_inverted_index_opt({:index_property_length, val}, config) do
    Map.put(config, "indexPropertyLength", val)
  end

  defp apply_inverted_index_opt({:index_timestamps, val}, config) do
    Map.put(config, "indexTimestamps", val)
  end

  defp apply_inverted_index_opt(_other, config), do: config

  @doc """
  Build a replication configuration update.

  ## Options

  - `:factor` - Replication factor (number of replicas)
  - `:async_enabled` - Whether async replication is enabled (boolean)
  - `:deletion_strategy` - Deletion strategy (`:no_automated_resolution` or `:delete_on_conflict`)

  ## Examples

      # Update replication factor
      Reconfigure.replication(factor: 3)

      # Enable async replication
      Reconfigure.replication(async_enabled: true)

      # Set deletion strategy
      Reconfigure.replication(deletion_strategy: :delete_on_conflict)
  """
  @spec replication(keyword()) :: map()
  def replication(opts \\ []) do
    config = %{}

    config =
      case Keyword.get(opts, :factor) do
        nil -> config
        val -> Map.put(config, "factor", val)
      end

    config =
      case Keyword.get(opts, :async_enabled) do
        nil -> config
        val -> Map.put(config, "asyncEnabled", val)
      end

    config =
      case Keyword.get(opts, :deletion_strategy) do
        nil ->
          config

        :no_automated_resolution ->
          Map.put(config, "deletionStrategy", "NoAutomatedResolution")

        :delete_on_conflict ->
          Map.put(config, "deletionStrategy", "DeleteOnConflict")

        val when is_binary(val) ->
          Map.put(config, "deletionStrategy", val)
      end

    %{"replicationConfig" => config}
  end

  @doc """
  Build an HNSW vector index configuration update.

  ## Options

  - `:ef` - Size of dynamic candidate list for search
  - `:ef_construction` - Size of candidate list during construction
  - `:max_connections` - Maximum connections per element
  - `:cleanup_interval_seconds` - Seconds between cleanup runs
  - `:dynamic_ef_factor` - Factor for dynamic ef
  - `:dynamic_ef_min` - Minimum dynamic ef
  - `:dynamic_ef_max` - Maximum dynamic ef
  - `:flat_search_cutoff` - Object count threshold for flat search
  - `:vector_cache_max_objects` - Max objects in vector cache
  - `:skip` - Skip vector index (boolean)
  - `:filter_strategy` - Filter strategy (`:sweeping` or `:acorn`)

  ## Examples

      # Update ef parameters
      Reconfigure.vector_index_hnsw(ef: 128, ef_construction: 256)

      # Update cache settings
      Reconfigure.vector_index_hnsw(vector_cache_max_objects: 100_000)
  """
  @spec vector_index_hnsw(keyword()) :: map()
  def vector_index_hnsw(opts \\ []) do
    config = %{}

    config =
      opts
      |> Enum.reduce(config, fn
        {:ef, val}, acc -> Map.put(acc, "ef", val)
        {:ef_construction, val}, acc -> Map.put(acc, "efConstruction", val)
        {:max_connections, val}, acc -> Map.put(acc, "maxConnections", val)
        {:cleanup_interval_seconds, val}, acc -> Map.put(acc, "cleanupIntervalSeconds", val)
        {:dynamic_ef_factor, val}, acc -> Map.put(acc, "dynamicEfFactor", val)
        {:dynamic_ef_min, val}, acc -> Map.put(acc, "dynamicEfMin", val)
        {:dynamic_ef_max, val}, acc -> Map.put(acc, "dynamicEfMax", val)
        {:flat_search_cutoff, val}, acc -> Map.put(acc, "flatSearchCutoff", val)
        {:vector_cache_max_objects, val}, acc -> Map.put(acc, "vectorCacheMaxObjects", val)
        {:skip, val}, acc -> Map.put(acc, "skip", val)
        {:filter_strategy, :sweeping}, acc -> Map.put(acc, "filterStrategy", "sweeping")
        {:filter_strategy, :acorn}, acc -> Map.put(acc, "filterStrategy", "acorn")
        {:filter_strategy, val}, acc when is_binary(val) -> Map.put(acc, "filterStrategy", val)
        _, acc -> acc
      end)

    %{"vectorIndexConfig" => config}
  end

  @doc """
  Build a named vector configuration update.

  Updates the configuration for a specific named vector.

  ## Parameters

  - `name` - Name of the vector to update
  - `opts` - Vector configuration options (same as vector_index_hnsw)

  ## Examples

      # Update a named vector's ef parameter
      Reconfigure.named_vectors_update("title_vector", ef: 128)

      # Update multiple named vectors
      updates =
        Reconfigure.named_vectors_update("title", ef: 128)
        |> Map.merge(Reconfigure.named_vectors_update("content", ef: 256))
  """
  @spec named_vectors_update(String.t(), keyword()) :: map()
  def named_vectors_update(name, opts \\ []) do
    hnsw_config = vector_index_hnsw(opts)["vectorIndexConfig"]

    %{
      "vectorConfig" => %{
        name => %{
          "vectorIndexConfig" => hnsw_config
        }
      }
    }
  end

  @doc """
  Build a multi-tenancy configuration update.

  ## Options

  - `:auto_tenant_creation` - Auto-create tenants on first insert (boolean)
  - `:auto_tenant_activation` - Auto-activate tenants on access (boolean)

  ## Examples

      # Enable auto-tenant creation
      Reconfigure.multi_tenancy(auto_tenant_creation: true)

      # Enable fully automatic mode
      Reconfigure.multi_tenancy(
        auto_tenant_creation: true,
        auto_tenant_activation: true
      )
  """
  @spec multi_tenancy(keyword()) :: map()
  def multi_tenancy(opts \\ []) do
    config = %{}

    config =
      case Keyword.get(opts, :auto_tenant_creation) do
        nil -> config
        val -> Map.put(config, "autoTenantCreation", val)
      end

    config =
      case Keyword.get(opts, :auto_tenant_activation) do
        nil -> config
        val -> Map.put(config, "autoTenantActivation", val)
      end

    %{"multiTenancyConfig" => config}
  end

  @doc """
  Build a description update.

  ## Examples

      Reconfigure.description("Updated collection description")
  """
  @spec description(String.t()) :: map()
  def description(desc) when is_binary(desc) do
    %{"description" => desc}
  end

  @doc """
  Merge multiple reconfiguration updates into a single map.

  ## Examples

      updates = Reconfigure.merge([
        Reconfigure.inverted_index(bm25: [b: 0.8]),
        Reconfigure.replication(factor: 3),
        Reconfigure.vector_index_hnsw(ef: 128)
      ])

      {:ok, _} = WeaviateEx.Collections.update(client, "Article", updates)
  """
  @spec merge([map()]) :: map()
  def merge(configs) when is_list(configs) do
    Enum.reduce(configs, %{}, &Map.merge(&2, &1))
  end

  # Private helpers

  defp build_bm25(opts) do
    %{}
    |> maybe_put("b", Keyword.get(opts, :b))
    |> maybe_put("k1", Keyword.get(opts, :k1))
  end

  defp build_stopwords(opts) do
    %{}
    |> maybe_put("preset", Keyword.get(opts, :preset))
    |> maybe_put("additions", Keyword.get(opts, :additions))
    |> maybe_put("removals", Keyword.get(opts, :removals))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
