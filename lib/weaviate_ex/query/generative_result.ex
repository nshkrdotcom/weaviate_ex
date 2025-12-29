defmodule WeaviateEx.Query.GenerativeResult do
  @moduledoc """
  Result structure for generative search queries.

  This struct holds the results from a combined search + generation query,
  including both the matched objects and their generated content.

  ## Fields

    - `:objects` - List of matched objects with their properties
    - `:generated` - The grouped generation result (if grouped_task was used)
    - `:generated_per_object` - List of per-object generation results (if single_prompt was used)

  ## Examples

      # Result with per-object generation
      %GenerativeResult{
        objects: [
          %{uuid: "uuid-1", properties: %{title: "Article 1"}},
          %{uuid: "uuid-2", properties: %{title: "Article 2"}}
        ],
        generated: nil,
        generated_per_object: ["Summary of Article 1", "Summary of Article 2"]
      }

      # Result with grouped generation
      %GenerativeResult{
        objects: [%{uuid: "uuid-1", properties: %{title: "Article 1"}}],
        generated: "Overall summary of all articles",
        generated_per_object: []
      }
  """

  defstruct [:objects, :generated, :generated_per_object]

  @type t :: %__MODULE__{
          objects: [object()],
          generated: String.t() | nil,
          generated_per_object: [String.t()]
        }

  @type object :: %{
          optional(:uuid) => String.t(),
          optional(:properties) => map(),
          optional(:vector) => [float()],
          optional(:distance) => float(),
          optional(:certainty) => float(),
          optional(:score) => float()
        }

  @doc """
  Creates a new empty GenerativeResult.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      objects: [],
      generated: nil,
      generated_per_object: []
    }
  end

  @doc """
  Creates a GenerativeResult from parsed objects.
  """
  @spec new([object()], String.t() | nil, [String.t()]) :: t()
  def new(objects, generated, generated_per_object) do
    %__MODULE__{
      objects: objects,
      generated: generated,
      generated_per_object: generated_per_object
    }
  end

  @doc """
  Checks if the result has any objects.
  """
  @spec has_objects?(t()) :: boolean()
  def has_objects?(%__MODULE__{objects: objects}) do
    length(objects) > 0
  end

  @doc """
  Checks if the result has a grouped generation.
  """
  @spec has_grouped_result?(t()) :: boolean()
  def has_grouped_result?(%__MODULE__{generated: nil}), do: false
  def has_grouped_result?(%__MODULE__{generated: _}), do: true

  @doc """
  Checks if the result has per-object generations.
  """
  @spec has_single_results?(t()) :: boolean()
  def has_single_results?(%__MODULE__{generated_per_object: results}) do
    length(results) > 0
  end

  @doc """
  Returns the count of objects in the result.
  """
  @spec object_count(t()) :: non_neg_integer()
  def object_count(%__MODULE__{objects: objects}) do
    length(objects)
  end
end
