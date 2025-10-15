defmodule WeaviateEx.Batch do
  @moduledoc """
  Functions for batch operations in Weaviate.

  Batch operations are much more efficient than individual operations
  when dealing with large numbers of objects.

  ## Examples

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
  """

  import WeaviateEx, only: [request: 4]

  @type batch_objects :: list(map())
  @type batch_references :: list(map())
  @type delete_criteria :: map()

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
    query_string = build_query_string(opts, [:consistency_level])
    body = %{objects: objects}
    request(:post, "/v1/batch/objects#{query_string}", body, opts)
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
    query_string = build_query_string(opts, [:consistency_level])
    request(:delete, "/v1/batch/objects#{query_string}", criteria, opts)
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
    request(:post, "/v1/batch/references#{query_string}", references, opts)
  end

  # Helper to build query strings
  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _value} -> key in allowed_keys end)
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    if params == "", do: "", else: "?#{params}"
  end
end
