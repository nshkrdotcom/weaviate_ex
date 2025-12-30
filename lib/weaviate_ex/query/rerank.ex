defmodule WeaviateEx.Query.Rerank do
  @moduledoc """
  Reranking configuration for query results.

  Reranking re-orders search results using a reranker model configured
  on the collection. The reranker scores results based on relevance to
  the query and returns a `rerank_score` in metadata.

  ## Examples

      # Rerank using a property
      rerank = Rerank.new("content")

      # Rerank with custom query
      rerank = Rerank.new("content", query: "What is machine learning?")

      # Use in query
      Query.get("Article")
      |> Query.near_text("machine learning")
      |> Query.rerank(rerank)
      |> Query.execute(client)
  """

  @type t :: %__MODULE__{
          prop: String.t(),
          query: String.t() | nil
        }

  defstruct [:prop, :query]

  @doc """
  Create a new rerank configuration.

  ## Parameters

    - `prop` - The property to use for reranking (e.g., "content", "description")
    - `opts` - Options:
      - `:query` - Optional query string for reranking. If not provided,
        the original search query is used.

  ## Examples

      # Basic rerank on a property
      Rerank.new("content")

      # Rerank with custom query
      Rerank.new("content", query: "What is deep learning?")

      # Rerank on description field
      Rerank.new("description", query: "AI applications")
  """
  @spec new(String.t(), keyword()) :: t()
  def new(prop, opts \\ []) when is_binary(prop) do
    %__MODULE__{
      prop: prop,
      query: Keyword.get(opts, :query)
    }
  end

  @doc """
  Convert rerank configuration to GraphQL format.

  ## Examples

      rerank = Rerank.new("content", query: "deep learning")
      Rerank.to_graphql(rerank)
      # => "{property: \"content\", query: \"deep learning\"}"
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = rerank) do
    query_escaped = if rerank.query, do: escape_string(rerank.query), else: nil

    parts = [~s(property: "#{escape_string(rerank.prop)}")]

    parts =
      if query_escaped do
        parts ++ [~s(query: "#{query_escaped}")]
      else
        parts
      end

    "{#{Enum.join(parts, ", ")}}"
  end

  @doc """
  Convert rerank configuration to map format (for gRPC).

  ## Examples

      rerank = Rerank.new("content", query: "deep learning")
      Rerank.to_map(rerank)
      # => %{property: "content", query: "deep learning"}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{prop: prop, query: nil}) do
    %{property: prop}
  end

  def to_map(%__MODULE__{prop: prop, query: query}) do
    %{property: prop, query: query}
  end

  @doc """
  Convert rerank configuration to gRPC Rerank message.

  ## Examples

      rerank = Rerank.new("content", query: "deep learning")
      Rerank.to_grpc(rerank)
      # => %Weaviate.V1.Rerank{property: "content", query: "deep learning"}
  """
  @spec to_grpc(t()) :: struct()
  def to_grpc(%__MODULE__{prop: prop, query: query}) do
    %Weaviate.V1.Rerank{
      property: prop,
      query: query
    }
  end

  @doc """
  Validate rerank configuration.

  ## Examples

      iex> Rerank.valid?(Rerank.new("content"))
      true

      iex> Rerank.valid?(%Rerank{prop: nil})
      false
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{prop: prop}) when is_binary(prop) and prop != "", do: true
  def valid?(_), do: false

  # Escape special characters in GraphQL strings
  defp escape_string(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end
end
