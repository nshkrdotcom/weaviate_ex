defmodule WeaviateEx.Iterator do
  @moduledoc """
  Collection iterator for cursor-based pagination.

  Provides a way to iterate through all objects in a collection
  using cursor-based pagination, which is more efficient than
  offset-based pagination for large collections.

  ## Examples

      # Create iterator
      iterator = Iterator.new(client, "Article",
        return_properties: ["title", "content"],
        batch_size: 100
      )

      # Use as Elixir Stream
      Iterator.stream(iterator)
      |> Stream.take(1000)
      |> Enum.to_list()

      # Manual iteration
      {:ok, {objects, next_iterator}} = Iterator.next_batch(iterator)
  """

  alias WeaviateEx.Client

  @type t :: %__MODULE__{
          client: Client.t(),
          collection: String.t(),
          batch_size: pos_integer(),
          return_properties: [String.t()],
          include_vector: boolean(),
          cursor: String.t() | nil,
          filter: map() | nil,
          tenant: String.t() | nil
        }

  defstruct [
    :client,
    :collection,
    :cursor,
    :filter,
    :tenant,
    batch_size: 100,
    return_properties: [],
    include_vector: false
  ]

  @doc """
  Create a new iterator for a collection.

  ## Options

    - `:batch_size` - Number of objects per batch (default: 100)
    - `:return_properties` - Properties to return (default: all)
    - `:include_vector` - Include vector in response (default: false)
    - `:after` - Start cursor (for resuming iteration)
    - `:filter` - Filter to apply to objects
    - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      Iterator.new(client, "Article", batch_size: 50)
      Iterator.new(client, "Article", return_properties: ["title"])
  """
  @spec new(Client.t(), String.t(), keyword()) :: t()
  def new(client, collection, opts \\ []) do
    %__MODULE__{
      client: client,
      collection: collection,
      batch_size: Keyword.get(opts, :batch_size, 100),
      return_properties: Keyword.get(opts, :return_properties, []),
      include_vector: Keyword.get(opts, :include_vector, false),
      cursor: Keyword.get(opts, :after),
      filter: Keyword.get(opts, :filter),
      tenant: Keyword.get(opts, :tenant)
    }
  end

  @doc """
  Create a lazy stream from the iterator.

  Returns an Elixir Stream that fetches objects on demand.

  ## Examples

      Iterator.new(client, "Article")
      |> Iterator.stream()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream(t()) :: Enumerable.t()
  def stream(%__MODULE__{} = iterator) do
    Stream.unfold(iterator, fn
      nil ->
        nil

      iter ->
        case next_batch(iter) do
          {:ok, {[], _next_iter}} ->
            nil

          {:ok, {objects, next_iter}} ->
            {objects, next_iter}

          {:error, _} ->
            nil
        end
    end)
    |> Stream.flat_map(& &1)
  end

  @doc """
  Fetch the next batch of objects.

  Returns `{:ok, {objects, next_iterator}}` where `next_iterator`
  can be used to fetch the next batch.

  ## Examples

      {:ok, {objects, next_iter}} = Iterator.next_batch(iterator)
  """
  @spec next_batch(t()) :: {:ok, {[map()], t() | nil}} | {:error, term()}
  def next_batch(%__MODULE__{client: client} = iterator) do
    query = build_query(iterator)

    case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
      {:ok, %{"data" => %{"Get" => get_results}}} ->
        collection = iterator.collection
        objects = Map.get(get_results, collection, []) || []

        next_iterator =
          if length(objects) < iterator.batch_size do
            nil
          else
            last_id =
              objects
              |> List.last()
              |> get_in(["_additional", "id"])

            with_cursor(iterator, last_id)
          end

        {:ok, {objects, next_iterator}}

      {:ok, %{"errors" => errors}} ->
        {:error, {:graphql_errors, errors}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Build the GraphQL query for the current iterator state.
  """
  @spec build_query(t()) :: String.t()
  def build_query(%__MODULE__{} = iterator) do
    collection = iterator.collection
    properties = build_properties_string(iterator)
    additional = build_additional_string(iterator)
    args = build_args_string(iterator)

    """
    {
      Get {
        #{collection}#{args} {
          #{properties}
          #{additional}
        }
      }
    }
    """
  end

  @doc """
  Update the cursor for the next page.
  """
  @spec with_cursor(t(), String.t() | nil) :: t()
  def with_cursor(%__MODULE__{} = iterator, cursor) do
    %{iterator | cursor: cursor}
  end

  # Private helpers

  defp build_properties_string(%{return_properties: []}) do
    ""
  end

  defp build_properties_string(%{return_properties: props}) do
    Enum.join(props, "\n          ")
  end

  defp build_additional_string(%{include_vector: include_vector}) do
    vector_str = if include_vector, do: " vector", else: ""
    "_additional { id#{vector_str} }"
  end

  defp build_args_string(iterator) do
    args = []

    # Add limit
    args = ["limit: #{iterator.batch_size}" | args]

    # Add after cursor
    args =
      case iterator.cursor do
        nil -> args
        cursor -> ["after: \"#{cursor}\"" | args]
      end

    # Add filter
    args =
      case iterator.filter do
        nil -> args
        filter -> ["where: #{encode_filter(filter)}" | args]
      end

    # Add tenant
    args =
      case iterator.tenant do
        nil -> args
        tenant -> ["tenant: \"#{tenant}\"" | args]
      end

    "(#{Enum.join(Enum.reverse(args), ", ")})"
  end

  defp encode_filter(filter) when is_map(filter) do
    filter
    |> Jason.encode!()
    |> String.replace("\"", "")
  end
end
