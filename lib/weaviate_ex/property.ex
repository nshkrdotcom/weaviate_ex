defmodule WeaviateEx.Property do
  @moduledoc """
  Property builder for collection schemas.

  Provides a fluent API for defining collection properties with proper
  data types, indexing options, and nested object support.

  ## Examples

      # Simple properties
      properties = [
        Property.text("title"),
        Property.text("content", tokenization: :word),
        Property.int("views"),
        Property.boolean("published"),
        Property.date("created_at")
      ]

      # Nested object
      author = Property.object("author", [
        Property.text("name"),
        Property.text("email"),
        Property.object("address", [
          Property.text("city"),
          Property.text("country")
        ])
      ])

      # Cross-reference
      ref = Property.reference("hasAuthor", "Author")
  """

  alias WeaviateEx.Types.DataType

  @type t :: map()
  @type opts :: keyword()

  @doc """
  Create a new property definition.

  ## Options

    - `:description` - Property description
    - `:index_filterable` - Enable filtering on this property
    - `:index_searchable` - Enable full-text search
    - `:index_inverted` - Include in inverted index
    - `:tokenization` - Tokenization strategy (:word, :whitespace, :field, etc.)
    - `:skip_vectorization` - Don't include in vectorization
    - `:vectorize_property_name` - Include property name in vector
    - `:nested_properties` - For object/object[] types

  ## Examples

      Property.new("title", :text)
      Property.new("title", :text, tokenization: :word, index_searchable: true)
  """
  @spec new(String.t(), atom() | String.t(), opts()) :: t()
  def new(name, data_type, opts \\ []) do
    %{
      "name" => name,
      "dataType" => [normalize_data_type(data_type)]
    }
    |> maybe_put("description", Keyword.get(opts, :description))
    |> maybe_put("indexFilterable", Keyword.get(opts, :index_filterable))
    |> maybe_put("indexSearchable", Keyword.get(opts, :index_searchable))
    |> maybe_put("indexInverted", Keyword.get(opts, :index_inverted))
    |> maybe_put("tokenization", normalize_tokenization(Keyword.get(opts, :tokenization)))
    |> maybe_add_nested_properties(Keyword.get(opts, :nested_properties))
    |> maybe_add_module_config(opts)
  end

  # Convenience constructors for each data type

  @doc "Create a text property"
  @spec text(String.t(), opts()) :: t()
  def text(name, opts \\ []), do: new(name, :text, opts)

  @doc "Create a text array property"
  @spec text_array(String.t(), opts()) :: t()
  def text_array(name, opts \\ []), do: new(name, :text_array, opts)

  @doc "Create an integer property"
  @spec int(String.t(), opts()) :: t()
  def int(name, opts \\ []), do: new(name, :int, opts)

  @doc "Create an integer array property"
  @spec int_array(String.t(), opts()) :: t()
  def int_array(name, opts \\ []), do: new(name, :int_array, opts)

  @doc "Create a number (float) property"
  @spec number(String.t(), opts()) :: t()
  def number(name, opts \\ []), do: new(name, :number, opts)

  @doc "Create a number array property"
  @spec number_array(String.t(), opts()) :: t()
  def number_array(name, opts \\ []), do: new(name, :number_array, opts)

  @doc "Create a boolean property"
  @spec boolean(String.t(), opts()) :: t()
  def boolean(name, opts \\ []), do: new(name, :boolean, opts)

  @doc "Create a boolean array property"
  @spec boolean_array(String.t(), opts()) :: t()
  def boolean_array(name, opts \\ []), do: new(name, :boolean_array, opts)

  @doc "Create a date property"
  @spec date(String.t(), opts()) :: t()
  def date(name, opts \\ []), do: new(name, :date, opts)

  @doc "Create a date array property"
  @spec date_array(String.t(), opts()) :: t()
  def date_array(name, opts \\ []), do: new(name, :date_array, opts)

  @doc "Create a UUID property"
  @spec uuid(String.t(), opts()) :: t()
  def uuid(name, opts \\ []), do: new(name, :uuid, opts)

  @doc "Create a UUID array property"
  @spec uuid_array(String.t(), opts()) :: t()
  def uuid_array(name, opts \\ []), do: new(name, :uuid_array, opts)

  @doc """
  Create a blob property.

  Blobs are not filterable by default.
  """
  @spec blob(String.t(), opts()) :: t()
  def blob(name, opts \\ []) do
    new(name, :blob, Keyword.put(opts, :index_filterable, false))
  end

  @doc "Create a geo coordinates property"
  @spec geo_coordinates(String.t(), opts()) :: t()
  def geo_coordinates(name, opts \\ []), do: new(name, :geo_coordinates, opts)

  @doc "Create a phone number property"
  @spec phone_number(String.t(), opts()) :: t()
  def phone_number(name, opts \\ []), do: new(name, :phone_number, opts)

  @doc """
  Create a nested object property.

  ## Examples

      Property.object("author", [
        Property.text("name"),
        Property.text("email"),
        Property.object("address", [
          Property.text("city"),
          Property.text("country")
        ])
      ])
  """
  @spec object(String.t(), [t()], opts()) :: t()
  def object(name, nested_properties, opts \\ []) do
    new(name, :object, Keyword.put(opts, :nested_properties, nested_properties))
  end

  @doc """
  Create a nested object array property.

  ## Examples

      Property.object_array("authors", [
        Property.text("name"),
        Property.text("email")
      ])
  """
  @spec object_array(String.t(), [t()], opts()) :: t()
  def object_array(name, nested_properties, opts \\ []) do
    new(name, :object_array, Keyword.put(opts, :nested_properties, nested_properties))
  end

  @doc """
  Create a cross-reference property.

  Supports both single-target and multi-target references.

  ## Examples

      # Single target reference
      Property.reference("hasAuthor", "Author")
      Property.reference("hasCategories", "Category", description: "Article categories")

      # Multi-target reference (can point to any of the listed collections)
      Property.reference("hasContent", ["Article", "BlogPost", "Video"])
  """
  @spec reference(String.t(), String.t() | [String.t()], opts()) :: t()
  def reference(name, target_collection, opts \\ [])

  def reference(name, target_collections, opts) when is_list(target_collections) do
    %{
      "name" => name,
      "dataType" => target_collections
    }
    |> maybe_put("description", Keyword.get(opts, :description))
  end

  def reference(name, target_collection, opts) when is_binary(target_collection) do
    %{
      "name" => name,
      "dataType" => [target_collection]
    }
    |> maybe_put("description", Keyword.get(opts, :description))
  end

  @doc """
  Create a multi-target cross-reference property.

  Alias for `reference/3` with a list of target collections.

  ## Examples

      Property.multi_reference("hasContent", ["Article", "BlogPost", "Video"])
  """
  @spec multi_reference(String.t(), [String.t()], opts()) :: t()
  def multi_reference(name, target_collections, opts \\ []) when is_list(target_collections) do
    reference(name, target_collections, opts)
  end

  # Private helpers

  defp normalize_data_type(type) when is_atom(type) do
    DataType.to_string(type)
  end

  defp normalize_data_type(type) when is_binary(type), do: type

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

  defp maybe_add_nested_properties(prop, nil), do: prop

  defp maybe_add_nested_properties(prop, nested) when is_list(nested) do
    Map.put(prop, "nestedProperties", nested)
  end

  defp maybe_add_module_config(prop, opts) do
    skip_vectorization = Keyword.get(opts, :skip_vectorization)
    vectorize_property_name = Keyword.get(opts, :vectorize_property_name)

    case {skip_vectorization, vectorize_property_name} do
      {nil, nil} ->
        prop

      _ ->
        module_config =
          %{}
          |> maybe_put("skip", skip_vectorization)
          |> maybe_put("vectorizePropertyName", vectorize_property_name)

        Map.put(prop, "moduleConfig", module_config)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
