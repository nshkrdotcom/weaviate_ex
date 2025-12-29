defmodule WeaviateEx.Batch do
  @moduledoc """
  Functions for batch operations in Weaviate.

  Batch operations are much more efficient than individual operations
  when dealing with large numbers of objects.

  ## Batch Modes

  This module supports three batching modes:

  - **Fixed size** (default): Simple fixed-size batching
  - **Dynamic**: Auto-adjusting batch sizes based on server queue depth
  - **Rate-limited**: Respects vectorizer API rate limits

  ## Context Manager Pattern

  Use `with_batch/3` for a context-manager style interface that automatically
  flushes on exit:

      {:ok, results} = WeaviateEx.Batch.with_batch(client, [batch_size: 100], fn batch ->
        batch
        |> WeaviateEx.Batch.add_object("Article", %{title: "Article 1"})
        |> WeaviateEx.Batch.add_object("Article", %{title: "Article 2"})
      end)

  ## Direct API Examples

      # Batch create objects
      objects = [
        %{class: "Article", properties: %{title: "Article 1"}},
        %{class: "Article", properties: %{title: "Article 2"}},
        %{class: "Article", properties: %{title: "Article 3"}}
      ]

      {:ok, result} = WeaviateEx.Batch.create_objects(objects)

      # Batch delete matching criteria
      {:ok, result} = WeaviateEx.Batch.delete_objects(%{
        class: "Article",
        where: %{
          path: ["title"],
          operator: "Equal",
          valueText: "Delete Me"
        }
      })

      # Batch add references
      references = [
        %{
          from: "weaviate://localhost/Article/uuid1/hasAuthor",
          to: "weaviate://localhost/Author/uuid2"
        }
      ]

      {:ok, result} = WeaviateEx.Batch.add_references(references)

      # Request a summary separating successes and failures
      {:ok, summary} = WeaviateEx.Batch.create_objects(objects, return_summary: true)
      summary.statistics
  """

  import WeaviateEx, only: [request: 4]
  alias WeaviateEx.API.Batch, as: BatchAPI
  alias WeaviateEx.API.Cluster
  alias WeaviateEx.Batch.{Background, Dynamic, FixedSize, RateLimited}
  alias WeaviateEx.Batch.ErrorTracking.Results
  alias WeaviateEx.Cluster.Shard

  @type batch_objects :: list(map())
  @type batch_references :: list(map())
  @type delete_criteria :: map()
  @type batch_mode :: :fixed | :dynamic | :rate_limited
  @type batch_context :: %{
          mode: batch_mode(),
          client: WeaviateEx.Client.t(),
          batcher: FixedSize.t() | pid(),
          opts: keyword(),
          results: Results.t()
        }

  @doc """
  Creates multiple objects in a single batch request.

  Much more efficient than creating objects one by one.

  ## Parameters

  - `objects` - List of objects to create
  - `opts` - Additional options

  ## Options

  - `:consistency_level` - Consistency level for the operation

  ## Object Format

  Each object should have:
  - `:class` - Collection name
  - `:id` - Optional UUID
  - `:properties` - Object properties
  - `:vector` - Optional vector embedding

  ## Examples

      objects = [
        %{class: "Article", properties: %{title: "Article 1"}},
        %{class: "Article", properties: %{title: "Article 2"}}
      ]

      {:ok, result} = Batch.create_objects(objects)
      # result["results"] contains status for each object
  """
  @spec create_objects(batch_objects(), Keyword.t()) :: WeaviateEx.api_response()
  def create_objects(objects, opts \\ []) when is_list(objects) do
    summary? = Keyword.get(opts, :return_summary, false)
    request_opts = Keyword.drop(opts, [:return_summary])

    with_client(fn client ->
      case BatchAPI.create_objects(client, objects, Keyword.put(request_opts, :summary, summary?)) do
        {:ok, %BatchAPI.Result{} = result} -> {:ok, result}
        other -> other
      end
    end)
  end

  @doc """
  Deletes multiple objects matching the given criteria.

  ## Parameters

  - `criteria` - Delete criteria including class and where clause
  - `opts` - Additional options

  ## Criteria Format

  - `:class` - Collection name (required)
  - `:where` - Where clause to match objects (required)
  - `:output` - Output verbosity ("minimal" or "verbose", default: "minimal")
  - `:dryRun` - If true, only reports what would be deleted without deleting

  ## Examples

      # Delete all articles with specific title
      {:ok, result} = Batch.delete_objects(%{
        class: "Article",
        where: %{
          path: ["title"],
          operator: "Equal",
          valueText: "Delete Me"
        }
      })

      # Dry run to see what would be deleted
      {:ok, result} = Batch.delete_objects(%{
        class: "Article",
        where: %{path: ["status"], operator: "Equal", valueText: "draft"},
        dryRun: true
      })
  """
  @spec delete_objects(delete_criteria(), Keyword.t()) :: WeaviateEx.api_response()
  def delete_objects(criteria, opts \\ []) when is_map(criteria) do
    with_client(fn client ->
      BatchAPI.delete_objects(client, criteria, opts)
    end)
  end

  @doc """
  Adds cross-references in batch.

  ## Parameters

  - `references` - List of reference objects
  - `opts` - Additional options

  ## Reference Format

  Each reference should have:
  - `:from` - Beacon URL of source property (e.g., "weaviate://localhost/Article/uuid/hasAuthor")
  - `:to` - Beacon URL of target object (e.g., "weaviate://localhost/Author/uuid")

  ## Examples

      references = [
        %{
          from: "weaviate://localhost/Article/550e8400-e29b-41d4-a716-446655440000/hasAuthor",
          to: "weaviate://localhost/Author/650e8400-e29b-41d4-a716-446655440000"
        }
      ]

      {:ok, result} = Batch.add_references(references)
  """
  @spec add_references(batch_references(), Keyword.t()) :: WeaviateEx.api_response()
  def add_references(references, opts \\ []) when is_list(references) do
    query_string = build_query_string(opts, [:consistency_level])

    case request(:post, "/v1/batch/references#{query_string}", references, opts) do
      {:ok, results} when is_list(results) -> {:ok, %{"results" => results}}
      other -> other
    end
  end

  @default_poll_interval 1000
  @default_max_failures 5
  @default_timeout 300_000

  @doc """
  Wait for all vectors to be indexed after batch insertion.

  This function polls shard status until all vector queues are empty,
  indicating that async vectorization is complete. This is useful when
  you need to ensure all objects are searchable before proceeding.

  ## Parameters

  - `client` - WeaviateEx.Client instance
  - `collection` - Collection name to wait for
  - `opts` - Options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 1000)
  - `:max_failures` - Max consecutive failures before error (default: 5)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000)
  - `:shards` - Specific shards to monitor (default: all shards)

  ## Examples

      # Wait for all shards
      :ok = Batch.wait_for_vector_indexing(client, "Article")

      # Wait with custom timeout
      :ok = Batch.wait_for_vector_indexing(client, "Article", timeout: 60_000)

      # Wait for specific shards
      :ok = Batch.wait_for_vector_indexing(client, "Article", shards: ["shard-0"])

  ## Returns

  - `:ok` - All vectors indexed successfully
  - `{:error, :timeout}` - Timed out waiting for indexing
  - `{:error, {:max_failures, reason}}` - Too many consecutive failures
  """
  @spec wait_for_vector_indexing(WeaviateEx.Client.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def wait_for_vector_indexing(client, collection, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    max_failures = Keyword.get(opts, :max_failures, @default_max_failures)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    target_shards = Keyword.get(opts, :shards)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_indexing(
      client,
      collection,
      target_shards,
      poll_interval,
      max_failures,
      deadline,
      0
    )
  end

  defp do_wait_for_indexing(
         client,
         collection,
         target_shards,
         interval,
         max_fails,
         deadline,
         fail_count
       ) do
    now = System.monotonic_time(:millisecond)

    cond do
      now >= deadline ->
        {:error, :timeout}

      fail_count >= max_fails ->
        {:error, {:max_failures, "exceeded #{max_fails} consecutive failures"}}

      true ->
        case check_indexing_status(client, collection, target_shards) do
          {:ok, :complete} ->
            :ok

          {:ok, :in_progress} ->
            Process.sleep(interval)

            do_wait_for_indexing(
              client,
              collection,
              target_shards,
              interval,
              max_fails,
              deadline,
              0
            )

          {:error, _reason} ->
            Process.sleep(interval)

            do_wait_for_indexing(
              client,
              collection,
              target_shards,
              interval,
              max_fails,
              deadline,
              fail_count + 1
            )
        end
    end
  end

  defp check_indexing_status(client, collection, target_shards) do
    case Cluster.shards(client, collection) do
      {:ok, shards} ->
        shards_to_check = filter_shards(shards, target_shards)

        if Enum.all?(shards_to_check, &Shard.vectors_indexed?/1) do
          {:ok, :complete}
        else
          {:ok, :in_progress}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_shards(shards, nil), do: shards

  defp filter_shards(shards, target_names) do
    Enum.filter(shards, fn shard -> shard.name in target_names end)
  end

  @doc """
  Start a background batch processor.

  Unlike the synchronous `with_batch/3`, this returns immediately and
  processes objects asynchronously in the background.

  ## Options

    * `:batch_size` - Objects per batch (default: 100)
    * `:concurrent_requests` - Max concurrent requests (default: 2)
    * `:flush_interval` - Auto-flush interval in ms (default: 1000)
    * `:on_flush` - Callback on each flush completion
    * `:on_error` - Callback on each error
    * `:tenant` - Tenant name for multi-tenancy

  ## Examples

      {:ok, batcher} = Batch.background(client, "Article",
        batch_size: 100,
        concurrent_requests: 2
      )

      for article <- articles do
        :ok = Batch.Background.add_object(batcher, article)
      end

      results = Batch.Background.stop(batcher, flush: true)
  """
  @spec background(WeaviateEx.Client.t(), String.t(), keyword()) ::
          {:ok, pid()} | {:error, term()}
  def background(client, collection, opts \\ []) do
    opts = Keyword.merge(opts, client: client, collection: collection)
    Background.start_link(opts)
  end

  # Helper to build query strings
  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _value} -> key in allowed_keys end)
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)

    if params == "", do: "", else: "?#{params}"
  end

  defp with_client(fun) when is_function(fun, 1) do
    {:ok, client} =
      WeaviateEx.Client.new(
        base_url: WeaviateEx.base_url(),
        api_key: WeaviateEx.api_key()
      )

    fun.(client)
  end

  # ============================================================================
  # Context Manager Pattern
  # ============================================================================

  @doc """
  Execute batch operations within a context that automatically flushes on exit.

  This provides a Python-like context manager pattern for batch operations.
  All buffered objects and references are automatically flushed when the
  callback completes.

  ## Parameters

    - `client` - WeaviateEx.Client
    - `opts` - Batch options
    - `fun` - Callback function receiving the batch context

  ## Options

    - `:mode` - Batch mode: `:fixed` (default), `:dynamic`, or `:rate_limited`
    - `:batch_size` - Number of objects per batch (default: 100)
    - `:on_flush` - Callback function called after each batch flush
    - `:on_error` - Callback function called on errors
    - `:consistency_level` - Consistency level for requests

  ### Dynamic Mode Options

    - `:min_batch_size` - Minimum batch size (default: 10)
    - `:max_batch_size` - Maximum batch size (default: 1000)
    - `:concurrent_requests` - Number of concurrent requests (default: 2)

  ### Rate-Limited Mode Options

    - `:requests_per_minute` - Maximum requests per minute (default: 60)
    - `:retry_on_rate_limit` - Retry on rate limit errors (default: false)
    - `:max_retries` - Maximum retry attempts (default: 5)

  ## Examples

      # Simple fixed-size batching
      {:ok, results} = Batch.with_batch(client, [batch_size: 100], fn batch ->
        batch
        |> Batch.add_object("Article", %{title: "Test 1"})
        |> Batch.add_object("Article", %{title: "Test 2"})
      end)

      # Dynamic batching
      {:ok, results} = Batch.with_batch(client, [mode: :dynamic], fn batch ->
        Enum.reduce(objects, batch, fn obj, b ->
          Batch.add_object(b, "Article", obj)
        end)
      end)

      # Rate-limited batching
      {:ok, results} = Batch.with_batch(client, [
        mode: :rate_limited,
        requests_per_minute: 30
      ], fn batch ->
        batch
        |> Batch.add_object("Article", %{title: "Test"})
      end)
  """
  @spec with_batch(WeaviateEx.Client.t(), keyword(), (batch_context() -> batch_context())) ::
          {:ok, Results.t()} | {:error, WeaviateEx.Error.t()}
  def with_batch(client, opts, fun) when is_function(fun, 1) do
    mode = Keyword.get(opts, :mode, :fixed)

    case mode do
      :fixed -> with_fixed_batch(client, opts, fun)
      :dynamic -> with_dynamic_batch(client, opts, fun)
      :rate_limited -> with_rate_limited_batch(client, opts, fun)
    end
  end

  @doc """
  Add an object to the batch context.

  Used within a `with_batch/3` callback.

  ## Options

    - `:uuid` - Custom UUID for the object
    - `:vector` - Custom vector for the object
    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      Batch.with_batch(client, [], fn batch ->
        batch
        |> Batch.add_object("Article", %{title: "Test"})
        |> Batch.add_object("Article", %{title: "Test 2"}, uuid: "custom-uuid")
      end)
  """
  @spec add_object(batch_context(), String.t(), map(), keyword()) :: batch_context()
  def add_object(ctx, collection, properties, opts \\ [])

  def add_object(%{mode: :fixed} = ctx, collection, properties, opts) do
    batcher = FixedSize.add_object(ctx.batcher, collection, properties, opts)

    # Check if we need to auto-flush
    if FixedSize.ready_to_send?(batcher) do
      case flush_fixed_batch(ctx.client, batcher, ctx.opts) do
        {:ok, new_results, _} ->
          %{
            ctx
            | batcher: FixedSize.clear(batcher),
              results: merge_results(ctx.results, new_results)
          }

        {:error, _} ->
          # Keep buffer, let final flush handle it
          %{ctx | batcher: batcher}
      end
    else
      %{ctx | batcher: batcher}
    end
  end

  def add_object(%{mode: mode} = ctx, collection, properties, opts)
      when mode in [:dynamic, :rate_limited] do
    module = if mode == :dynamic, do: Dynamic, else: RateLimited
    :ok = module.add_object(ctx.batcher, collection, properties, opts)
    ctx
  end

  @doc """
  Add a reference to the batch context.

  Used within a `with_batch/3` callback.

  ## Options

    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      Batch.with_batch(client, [], fn batch ->
        batch
        |> Batch.add_reference("Article", "uuid-1", "hasAuthor", "author-uuid")
      end)
  """
  @spec add_reference(batch_context(), String.t(), String.t(), String.t(), String.t(), keyword()) ::
          batch_context()
  def add_reference(ctx, collection, from_uuid, property, to_uuid, opts \\ [])

  def add_reference(%{mode: :fixed} = ctx, collection, from_uuid, property, to_uuid, opts) do
    batcher = FixedSize.add_reference(ctx.batcher, collection, from_uuid, property, to_uuid, opts)
    %{ctx | batcher: batcher}
  end

  def add_reference(%{mode: mode} = ctx, collection, from_uuid, property, to_uuid, opts)
      when mode in [:dynamic, :rate_limited] do
    module = if mode == :dynamic, do: Dynamic, else: RateLimited
    :ok = module.add_reference(ctx.batcher, collection, from_uuid, property, to_uuid, opts)
    ctx
  end

  @doc """
  Explicitly flush the current batch within a context.

  Returns updated context with flushed results.

  ## Examples

      Batch.with_batch(client, [], fn batch ->
        batch = Batch.add_object(batch, "Article", %{title: "Test 1"})
        {:ok, batch, _results} = Batch.flush(batch)
        batch = Batch.add_object(batch, "Article", %{title: "Test 2"})
        batch
      end)
  """
  @spec flush(batch_context()) ::
          {:ok, batch_context(), Results.t()} | {:error, WeaviateEx.Error.t()}
  def flush(%{mode: :fixed} = ctx) do
    case flush_fixed_batch(ctx.client, ctx.batcher, ctx.opts) do
      {:ok, results, _} ->
        new_ctx = %{
          ctx
          | batcher: FixedSize.clear(ctx.batcher),
            results: merge_results(ctx.results, results)
        }

        {:ok, new_ctx, results}

      {:error, error} ->
        {:error, error}
    end
  end

  def flush(%{mode: mode} = ctx) when mode in [:dynamic, :rate_limited] do
    module = if mode == :dynamic, do: Dynamic, else: RateLimited

    case module.flush(ctx.batcher) do
      {:ok, results} ->
        new_ctx = %{ctx | results: merge_results(ctx.results, results)}
        {:ok, new_ctx, results}

      {:error, error} ->
        {:error, error}
    end
  end

  # ============================================================================
  # Private Context Manager Helpers
  # ============================================================================

  defp with_fixed_batch(client, opts, fun) do
    batch_size = Keyword.get(opts, :batch_size, 100)
    batcher = FixedSize.new(batch_size: batch_size)

    ctx = %{
      mode: :fixed,
      client: client,
      batcher: batcher,
      opts: opts,
      results: Results.new()
    }

    final_ctx = fun.(ctx)

    # Final flush
    case flush_fixed_batch(client, final_ctx.batcher, opts) do
      {:ok, results, _} ->
        {:ok, merge_results(final_ctx.results, results)}

      {:error, error} ->
        if Keyword.get(opts, :on_error), do: Keyword.get(opts, :on_error).(error)
        {:error, error}
    end
  end

  defp with_dynamic_batch(client, opts, fun) do
    {:ok, pid} = Dynamic.start(Keyword.put(opts, :client, client))

    ctx = %{
      mode: :dynamic,
      client: client,
      batcher: pid,
      opts: opts,
      results: Results.new()
    }

    try do
      final_ctx = fun.(ctx)
      {:ok, results} = Dynamic.stop(pid)
      {:ok, merge_results(final_ctx.results, results)}
    catch
      kind, reason ->
        Dynamic.stop(pid)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp with_rate_limited_batch(client, opts, fun) do
    {:ok, pid} = RateLimited.start(Keyword.put(opts, :client, client))

    ctx = %{
      mode: :rate_limited,
      client: client,
      batcher: pid,
      opts: opts,
      results: Results.new()
    }

    try do
      final_ctx = fun.(ctx)
      {:ok, results} = RateLimited.stop(pid)
      {:ok, merge_results(final_ctx.results, results)}
    catch
      kind, reason ->
        RateLimited.stop(pid)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp flush_fixed_batch(client, batcher, opts) do
    objects = FixedSize.get_batches(batcher) |> List.flatten()
    references = FixedSize.get_reference_batches(batcher) |> List.flatten()

    results = Results.new()

    with {:ok, results} <- flush_objects_list(client, objects, results, opts) do
      flush_references_list(client, references, results, batcher, opts)
    end
  end

  defp flush_objects_list(_client, [], results, _opts), do: {:ok, results}

  defp flush_objects_list(client, objects, results, opts) do
    formatted_objects = format_objects(objects)

    case BatchAPI.create_objects(client, formatted_objects, Keyword.put(opts, :summary, true)) do
      {:ok, %BatchAPI.Result{} = result} ->
        {:ok, merge_results(results, convert_api_result(result))}

      {:error, error} ->
        {:error, error}
    end
  end

  defp flush_references_list(_client, [], results, batcher, opts) do
    if Keyword.get(opts, :on_flush), do: Keyword.get(opts, :on_flush).(results)
    {:ok, results, batcher}
  end

  defp flush_references_list(client, references, results, batcher, opts) do
    formatted_refs = format_references(references)

    case WeaviateEx.Client.request(
           client,
           :post,
           "/v1/batch/references",
           formatted_refs,
           opts
         ) do
      {:ok, ref_results} when is_list(ref_results) ->
        ref_processed = process_reference_results(ref_results)
        {:ok, merge_results(results, ref_processed), batcher}

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_objects(objects) do
    Enum.map(objects, fn obj ->
      base = %{
        "class" => obj.collection,
        "properties" => obj.properties
      }

      base
      |> maybe_put("id", obj.uuid)
      |> maybe_put("vector", obj.vector)
      |> maybe_put("tenant", obj.tenant)
    end)
  end

  defp format_references(references) do
    Enum.map(references, fn ref ->
      %{
        "from" => "weaviate://localhost/#{ref.collection}/#{ref.from_uuid}/#{ref.property}",
        "to" => "weaviate://localhost/#{ref.collection}/#{ref.to_uuid}"
      }
    end)
  end

  defp convert_api_result(%BatchAPI.Result{} = result) do
    alias WeaviateEx.Batch.ErrorTracking.ErrorObject

    base = Results.new()

    successful_results =
      result.successful
      |> Enum.with_index()
      |> Enum.reduce(base, fn {obj, idx}, acc ->
        Results.add_success(acc, idx, obj["id"])
      end)

    Enum.reduce(result.errors, successful_results, fn error, acc ->
      error_obj = %ErrorObject{
        message: Enum.join(error.messages, "; "),
        object: error.raw,
        original_uuid: error.id
      }

      Results.add_error(acc, error_obj)
    end)
  end

  defp process_reference_results(results) do
    alias WeaviateEx.Batch.ErrorTracking.ErrorObject

    Enum.reduce(results, Results.new(), fn result, acc ->
      case result do
        %{"status" => "SUCCESS"} ->
          Results.add_success(acc, map_size(acc.successful_uuids), "reference")

        %{"status" => "FAILED"} = failed ->
          error = %ErrorObject{
            message: Map.get(failed, "result", %{}) |> Map.get("errors", "Unknown error"),
            object: failed
          }

          Results.add_error(acc, error)

        _ ->
          acc
      end
    end)
  end

  defp merge_results(acc, new) do
    # Offset the new UUIDs to avoid key collisions
    base_index = map_size(acc.successful_uuids)

    offset_uuids =
      for {idx, uuid} <- new.successful_uuids, into: %{} do
        {base_index + idx, uuid}
      end

    %Results{
      failed_objects: acc.failed_objects ++ new.failed_objects,
      failed_references: acc.failed_references ++ new.failed_references,
      successful_uuids: Map.merge(acc.successful_uuids, offset_uuids),
      elapsed_seconds: acc.elapsed_seconds + new.elapsed_seconds
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
