defmodule WeaviateEx.Query.TargetVectors do
  @moduledoc """
  Target vector configuration for named vector collections.

  When a collection has multiple named vectors, you can specify which
  vector(s) to use for a search and how to combine them.

  ## Combination Methods

    * `:sum` - Sum of distances/similarities
    * `:average` - Average of distances/similarities
    * `:minimum` - Minimum distance (closest match)
    * `:manual_weights` - Weighted combination with custom weights
    * `:relative_score` - Relative score weighting

  ## Examples

      # Single target vector
      Query.near_vector(query, vector, target_vectors: "title_vector")

      # Multiple vectors with sum combination
      target = TargetVectors.combine(["title_vector", "content_vector"], method: :sum)
      Query.near_vector(query, vector, target_vectors: target)

      # Manual weights
      target = TargetVectors.weighted(%{
        "title_vector" => 0.7,
        "content_vector" => 0.3
      })
      Query.near_text(query, "search term", target_vectors: target)
  """

  alias Weaviate.V1.{Targets, WeightsForTarget}

  defmodule Config do
    @moduledoc """
    Configuration struct for target vector settings.
    """

    @type combination_method :: :sum | :average | :minimum | :manual_weights | :relative_score

    @type t :: %__MODULE__{
            vectors: [String.t()],
            method: combination_method(),
            weights: %{String.t() => float()} | nil
          }

    defstruct [:vectors, :method, :weights]
  end

  @type single :: String.t()
  @type combination :: {:sum | :average | :minimum | :manual_weights | :relative_score, term()}
  @type t :: single() | combination() | Config.t()

  @valid_methods [:sum, :average, :minimum, :manual_weights, :relative_score]

  # ============================================================================
  # Legacy API (backwards compatible)
  # ============================================================================

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

  # ============================================================================
  # New Struct-based API
  # ============================================================================

  @doc """
  Create a combined target vector configuration.

  ## Options

    * `:method` - Combination method: `:sum`, `:average`, or `:minimum` (default: `:sum`)

  ## Examples

      TargetVectors.combine(["title_vector", "content_vector"], method: :average)
  """
  @spec combine([String.t()], keyword()) :: Config.t()
  def combine(vectors, opts \\ []) when is_list(vectors) do
    method = Keyword.get(opts, :method, :sum)

    if method not in [:sum, :average, :minimum] do
      raise ArgumentError,
            "invalid combination method: #{inspect(method)}. " <>
              "Must be one of: :sum, :average, :minimum"
    end

    %Config{
      vectors: vectors,
      method: method,
      weights: nil
    }
  end

  @doc """
  Create a manually weighted target vector configuration.

  ## Examples

      TargetVectors.weighted(%{
        "title_vector" => 0.7,
        "content_vector" => 0.3
      })
  """
  @spec weighted(%{String.t() => float()}) :: Config.t()
  def weighted(weights) when is_map(weights) do
    %Config{
      vectors: Map.keys(weights),
      method: :manual_weights,
      weights: weights
    }
  end

  @doc """
  Normalize target_vectors option to consistent format.

  Accepts:
    * `nil` - returns nil
    * String - single target vector name
    * List of strings - multiple target vectors (uses sum)
    * Config.t() - full configuration struct

  ## Examples

      TargetVectors.normalize("content_vector")
      # => %Config{vectors: ["content_vector"], method: :sum}

      TargetVectors.normalize(["vec1", "vec2"])
      # => %Config{vectors: ["vec1", "vec2"], method: :sum}
  """
  @spec normalize(String.t() | [String.t()] | Config.t() | nil) :: Config.t() | nil
  def normalize(nil), do: nil
  def normalize(%Config{} = target), do: target
  def normalize(vector) when is_binary(vector), do: %Config{vectors: [vector], method: :sum}
  def normalize(vectors) when is_list(vectors), do: combine(vectors, method: :sum)

  # ============================================================================
  # Conversion Functions
  # ============================================================================

  @grpc_method_map %{
    sum: :COMBINATION_METHOD_TYPE_SUM,
    average: :COMBINATION_METHOD_TYPE_AVERAGE,
    minimum: :COMBINATION_METHOD_TYPE_MIN,
    manual_weights: :COMBINATION_METHOD_TYPE_MANUAL,
    relative_score: :COMBINATION_METHOD_TYPE_RELATIVE_SCORE
  }

  @doc """
  Convert to gRPC format for query execution.

  ## Examples

      target = TargetVectors.combine(["vec1", "vec2"], method: :average)
      TargetVectors.to_grpc(target)
      # => %Weaviate.V1.Targets{target_vectors: ["vec1", "vec2"], combination: :COMBINATION_METHOD_TYPE_AVERAGE}
  """
  @spec to_grpc(String.t() | [String.t()] | Config.t() | nil) :: struct() | nil
  def to_grpc(nil), do: nil

  def to_grpc(target) when is_binary(target) do
    %Targets{
      target_vectors: [target],
      combination: :COMBINATION_METHOD_TYPE_SUM
    }
  end

  def to_grpc(targets) when is_list(targets) do
    %Targets{
      target_vectors: targets,
      combination: :COMBINATION_METHOD_TYPE_SUM
    }
  end

  def to_grpc(%Config{} = target) do
    %Targets{
      target_vectors: target.vectors,
      combination: Map.fetch!(@grpc_method_map, target.method),
      weights_for_targets: build_weights(target.weights)
    }
  end

  # Also handle legacy tuple format
  def to_grpc({method, vectors}) when method in @valid_methods and is_list(vectors) do
    %Targets{
      target_vectors: vectors,
      combination: Map.fetch!(@grpc_method_map, method)
    }
  end

  def to_grpc({method, weights})
      when method in [:manual_weights, :relative_score] and is_map(weights) do
    %Targets{
      target_vectors: Map.keys(weights),
      combination: Map.fetch!(@grpc_method_map, method),
      weights_for_targets: build_weights(weights)
    }
  end

  defp build_weights(nil), do: []

  defp build_weights(weights) when is_map(weights) do
    weights
    |> Enum.sort_by(fn {name, _weight} -> name end)
    |> Enum.map(fn {name, weight} ->
      %WeightsForTarget{target: name, weight: weight}
    end)
  end

  @doc """
  Convert target vectors configuration to GraphQL format.

  ## Examples

      target = TargetVectors.average(["title_vector", "content_vector"])
      TargetVectors.to_graphql(target)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(nil), do: ""

  def to_graphql(target) when is_binary(target) do
    ~s("#{target}")
  end

  def to_graphql(%Config{method: method, vectors: vectors, weights: weights}) do
    if weights do
      format_weighted(graphql_method(method), weights)
    else
      format_combination(graphql_method(method), vectors)
    end
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

  defp graphql_method(:sum), do: "sum"
  defp graphql_method(:average), do: "average"
  defp graphql_method(:minimum), do: "minimum"
  defp graphql_method(:manual_weights), do: "manualWeights"
  defp graphql_method(:relative_score), do: "relativeScore"

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
