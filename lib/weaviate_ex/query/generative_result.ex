defmodule WeaviateEx.Query.GenerativeResult do
  @moduledoc """
  Result structure for generative search queries.

  This struct holds the results from a combined search + generation query,
  including both the matched objects and their generated content.

  ## Fields

    - `:objects` - List of matched objects with their properties
    - `:generated` - The grouped generation result (if grouped_task was used)
    - `:generated_per_object` - List of per-object generation results (if single_prompt was used)
    - `:metadata` - Optional metadata about the generative operation (token usage, etc.)

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

  defstruct [:objects, :generated, :generated_per_object, :metadata]

  @type t :: %__MODULE__{
          objects: [object()],
          generated: String.t() | nil,
          generated_per_object: [String.t()],
          metadata: metadata() | nil
        }

  @type object :: %{
          optional(:uuid) => String.t(),
          optional(:properties) => map(),
          optional(:vector) => [float()],
          optional(:distance) => float(),
          optional(:certainty) => float(),
          optional(:score) => float()
        }

  @type metadata :: %{
          optional(:usage) => usage_metadata(),
          optional(:debug) => debug_metadata()
        }

  @type usage_metadata :: %{
          optional(:prompt_tokens) => integer(),
          optional(:completion_tokens) => integer(),
          optional(:total_tokens) => integer()
        }

  @type debug_metadata :: %{
          optional(:full_prompt) => String.t()
        }

  @doc """
  Creates a new empty GenerativeResult.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      objects: [],
      generated: nil,
      generated_per_object: [],
      metadata: nil
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
      generated_per_object: generated_per_object,
      metadata: nil
    }
  end

  @doc """
  Creates a GenerativeResult from a gRPC SearchReply.

  Parses the gRPC response structure to extract:
  - Objects from the search results
  - Grouped generative results (if present)
  - Per-object generative results (if present)
  - Optional metadata (usage, debug info)
  """
  @spec from_grpc_response(map()) :: t()
  def from_grpc_response(%{results: results} = reply) do
    objects = parse_grpc_objects(results)
    grouped = extract_grouped_result(reply)
    per_object = extract_single_results(results)

    %__MODULE__{
      objects: objects,
      generated: grouped,
      generated_per_object: per_object,
      metadata: nil
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

  # Private helpers for gRPC parsing

  defp parse_grpc_objects(nil), do: []

  defp parse_grpc_objects(results) when is_list(results) do
    Enum.map(results, &parse_grpc_object/1)
  end

  defp parse_grpc_object(%{properties: props, metadata: meta}) do
    object = %{}

    object =
      if meta do
        object
        |> maybe_put(:uuid, meta.id)
        |> maybe_put(:distance, if(meta.distance_present, do: meta.distance))
        |> maybe_put(:certainty, if(meta.certainty_present, do: meta.certainty))
        |> maybe_put(:score, if(meta.score_present, do: meta.score))
        |> maybe_put(:vector, parse_vector(meta))
      else
        object
      end

    if props && props.non_ref_props do
      Map.put(object, :properties, parse_properties(props.non_ref_props))
    else
      object
    end
  end

  defp parse_grpc_object(_), do: %{}

  defp parse_vector(%{vector_bytes: bytes}) when is_binary(bytes) and byte_size(bytes) > 0 do
    for <<f::float-little-32 <- bytes>>, do: f
  end

  defp parse_vector(%{vector: vector}) when is_list(vector) and length(vector) > 0, do: vector
  defp parse_vector(_), do: nil

  defp parse_properties(%{fields: fields}) when is_map(fields) do
    Map.new(fields, fn {key, value} ->
      {String.to_atom(key), parse_property_value(value)}
    end)
  end

  defp parse_properties(_), do: %{}

  defp parse_property_value(%{kind: {:text_value, value}}), do: value
  defp parse_property_value(%{kind: {:int_value, value}}), do: value
  defp parse_property_value(%{kind: {:number_value, value}}), do: value
  defp parse_property_value(%{kind: {:bool_value, value}}), do: value

  defp parse_property_value(%{kind: {:list_value, %{values: values}}}),
    do: Enum.map(values, &parse_property_value/1)

  defp parse_property_value(%{kind: {:object_value, obj}}), do: parse_properties(obj)
  defp parse_property_value(_), do: nil

  defp extract_grouped_result(%{generative_grouped_results: %{values: [first | _]}}) do
    first.result
  end

  defp extract_grouped_result(%{generative_grouped_result: result})
       when is_binary(result) and result != "" do
    result
  end

  defp extract_grouped_result(_), do: nil

  defp extract_single_results(nil), do: []

  defp extract_single_results(results) when is_list(results) do
    results
    |> Enum.map(&extract_single_result/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_single_result(%{generative: %{values: [first | _]}}) do
    first.result
  end

  defp extract_single_result(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
