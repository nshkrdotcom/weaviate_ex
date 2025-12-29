defmodule WeaviateEx.Query.Rerank do
  @moduledoc """
  Rerank configuration for search queries.

  Reranking uses a reranker model to re-order search results based on
  the specified property content and optional query.

  ## Examples

      # Basic rerank on a property
      rerank = Rerank.new("content")

      # Rerank with custom query
      rerank = Rerank.new("content", query: "deep learning applications")

      # Use in query
      Query.get("Article")
      |> Query.near_text("machine learning")
      |> Query.rerank(rerank)
  """

  @type t :: %__MODULE__{
          prop: String.t(),
          query: String.t() | nil
        }

  defstruct [:prop, :query]

  @doc """
  Create a new rerank configuration.

  ## Parameters

    - `prop` - The property to use for reranking
    - `opts` - Options:
      - `:query` - Optional query string for reranking

  ## Examples

      Rerank.new("content")
      Rerank.new("content", query: "deep learning applications")
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
      # => "{property: \\\"content\\\", query: \\\"deep learning\\\"}"
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = rerank) do
    parts = [~s(property: "#{rerank.prop}")]

    parts =
      if rerank.query do
        parts ++ [~s(query: "#{rerank.query}")]
      else
        parts
      end

    "{#{Enum.join(parts, ", ")}}"
  end
end
