defmodule WeaviateEx.Generative.Result do
  @moduledoc """
  Typed result structures for generative queries.

  These structs provide structured access to generation results including:
  - Generated text
  - Provider-specific metadata (tokens, latency)
  - Debug information (full prompt)
  - Error handling

  ## Examples

      # Parse a generative response
      result = Result.ResponseParser.parse(response, "Article")

      # Access single prompt results
      for obj <- result.objects do
        IO.puts(obj.generative.text)
        IO.inspect(obj.generative.metadata)
      end

      # Access grouped task result
      IO.puts(result.generative.text)
  """

  # Single prompt result
  defmodule Single do
    @moduledoc "Result for single prompt generation per object"

    defstruct [:text, :metadata, :debug, :error]

    @type t :: %__MODULE__{
            text: String.t() | nil,
            metadata: map() | nil,
            debug: debug_info() | nil,
            error: String.t() | nil
          }

    @type debug_info :: %{
            full_prompt: String.t()
          }
  end

  # Grouped task result
  defmodule Grouped do
    @moduledoc "Result for grouped task generation"

    defstruct [:text, :metadata, :error]

    @type t :: %__MODULE__{
            text: String.t() | nil,
            metadata: map() | nil,
            error: String.t() | nil
          }
  end

  # Object with generative result
  defmodule GenerativeObject do
    @moduledoc "Object with associated generative result"

    defstruct [:uuid, :properties, :references, :vector, :collection, :generative]

    @type t :: %__MODULE__{
            uuid: String.t() | nil,
            properties: map(),
            references: map() | nil,
            vector: map() | nil,
            collection: String.t() | nil,
            generative: Single.t() | nil
          }
  end

  # Full return type
  defmodule GenerativeReturn do
    @moduledoc "Full return type for generative queries"

    defstruct [:objects, :generative]

    @type t :: %__MODULE__{
            objects: [GenerativeObject.t()],
            generative: Grouped.t() | nil
          }
  end

  # Response parser
  defmodule ResponseParser do
    @moduledoc "Parser for generative API responses"

    alias WeaviateEx.Generative.Result

    @doc """
    Parse a generative response into typed structs.

    ## Parameters

      - `response` - The raw API response map
      - `collection` - The collection name to extract results from

    ## Returns

      A `GenerativeReturn` struct with parsed objects and grouped result
    """
    @spec parse(map(), String.t()) :: Result.GenerativeReturn.t()
    def parse(%{"data" => %{"Get" => get}}, collection) do
      raw_objects = Map.get(get, collection, [])
      parsed_objects = Enum.map(raw_objects, &parse_object/1)

      # Check for grouped result in the raw objects
      grouped = extract_grouped_from_raw(raw_objects)

      %Result.GenerativeReturn{
        objects: parsed_objects,
        generative: grouped
      }
    end

    def parse(_, _collection) do
      %Result.GenerativeReturn{
        objects: [],
        generative: nil
      }
    end

    defp parse_object(obj) do
      additional = Map.get(obj, "_additional", %{})
      generate = Map.get(additional, "generate", %{})
      properties = Map.drop(obj, ["_additional"])

      %Result.GenerativeObject{
        uuid: additional["id"],
        properties: properties,
        collection: nil,
        generative: parse_single_result(generate)
      }
    end

    defp parse_single_result(nil), do: nil
    defp parse_single_result(%{} = gen) when gen == %{}, do: nil

    defp parse_single_result(%{"singleResult" => text} = gen) do
      %Result.Single{
        text: text,
        metadata: gen["metadata"],
        debug: parse_debug(gen["debug"]),
        error: gen["error"]
      }
    end

    defp parse_single_result(%{"groupedResult" => _text} = gen) do
      # For grouped results, we store the grouped text in the Single struct
      # The actual grouped result is extracted separately
      %Result.Single{
        text: nil,
        metadata: gen["metadata"],
        debug: parse_debug(gen["debug"]),
        error: gen["error"]
      }
    end

    defp parse_single_result(gen) do
      %Result.Single{
        text: gen["singleResult"],
        metadata: gen["metadata"],
        debug: parse_debug(gen["debug"]),
        error: gen["error"]
      }
    end

    defp parse_debug(nil), do: nil

    defp parse_debug(%{"fullPrompt" => prompt}) do
      %{full_prompt: prompt}
    end

    defp parse_debug(_), do: nil

    defp extract_grouped_from_raw([]), do: nil

    defp extract_grouped_from_raw(raw_objects) do
      Enum.find_value(raw_objects, fn obj ->
        case get_in(obj, ["_additional", "generate", "groupedResult"]) do
          nil ->
            nil

          text ->
            %Result.Grouped{
              text: text,
              metadata: get_in(obj, ["_additional", "generate", "metadata"]),
              error: get_in(obj, ["_additional", "generate", "error"])
            }
        end
      end)
    end
  end
end
