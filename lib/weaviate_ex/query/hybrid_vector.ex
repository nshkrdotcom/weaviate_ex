defmodule WeaviateEx.Query.HybridVector do
  @moduledoc """
  Vector sub-search configuration for hybrid queries.

  In hybrid queries, the vector component can be configured using either
  near_text (text-to-vector) or near_vector (explicit vector) searches,
  with full support for Move operations and target vectors.

  ## Examples

      # Text-based vector search with Move
      hv = HybridVector.near_text("machine learning",
        move_to: Move.to(0.5, concepts: ["AI"]),
        move_away_from: Move.to(0.3, concepts: ["biology"])
      )

      Query.hybrid(query, "search term", vector: hv, alpha: 0.7)

      # Vector-based search with target vectors
      hv = HybridVector.near_vector(embedding, target_vectors: "content_vector")

      Query.hybrid(query, "search term", vector: hv, alpha: 0.5)
  """

  alias WeaviateEx.Query.Move
  alias WeaviateEx.Query.TargetVectors

  @type search_type :: :near_text | :near_vector

  @type t :: %__MODULE__{
          type: search_type(),
          query: String.t() | nil,
          text: String.t() | nil,
          vector: [float()] | nil,
          certainty: float() | nil,
          distance: float() | nil,
          move_to: Move.t() | nil,
          move_away: Move.t() | nil,
          move_away_from: Move.t() | nil,
          target_vectors: TargetVectors.Config.t() | String.t() | [String.t()] | nil
        }

  defstruct [
    :type,
    :query,
    :text,
    :vector,
    :certainty,
    :distance,
    :move_to,
    :move_away,
    :move_away_from,
    :target_vectors
  ]

  @doc """
  Create a text-based vector sub-search for hybrid queries.

  ## Options

    * `:certainty` - Minimum certainty threshold
    * `:distance` - Maximum distance threshold
    * `:move_to` - Move towards concepts/objects (use `Move.to/2`)
    * `:move_away_from` - Move away from concepts/objects (use `Move.to/2`)
    * `:move_away` - Alias for `:move_away_from` (deprecated)
    * `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      HybridVector.near_text("machine learning", certainty: 0.8)

      HybridVector.near_text("ML",
        move_to: Move.to(0.5, concepts: ["artificial intelligence"]),
        target_vectors: "content_vector"
      )
  """
  @spec near_text(String.t(), keyword()) :: t()
  def near_text(query, opts \\ []) when is_binary(query) do
    %__MODULE__{
      type: :near_text,
      query: query,
      text: query,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance),
      move_to: normalize_move(Keyword.get(opts, :move_to)),
      move_away: normalize_move(Keyword.get(opts, :move_away)),
      move_away_from: normalize_move(Keyword.get(opts, :move_away_from)),
      target_vectors: Keyword.get(opts, :target_vectors)
    }
  end

  @doc """
  Create a vector-based sub-search for hybrid queries.

  ## Options

    * `:certainty` - Minimum certainty threshold
    * `:distance` - Maximum distance threshold
    * `:target_vectors` - Target vectors for multi-vector collections

  ## Examples

      HybridVector.near_vector([0.1, 0.2, 0.3], distance: 0.2)

      HybridVector.near_vector(embedding, target_vectors: ["vec1", "vec2"])
  """
  @spec near_vector([float()], keyword()) :: t()
  def near_vector(vector, opts \\ []) when is_list(vector) do
    %__MODULE__{
      type: :near_vector,
      vector: vector,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance),
      target_vectors: Keyword.get(opts, :target_vectors)
    }
  end

  @doc """
  Convert to gRPC format for query execution.
  """
  @spec to_grpc(t()) :: map()
  def to_grpc(%__MODULE__{type: :near_text} = hv) do
    move_away = hv.move_away_from || hv.move_away

    near_text =
      %{
        query: hv.query || hv.text,
        certainty: hv.certainty,
        distance: hv.distance,
        move_to: move_to_grpc(hv.move_to),
        move_away_from: move_to_grpc(move_away)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    base = %{near_text: near_text}
    add_target_vectors(base, hv.target_vectors)
  end

  def to_grpc(%__MODULE__{type: :near_vector} = hv) do
    near_vector =
      %{
        vector: hv.vector,
        certainty: hv.certainty,
        distance: hv.distance
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    base = %{near_vector: near_vector}
    add_target_vectors(base, hv.target_vectors)
  end

  @doc """
  Convert to GraphQL format.
  """
  @spec to_graphql(t()) :: map() | String.t()
  def to_graphql(%__MODULE__{type: :near_text} = hv) do
    move_away = hv.move_away_from || hv.move_away

    near_text =
      %{
        "concepts" => [hv.query || hv.text],
        "certainty" => hv.certainty,
        "distance" => hv.distance,
        "moveTo" => move_to_graphql_map(hv.move_to),
        "moveAwayFrom" => move_to_graphql_map(move_away),
        "targetVectors" => format_target_vectors_graphql(hv.target_vectors)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{"nearText" => near_text}
  end

  def to_graphql(%__MODULE__{type: :near_vector} = hv) do
    near_vector =
      %{
        "vector" => hv.vector,
        "certainty" => hv.certainty,
        "distance" => hv.distance,
        "targetVectors" => format_target_vectors_graphql(hv.target_vectors)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{"nearVector" => near_vector}
  end

  @doc """
  Convert hybrid vector configuration to GraphQL string format (legacy).

  ## Examples

      sub = HybridVector.near_text("espresso brewing")
      HybridVector.to_graphql_string(sub)
  """
  @spec to_graphql_string(t()) :: String.t()
  def to_graphql_string(%__MODULE__{type: :near_text} = config) do
    parts = [~s(concepts: ["#{config.query || config.text}"])]

    parts =
      if config.move_to do
        parts ++ ["moveTo: #{Move.to_graphql(config.move_to)}"]
      else
        parts
      end

    move_away = config.move_away_from || config.move_away

    parts =
      if move_away do
        parts ++ ["moveAwayFrom: #{Move.to_graphql(move_away)}"]
      else
        parts
      end

    parts = add_common_parts(parts, config)

    "nearText: {#{Enum.join(parts, ", ")}}"
  end

  def to_graphql_string(%__MODULE__{type: :near_vector} = config) do
    vector_str = "[#{Enum.join(config.vector, ", ")}]"
    parts = ["vector: #{vector_str}"]

    parts = add_common_parts(parts, config)

    "nearVector: {#{Enum.join(parts, ", ")}}"
  end

  # Private helpers

  defp normalize_move(nil), do: nil
  defp normalize_move(%Move{} = move), do: move
  defp normalize_move(map) when is_map(map), do: struct(Move, map)

  defp move_to_grpc(nil), do: nil

  defp move_to_grpc(%Move{} = move) do
    %{
      force: move.force,
      concepts: move.concepts,
      objects: move.objects
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp move_to_graphql_map(nil), do: nil

  defp move_to_graphql_map(%Move{} = move) do
    %{
      "force" => move.force,
      "concepts" => move.concepts,
      "objects" => move.objects
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp add_target_vectors(map, nil), do: map

  defp add_target_vectors(map, tv) do
    Map.put(map, :target_vectors, TargetVectors.to_grpc(tv))
  end

  defp format_target_vectors_graphql(nil), do: nil
  defp format_target_vectors_graphql(tv) when is_binary(tv), do: [tv]
  defp format_target_vectors_graphql(tv) when is_list(tv), do: tv

  defp format_target_vectors_graphql(%TargetVectors.Config{vectors: vectors}), do: vectors

  defp add_common_parts(parts, config) do
    parts =
      if config.certainty do
        parts ++ ["certainty: #{config.certainty}"]
      else
        parts
      end

    if config.distance do
      parts ++ ["distance: #{config.distance}"]
    else
      parts
    end
  end
end
