defmodule WeaviateEx.Query.Move do
  @moduledoc """
  Move configuration for near_text queries.

  Move operations allow you to shift the search vector towards or away from
  specified concepts or objects. This is useful for semantic search refinement.

  ## Examples

      # Move towards concepts
      move_to = Move.to(0.5, concepts: ["summer", "beach"])

      # Move away from objects
      move_away = Move.to(0.25, objects: ["uuid-to-avoid"])

      # Use in near_text query
      Query.get("Article")
      |> Query.near_text("fashion",
        move_to: move_to,
        move_away: move_away
      )
  """

  @type t :: %__MODULE__{
          force: float(),
          concepts: [String.t()] | nil,
          objects: [String.t()] | nil
        }

  defstruct [:force, :concepts, :objects]

  @doc """
  Create a move configuration.

  ## Parameters

    - `force` - The force of the movement (0.0 to 1.0)
    - `opts` - Options:
      - `:concepts` - List of concept strings to move towards/away from
      - `:objects` - List of object UUIDs to move towards/away from

  ## Examples

      Move.to(0.5, concepts: ["summer", "beach"])
      Move.to(0.25, objects: ["uuid-1", "uuid-2"])
      Move.to(0.3, concepts: ["summer"], objects: ["uuid-1"])
  """
  @spec to(float(), keyword()) :: t()
  def to(force, opts \\ []) when is_number(force) do
    %__MODULE__{
      force: force,
      concepts: Keyword.get(opts, :concepts),
      objects: Keyword.get(opts, :objects)
    }
  end

  @doc """
  Convert move configuration to GraphQL format.

  ## Examples

      move = Move.to(0.5, concepts: ["summer"])
      Move.to_graphql(move)
      # => "{force: 0.5, concepts: [\\\"summer\\\"]}"
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = move) do
    parts = ["force: #{move.force}"]

    parts =
      if move.concepts do
        concepts_str = Enum.map_join(move.concepts, ", ", &~s("#{&1}"))
        parts ++ ["concepts: [#{concepts_str}]"]
      else
        parts
      end

    parts =
      if move.objects do
        objects_str = Enum.map_join(move.objects, ", ", &~s("#{&1}"))
        parts ++ ["objects: [#{objects_str}]"]
      else
        parts
      end

    "{#{Enum.join(parts, ", ")}}"
  end
end
