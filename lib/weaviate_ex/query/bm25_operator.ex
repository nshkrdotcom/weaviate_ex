defmodule WeaviateEx.Query.BM25Operator do
  @moduledoc """
  BM25 operator configuration for keyword search.

  Controls how search tokens are combined in BM25 queries.

  ## Examples

      # OR with minimum match - at least 2 tokens must match
      operator = BM25Operator.or_(2)

      # AND - all tokens must match
      operator = BM25Operator.and_()

      # Use in query
      Query.get("Article")
      |> Query.bm25("machine learning AI", operator: operator)
  """

  @type t :: %__MODULE__{
          type: :and | :or,
          minimum_should_match: non_neg_integer() | nil
        }

  defstruct [:type, :minimum_should_match]

  @doc """
  Create an OR operator with minimum token match requirement.

  At least `minimum_match` tokens must match for a document to be returned.

  ## Examples

      BM25Operator.or_(2)  # At least 2 tokens must match
  """
  @spec or_(non_neg_integer()) :: t()
  def or_(minimum_match) when is_integer(minimum_match) and minimum_match >= 0 do
    %__MODULE__{
      type: :or,
      minimum_should_match: minimum_match
    }
  end

  @doc """
  Create an AND operator.

  All tokens must match for a document to be returned.

  ## Examples

      BM25Operator.and_()
  """
  @spec and_() :: t()
  def and_ do
    %__MODULE__{
      type: :and,
      minimum_should_match: nil
    }
  end

  @doc """
  Convert BM25 operator configuration to GraphQL format.

  ## Examples

      operator = BM25Operator.or_(2)
      BM25Operator.to_graphql(operator)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{type: :and}) do
    "{operator: And}"
  end

  def to_graphql(%__MODULE__{type: :or, minimum_should_match: min}) do
    "{operator: Or, minimumShouldMatch: #{min}}"
  end
end
