defmodule WeaviateEx.Query.HybridVector do
  @moduledoc """
  Hybrid search vector sub-search configuration.

  Controls the vector component of hybrid search with
  near_text or near_vector sub-searches.

  ## Examples

      # Hybrid with near_text sub-search
      Query.hybrid("coffee",
        vector: HybridVector.near_text("espresso brewing",
          move_to: Move.to(0.5, concepts: ["barista"])
        ),
        alpha: 0.75
      )

      # Hybrid with explicit vector
      Query.hybrid("coffee",
        vector: HybridVector.near_vector([0.1, 0.2, ...], distance: 0.5),
        alpha: 0.75
      )
  """

  alias WeaviateEx.Query.Move

  @type t :: %__MODULE__{
          type: :near_text | :near_vector,
          text: String.t() | nil,
          vector: [float()] | nil,
          move_to: Move.t() | nil,
          move_away: Move.t() | nil,
          certainty: float() | nil,
          distance: float() | nil
        }

  defstruct [:type, :text, :vector, :move_to, :move_away, :certainty, :distance]

  @doc """
  Create a near_text sub-search for hybrid queries.

  ## Options

    - `:move_to` - Move configuration to shift towards concepts/objects
    - `:move_away` - Move configuration to shift away from concepts/objects
    - `:certainty` - Minimum certainty (0.0 to 1.0)
    - `:distance` - Maximum distance

  ## Examples

      HybridVector.near_text("espresso brewing")
      HybridVector.near_text("espresso brewing", move_to: Move.to(0.5, concepts: ["barista"]))
  """
  @spec near_text(String.t(), keyword()) :: t()
  def near_text(query, opts \\ []) when is_binary(query) do
    %__MODULE__{
      type: :near_text,
      text: query,
      move_to: Keyword.get(opts, :move_to),
      move_away: Keyword.get(opts, :move_away),
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  @doc """
  Create a near_vector sub-search for hybrid queries.

  ## Options

    - `:certainty` - Minimum certainty (0.0 to 1.0)
    - `:distance` - Maximum distance

  ## Examples

      HybridVector.near_vector([0.1, 0.2, 0.3])
      HybridVector.near_vector([0.1, 0.2, 0.3], distance: 0.5)
  """
  @spec near_vector([float()], keyword()) :: t()
  def near_vector(vector, opts \\ []) when is_list(vector) do
    %__MODULE__{
      type: :near_vector,
      vector: vector,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  @doc """
  Convert hybrid vector configuration to GraphQL format.

  ## Examples

      sub = HybridVector.near_text("espresso brewing")
      HybridVector.to_graphql(sub)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{type: :near_text} = config) do
    parts = [~s(concepts: ["#{config.text}"])]

    parts =
      if config.move_to do
        parts ++ ["moveTo: #{Move.to_graphql(config.move_to)}"]
      else
        parts
      end

    parts =
      if config.move_away do
        parts ++ ["moveAwayFrom: #{Move.to_graphql(config.move_away)}"]
      else
        parts
      end

    parts = add_common_parts(parts, config)

    "nearText: {#{Enum.join(parts, ", ")}}"
  end

  def to_graphql(%__MODULE__{type: :near_vector} = config) do
    vector_str = "[#{Enum.join(config.vector, ", ")}]"
    parts = ["vector: #{vector_str}"]

    parts = add_common_parts(parts, config)

    "nearVector: {#{Enum.join(parts, ", ")}}"
  end

  # Private helpers

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
