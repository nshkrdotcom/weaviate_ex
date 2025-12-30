defmodule WeaviateEx.Query.NearVector do
  @moduledoc """
  Near vector query configuration builders.

  This module provides functions for building near_vector queries,
  including support for single vectors, multiple vectors, and
  per-target named vector configurations.

  ## Single Vector Query

      # Standard vector search
      vector = [0.1, 0.2, 0.3, ...]
      NearVector.single(vector)

  ## List of Vectors Query

      # Query with multiple vectors (averaged or combined)
      vectors = [vector1, vector2, vector3]
      NearVector.list_of_vectors(vectors)

  ## Per-Target Vectors Query

      # Different vectors for different named vector spaces
      NearVector.per_target(%{
        "title_vector" => title_vec,
        "content_vector" => content_vec
      })

  These can be used with the Query module:

      Query.new("Article")
      |> Query.near_vector(NearVector.per_target(%{"title" => vec}))
      |> Query.execute(client)
  """

  @type vector :: [float()]
  @type target_vectors :: %{String.t() => vector()}

  @doc """
  Create a single vector query.

  ## Parameters

  - `vector` - A list of floats representing the query vector

  ## Options

  - `:certainty` - Minimum certainty threshold (0.0 to 1.0)
  - `:distance` - Maximum distance threshold

  ## Examples

      NearVector.single([0.1, 0.2, 0.3])
      NearVector.single(vector, certainty: 0.8)
  """
  @spec single(vector(), keyword()) :: map()
  def single(vector, opts \\ []) when is_list(vector) do
    config = %{vector: vector}

    config
    |> maybe_add_certainty(Keyword.get(opts, :certainty))
    |> maybe_add_distance(Keyword.get(opts, :distance))
    |> maybe_add_target_vectors(Keyword.get(opts, :target_vectors))
  end

  @doc """
  Create a query with a list of vectors.

  Used for multi-vector search patterns where you want to query
  with multiple vectors over a single vector space. The server
  may average or otherwise combine these vectors.

  ## Parameters

  - `vectors` - A list of vectors (each vector is a list of floats)

  ## Options

  - `:certainty` - Minimum certainty threshold
  - `:distance` - Maximum distance threshold

  ## Examples

      vectors = [vec1, vec2, vec3]
      NearVector.list_of_vectors(vectors)

      # With certainty
      NearVector.list_of_vectors(vectors, certainty: 0.7)
  """
  @spec list_of_vectors([vector()], keyword()) :: map()
  def list_of_vectors(vectors, opts \\ []) when is_list(vectors) do
    config = %{vectors: vectors}

    config
    |> maybe_add_certainty(Keyword.get(opts, :certainty))
    |> maybe_add_distance(Keyword.get(opts, :distance))
    |> maybe_add_target_vectors(Keyword.get(opts, :target_vectors))
  end

  @doc """
  Create a query with different vectors for different target vector spaces.

  Used with collections that have multiple named vectors. Allows you to
  provide a different query vector for each named vector space.

  ## Parameters

  - `targets` - A map of named vector names to their respective query vectors

  ## Options

  - `:certainty` - Minimum certainty threshold (applied to all targets)
  - `:distance` - Maximum distance threshold (applied to all targets)
  - `:combination_method` - How to combine results (`:sum`, `:average`, `:minimum`, `:manual`)

  ## Examples

      NearVector.per_target(%{
        "title_vector" => title_embedding,
        "content_vector" => content_embedding
      })

      NearVector.per_target(%{
        "image" => image_vec,
        "text" => text_vec
      }, combination_method: :average)
  """
  @spec per_target(target_vectors(), keyword()) :: map()
  def per_target(targets, opts \\ []) when is_map(targets) do
    config = %{targets: targets}

    config
    |> maybe_add_certainty(Keyword.get(opts, :certainty))
    |> maybe_add_distance(Keyword.get(opts, :distance))
    |> maybe_add_combination_method(Keyword.get(opts, :combination_method))
  end

  @doc """
  Create a weighted multi-target vector query.

  Allows specifying weights for each target vector space.

  ## Parameters

  - `weighted_targets` - A list of tuples: `{vector_name, vector, weight}`

  ## Options

  - `:certainty` - Minimum certainty threshold
  - `:distance` - Maximum distance threshold

  ## Examples

      NearVector.weighted_targets([
        {"title_vector", title_vec, 0.7},
        {"content_vector", content_vec, 0.3}
      ])
  """
  @spec weighted_targets([{String.t(), vector(), float()}], keyword()) :: map()
  def weighted_targets(weighted_list, opts \\ []) when is_list(weighted_list) do
    targets =
      Enum.into(weighted_list, %{}, fn {name, vector, weight} ->
        {name, %{vector: vector, weight: weight}}
      end)

    config = %{weighted_targets: targets}

    config
    |> maybe_add_certainty(Keyword.get(opts, :certainty))
    |> maybe_add_distance(Keyword.get(opts, :distance))
  end

  @doc """
  Convert a near vector configuration to API format.

  ## Examples

      config = NearVector.single([0.1, 0.2])
      NearVector.to_api(config)
      # => %{"vector" => [0.1, 0.2]}
  """
  @spec to_api(map()) :: map()
  def to_api(%{vector: vector} = config) do
    result = %{"vector" => vector}

    result
    |> add_if_present(config, :certainty, "certainty")
    |> add_if_present(config, :distance, "distance")
    |> add_if_present(config, :target_vectors, "targetVectors")
  end

  def to_api(%{vectors: vectors} = config) do
    result = %{"vectors" => vectors}

    result
    |> add_if_present(config, :certainty, "certainty")
    |> add_if_present(config, :distance, "distance")
    |> add_if_present(config, :target_vectors, "targetVectors")
  end

  def to_api(%{targets: targets} = config) do
    # Convert to API format for per-target vectors
    target_vectors =
      Enum.into(targets, %{}, fn {name, vector} ->
        {name, vector}
      end)

    result = %{"targetVectors" => target_vectors}

    result
    |> add_if_present(config, :certainty, "certainty")
    |> add_if_present(config, :distance, "distance")
    |> add_if_present(config, :combination_method, "combinationMethod")
  end

  def to_api(%{weighted_targets: targets} = config) do
    # Convert weighted targets to API format
    api_targets =
      Enum.map(targets, fn {name, %{vector: vector, weight: weight}} ->
        %{
          "targetVector" => name,
          "vector" => vector,
          "weight" => weight
        }
      end)

    result = %{"vectorPerTarget" => api_targets}

    result
    |> add_if_present(config, :certainty, "certainty")
    |> add_if_present(config, :distance, "distance")
  end

  # Private helpers

  defp maybe_add_certainty(config, nil), do: config
  defp maybe_add_certainty(config, certainty), do: Map.put(config, :certainty, certainty)

  defp maybe_add_distance(config, nil), do: config
  defp maybe_add_distance(config, distance), do: Map.put(config, :distance, distance)

  defp maybe_add_target_vectors(config, nil), do: config

  defp maybe_add_target_vectors(config, targets) when is_list(targets) do
    Map.put(config, :target_vectors, targets)
  end

  defp maybe_add_combination_method(config, nil), do: config

  defp maybe_add_combination_method(config, method) when is_atom(method) do
    Map.put(config, :combination_method, combination_method_to_string(method))
  end

  defp maybe_add_combination_method(config, method) when is_binary(method) do
    Map.put(config, :combination_method, method)
  end

  defp combination_method_to_string(:sum), do: "sum"
  defp combination_method_to_string(:average), do: "average"
  defp combination_method_to_string(:minimum), do: "minimum"
  defp combination_method_to_string(:manual), do: "manual"
  defp combination_method_to_string(:relative_score), do: "relativeScore"

  defp add_if_present(result, config, key, api_key) do
    case Map.get(config, key) do
      nil -> result
      value -> Map.put(result, api_key, value)
    end
  end
end
