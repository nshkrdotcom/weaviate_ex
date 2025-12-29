defmodule WeaviateEx.Property.Nested do
  @moduledoc """
  Nested property definition for object and object_array data types.

  Provides a typed struct for defining nested properties within object-type
  properties. Supports recursive nesting for complex data structures.

  ## Examples

      # Simple nested property
      Nested.new(name: "author", data_type: :text)

      # Nested object with sub-properties
      Nested.new(
        name: "metadata",
        data_type: :object,
        nested_properties: [
          Nested.new(name: "author", data_type: :text),
          Nested.new(name: "tags", data_type: :text_array)
        ]
      )

      # Deeply nested structure
      Nested.new(
        name: "metadata",
        data_type: :object,
        nested_properties: [
          Nested.new(
            name: "stats",
            data_type: :object,
            nested_properties: [
              Nested.new(name: "views", data_type: :int),
              Nested.new(name: "likes", data_type: :int)
            ]
          )
        ]
      )
  """

  alias WeaviateEx.Types.DataType

  defstruct [
    :name,
    :data_type,
    :nested_properties,
    :description,
    :indexable,
    :tokenization
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          data_type: DataType.t(),
          nested_properties: [t()] | nil,
          description: String.t() | nil,
          indexable: boolean() | nil,
          tokenization: atom() | nil
        }

  @doc """
  Creates a new nested property definition.

  ## Required Options

    - `:name` - Property name (required)
    - `:data_type` - Data type atom (required)

  ## Optional Options

    - `:nested_properties` - List of child Nested structs (for object types)
    - `:description` - Property description
    - `:indexable` - Whether property is filterable/searchable
    - `:tokenization` - Tokenization strategy (:word, :whitespace, :field, etc.)

  ## Examples

      Nested.new(name: "title", data_type: :text)
      Nested.new(name: "metadata", data_type: :object, nested_properties: [...])
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    data_type = Keyword.fetch!(opts, :data_type)

    %__MODULE__{
      name: name,
      data_type: data_type,
      nested_properties: Keyword.get(opts, :nested_properties),
      description: Keyword.get(opts, :description),
      indexable: Keyword.get(opts, :indexable),
      tokenization: Keyword.get(opts, :tokenization)
    }
  end

  @doc """
  Converts a Nested struct to Weaviate API format.

  ## Examples

      nested = Nested.new(name: "title", data_type: :text)
      Nested.to_api(nested)
      # => %{"name" => "title", "dataType" => ["text"]}
  """
  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = nested) do
    %{
      "name" => nested.name,
      "dataType" => [DataType.to_string(nested.data_type)]
    }
    |> maybe_put("description", nested.description)
    |> maybe_add_indexable(nested.indexable)
    |> maybe_put("tokenization", normalize_tokenization(nested.tokenization))
    |> maybe_add_nested_properties(nested.nested_properties)
  end

  @doc """
  Parses a Weaviate API response into a Nested struct.

  ## Examples

      api = %{"name" => "title", "dataType" => ["text"]}
      Nested.from_api(api)
      # => %Nested{name: "title", data_type: :text}
  """
  @spec from_api(map()) :: t()
  def from_api(api) when is_map(api) do
    data_type = parse_data_type(api["dataType"])
    nested_properties = parse_nested_properties(api["nestedProperties"])
    indexable = parse_indexable(api)
    tokenization = parse_tokenization(api["tokenization"])

    %__MODULE__{
      name: api["name"],
      data_type: data_type,
      nested_properties: nested_properties,
      description: api["description"],
      indexable: indexable,
      tokenization: tokenization
    }
  end

  @doc """
  Validates a Nested struct.

  Returns `true` if:
    - Object types have nested_properties defined
    - Non-object types do NOT have nested_properties

  ## Examples

      nested = Nested.new(name: "title", data_type: :text)
      Nested.valid?(nested)
      # => true

      nested = Nested.new(name: "data", data_type: :object)
      Nested.valid?(nested)
      # => false (object must have nested_properties)
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = nested) do
    cond do
      object_type?(nested) ->
        # Object types must have nested_properties
        is_list(nested.nested_properties) and length(nested.nested_properties) > 0

      is_list(nested.nested_properties) and length(nested.nested_properties) > 0 ->
        # Non-object types should not have nested_properties
        false

      true ->
        true
    end
  end

  @doc """
  Checks if the nested property is an object type.

  ## Examples

      Nested.object_type?(%Nested{data_type: :object})
      # => true

      Nested.object_type?(%Nested{data_type: :text})
      # => false
  """
  @spec object_type?(t()) :: boolean()
  def object_type?(%__MODULE__{data_type: data_type}) do
    data_type in [:object, :object_array]
  end

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_indexable(map, nil), do: map

  defp maybe_add_indexable(map, true) do
    map
    |> Map.put("indexFilterable", true)
    |> Map.put("indexSearchable", true)
  end

  defp maybe_add_indexable(map, false) do
    map
    |> Map.put("indexFilterable", false)
    |> Map.put("indexSearchable", false)
  end

  defp maybe_add_nested_properties(map, nil), do: map

  defp maybe_add_nested_properties(map, nested) when is_list(nested) do
    Map.put(map, "nestedProperties", Enum.map(nested, &to_api/1))
  end

  defp normalize_tokenization(nil), do: nil
  defp normalize_tokenization(:word), do: "word"
  defp normalize_tokenization(:whitespace), do: "whitespace"
  defp normalize_tokenization(:lowercase), do: "lowercase"
  defp normalize_tokenization(:field), do: "field"
  defp normalize_tokenization(:gse), do: "gse"
  defp normalize_tokenization(:trigram), do: "trigram"
  defp normalize_tokenization(:kagome_ja), do: "kagome_ja"
  defp normalize_tokenization(:kagome_kr), do: "kagome_kr"
  defp normalize_tokenization(t) when is_binary(t), do: t

  defp parse_data_type(nil), do: nil
  defp parse_data_type([]), do: nil

  defp parse_data_type([type_str | _]) when is_binary(type_str) do
    case DataType.from_string(type_str) do
      {:ok, type} -> type
      {:error, _} -> nil
    end
  end

  defp parse_nested_properties(nil), do: nil
  defp parse_nested_properties([]), do: nil

  defp parse_nested_properties(props) when is_list(props) do
    Enum.map(props, &from_api/1)
  end

  defp parse_indexable(api) do
    filterable = api["indexFilterable"]
    searchable = api["indexSearchable"]

    cond do
      filterable == true or searchable == true -> true
      filterable == false and searchable == false -> false
      true -> nil
    end
  end

  defp parse_tokenization(nil), do: nil
  defp parse_tokenization("word"), do: :word
  defp parse_tokenization("whitespace"), do: :whitespace
  defp parse_tokenization("lowercase"), do: :lowercase
  defp parse_tokenization("field"), do: :field
  defp parse_tokenization("gse"), do: :gse
  defp parse_tokenization("trigram"), do: :trigram
  defp parse_tokenization("kagome_ja"), do: :kagome_ja
  defp parse_tokenization("kagome_kr"), do: :kagome_kr
  defp parse_tokenization(t), do: t
end
