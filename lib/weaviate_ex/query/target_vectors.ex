defmodule WeaviateEx.Query.TargetVectors do
  @moduledoc """
  Target vector configuration for named vector collections.

  When a collection has multiple named vectors, you can specify which
  vector(s) to use for a search and how to combine them.

  ## Examples

      # Single target vector
      TargetVectors.single("content_vector")

      # Average of multiple vectors
      TargetVectors.average(["title_vector", "content_vector"])

      # Manual weights
      TargetVectors.manual_weights(%{
        "title_vector" => 0.7,
        "content_vector" => 0.3
      })
  """

  @type single :: String.t()
  @type combination :: {:sum | :average | :minimum | :manual_weights | :relative_score, term()}
  @type t :: single() | combination()

  @doc """
  Use a single target vector.

  ## Examples

      TargetVectors.single("content_vector")
  """
  @spec single(String.t()) :: String.t()
  def single(name) when is_binary(name), do: name

  @doc """
  Combine vectors by summing their scores.

  ## Examples

      TargetVectors.sum(["title_vector", "content_vector"])
  """
  @spec sum([String.t()]) :: combination()
  def sum(vectors) when is_list(vectors), do: {:sum, vectors}

  @doc """
  Combine vectors by averaging their scores.

  ## Examples

      TargetVectors.average(["title_vector", "content_vector"])
  """
  @spec average([String.t()]) :: combination()
  def average(vectors) when is_list(vectors), do: {:average, vectors}

  @doc """
  Combine vectors by taking the minimum score.

  ## Examples

      TargetVectors.minimum(["title_vector", "content_vector"])
  """
  @spec minimum([String.t()]) :: combination()
  def minimum(vectors) when is_list(vectors), do: {:minimum, vectors}

  @doc """
  Combine vectors with manual weights.

  Weights should sum to 1.0 for best results.

  ## Examples

      TargetVectors.manual_weights(%{
        "title_vector" => 0.7,
        "content_vector" => 0.3
      })
  """
  @spec manual_weights(map()) :: combination()
  def manual_weights(weights) when is_map(weights), do: {:manual_weights, weights}

  @doc """
  Combine vectors using relative score weighting.

  ## Examples

      TargetVectors.relative_score(%{
        "title_vector" => 0.6,
        "content_vector" => 0.4
      })
  """
  @spec relative_score(map()) :: combination()
  def relative_score(weights) when is_map(weights), do: {:relative_score, weights}

  @doc """
  Convert target vectors configuration to GraphQL format.

  ## Examples

      target = TargetVectors.average(["title_vector", "content_vector"])
      TargetVectors.to_graphql(target)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(target) when is_binary(target) do
    ~s("#{target}")
  end

  def to_graphql({:sum, vectors}) do
    format_combination("sum", vectors)
  end

  def to_graphql({:average, vectors}) do
    format_combination("average", vectors)
  end

  def to_graphql({:minimum, vectors}) do
    format_combination("minimum", vectors)
  end

  def to_graphql({:manual_weights, weights}) do
    format_weighted("manualWeights", weights)
  end

  def to_graphql({:relative_score, weights}) do
    format_weighted("relativeScore", weights)
  end

  # Private helpers

  defp format_combination(method, vectors) do
    vectors_str = Enum.map_join(vectors, ", ", &~s("#{&1}"))
    "{targetVectors: [#{vectors_str}], combinationMethod: #{method}}"
  end

  defp format_weighted(method, weights) do
    vectors = Map.keys(weights)
    vectors_str = Enum.map_join(vectors, ", ", &~s("#{&1}"))

    weights_str =
      weights
      |> Enum.map_join(", ", fn {name, weight} -> ~s("#{name}": #{weight}) end)

    "{targetVectors: [#{vectors_str}], combinationMethod: #{method}, weights: {#{weights_str}}}"
  end
end
