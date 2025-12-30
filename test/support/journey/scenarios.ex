defmodule WeaviateEx.Journey.Scenarios do
  @moduledoc """
  Shared journey test scenarios ported from Python client.

  Each scenario exercises a complete workflow using the WeaviateEx SDK,
  validating that the client works correctly when embedded in web applications.

  ## Available Scenarios

  - `simple/1` - Create collection, insert objects, query, cleanup
  - `batch_insert_and_search/1` - Batch 1000 objects, vector search
  - `concurrent_operations/1` - Multiple simultaneous operations

  ## Usage

      client = get_weaviate_client()
      :ok = WeaviateEx.Journey.Scenarios.simple(client)
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Query

  @vector_dimensions 128

  @doc """
  Simple journey: Create collection, insert objects, query, cleanup.

  This scenario validates basic SDK functionality:
  1. Create a collection with text properties
  2. Insert 100 objects with vectors
  3. Perform a vector similarity search
  4. Clean up the collection

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec simple(Client.t()) :: :ok | {:error, term()}
  def simple(%Client{} = client) do
    collection_name = unique_collection_name("JourneySimple")

    with :ok <- create_simple_collection(client, collection_name),
         :ok <- insert_objects(client, collection_name, 100),
         :ok <- query_objects(client, collection_name),
         :ok <- cleanup_collection(client, collection_name) do
      :ok
    else
      {:error, reason} ->
        # Attempt cleanup even on failure
        cleanup_collection(client, collection_name)
        {:error, reason}
    end
  end

  @doc """
  Batch insert and search journey: Batch 1000 objects, vector search.

  This scenario validates batch operations and vector search:
  1. Create a collection with vector config
  2. Batch insert 1000 objects with vectors
  3. Perform vector similarity search
  4. Verify search results
  5. Clean up

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec batch_insert_and_search(Client.t()) :: :ok | {:error, term()}
  def batch_insert_and_search(%Client{} = client) do
    collection_name = unique_collection_name("JourneyBatch")

    with :ok <- create_vector_collection(client, collection_name),
         :ok <- batch_insert_objects(client, collection_name, 1000),
         :ok <- vector_search(client, collection_name),
         :ok <- cleanup_collection(client, collection_name) do
      :ok
    else
      {:error, reason} ->
        cleanup_collection(client, collection_name)
        {:error, reason}
    end
  end

  @doc """
  Concurrent operations journey: Multiple simultaneous operations.

  This scenario validates thread/process safety:
  1. Create a collection
  2. Spawn 10 concurrent tasks that each insert and query
  3. Wait for all tasks to complete
  4. Verify no errors occurred
  5. Clean up

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec concurrent_operations(Client.t()) :: :ok | {:error, term()}
  def concurrent_operations(%Client{} = client) do
    collection_name = unique_collection_name("JourneyConcurrent")

    with :ok <- create_simple_collection(client, collection_name),
         :ok <- run_concurrent_operations(client, collection_name, 10),
         :ok <- cleanup_collection(client, collection_name) do
      :ok
    else
      {:error, reason} ->
        cleanup_collection(client, collection_name)
        {:error, reason}
    end
  end

  # Private helper functions

  defp unique_collection_name(prefix) do
    timestamp = System.system_time(:millisecond)
    random_suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{prefix}_#{timestamp}_#{random_suffix}"
  end

  defp create_simple_collection(client, collection_name) do
    config = %{
      "class" => collection_name,
      "description" => "Journey test collection",
      "vectorizer" => "none",
      "properties" => [
        %{
          "name" => "title",
          "dataType" => ["text"],
          "description" => "Object title"
        },
        %{
          "name" => "content",
          "dataType" => ["text"],
          "description" => "Object content"
        },
        %{
          "name" => "index",
          "dataType" => ["int"],
          "description" => "Object index"
        }
      ]
    }

    case Client.request(client, :post, "/v1/schema", config, []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:create_collection_failed, reason}}
    end
  end

  defp create_vector_collection(client, collection_name) do
    config = %{
      "class" => collection_name,
      "description" => "Journey batch test collection",
      "vectorizer" => "none",
      "vectorIndexConfig" => %{
        "distance" => "cosine"
      },
      "properties" => [
        %{
          "name" => "index",
          "dataType" => ["int"],
          "description" => "Object index"
        },
        %{
          "name" => "data",
          "dataType" => ["text"],
          "description" => "Object data"
        }
      ]
    }

    case Client.request(client, :post, "/v1/schema", config, []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:create_collection_failed, reason}}
    end
  end

  defp insert_objects(client, collection_name, count) do
    results =
      1..count
      |> Enum.map(fn i ->
        object = %{
          "class" => collection_name,
          "properties" => %{
            "title" => "Object #{i}",
            "content" => "Content for object #{i}",
            "index" => i
          },
          "vector" => generate_random_vector(@vector_dimensions)
        }

        Client.request(client, :post, "/v1/objects", object, [])
      end)

    errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:insert_failed, length(errors), errors}}
    end
  end

  defp batch_insert_objects(client, collection_name, count) do
    # Insert in batches of 100
    batch_size = 100

    results =
      1..count
      |> Enum.chunk_every(batch_size)
      |> Enum.map(fn batch_indices ->
        objects =
          Enum.map(batch_indices, fn i ->
            %{
              "class" => collection_name,
              "properties" => %{
                "index" => i,
                "data" => "Batch data #{i}"
              },
              "vector" => generate_random_vector(@vector_dimensions)
            }
          end)

        body = %{"objects" => objects}
        Client.request(client, :post, "/v1/batch/objects", body, [])
      end)

    errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:batch_insert_failed, length(errors), errors}}
    end
  end

  defp query_objects(client, collection_name) do
    query =
      Query.get(collection_name)
      |> Query.fields(["title", "content", "index"])
      |> Query.limit(10)

    case Query.execute(query, client) do
      {:ok, results} when is_list(results) ->
        if length(results) > 0, do: :ok, else: {:error, :no_results}

      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  defp vector_search(client, collection_name) do
    search_vector = generate_random_vector(@vector_dimensions)

    query =
      Query.get(collection_name)
      |> Query.near_vector(search_vector, distance: 0.9)
      |> Query.fields(["index", "data"])
      |> Query.additional(["distance"])
      |> Query.limit(10)

    case Query.execute(query, client) do
      {:ok, results} when is_list(results) ->
        if length(results) > 0, do: :ok, else: {:error, :no_vector_results}

      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error, {:vector_search_failed, reason}}
    end
  end

  defp run_concurrent_operations(client, collection_name, concurrency) do
    tasks =
      1..concurrency
      |> Enum.map(fn task_id ->
        Task.async(fn ->
          # Each task inserts an object and queries
          with :ok <- insert_single_object(client, collection_name, task_id * 1000) do
            query_single_object(client, collection_name)
          end
        end)
      end)

    results =
      tasks
      |> Task.await_many(30_000)

    errors = Enum.filter(results, fn result -> result != :ok end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:concurrent_operations_failed, errors}}
    end
  end

  defp insert_single_object(client, collection_name, base_index) do
    object = %{
      "class" => collection_name,
      "properties" => %{
        "title" => "Concurrent object #{base_index}",
        "content" => "Content from concurrent task",
        "index" => base_index
      },
      "vector" => generate_random_vector(@vector_dimensions)
    }

    case Client.request(client, :post, "/v1/objects", object, []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:insert_failed, reason}}
    end
  end

  defp query_single_object(client, collection_name) do
    query =
      Query.get(collection_name)
      |> Query.fields(["title"])
      |> Query.limit(1)

    case Query.execute(query, client) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:query_failed, reason}}
    end
  end

  defp cleanup_collection(client, collection_name) do
    case Client.request(client, :delete, "/v1/schema/#{collection_name}", nil, []) do
      {:ok, _} -> :ok
      # Collection might not exist, which is fine for cleanup
      {:error, %{status_code: 404}} -> :ok
      {:error, reason} -> {:error, {:cleanup_failed, reason}}
    end
  end

  defp generate_random_vector(dimensions) do
    for _ <- 1..dimensions, do: :rand.uniform()
  end
end
