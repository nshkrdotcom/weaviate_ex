defmodule WeaviateEx.Query.QueryReference do
  @moduledoc """
  Query reference configuration for traversing cross-references.

  Allows specifying which properties to return from referenced objects,
  and supports nested reference traversal.

  ## Examples

      # Simple reference
      QueryReference.new("hasAuthor")

      # Reference with properties
      QueryReference.new("hasAuthor", return_properties: ["name", "bio"])

      # Multi-target reference
      QueryReference.multi_target("relatedTo", "Article",
        return_properties: ["title"]
      )

      # With metadata
      QueryReference.new("hasAuthor",
        return_properties: ["name"],
        return_metadata: [:uuid, :distance]
      )

      # Nested references
      QueryReference.new("hasAuthor",
        return_properties: ["name"],
        return_references: [
          QueryReference.new("hasPublisher", return_properties: ["name"])
        ]
      )

      # Use in query
      Query.get("Article")
      |> Query.return_references([
        QueryReference.new("hasAuthor", return_properties: ["name"])
      ])
  """

  alias WeaviateEx.Query.Metadata

  @type metadata_option :: [atom()] | :full | :common | nil

  @type t :: %__MODULE__{
          link_on: String.t(),
          target_collection: String.t() | nil,
          return_properties: [String.t()] | nil,
          return_references: [t()] | nil,
          return_metadata: metadata_option(),
          include_vector: boolean()
        }

  defstruct [
    :link_on,
    :target_collection,
    :return_properties,
    :return_references,
    :return_metadata,
    include_vector: false
  ]

  @doc """
  Create a new query reference configuration.

  ## Parameters

    - `link_on` - The reference property name
    - `opts` - Options:
      - `:return_properties` - List of properties to return from referenced objects
      - `:return_references` - List of nested QueryReference for further traversal
      - `:return_metadata` - Metadata to return (list of atoms, `:full`, `:common`)
      - `:include_vector` - Whether to include vector in response

  ## Examples

      QueryReference.new("hasAuthor")
      QueryReference.new("hasAuthor", return_properties: ["name", "bio"])
      QueryReference.new("hasAuthor",
        return_properties: ["name"],
        return_metadata: [:uuid, :distance]
      )
  """
  @spec new(String.t(), keyword()) :: t()
  def new(link_on, opts \\ []) when is_binary(link_on) do
    %__MODULE__{
      link_on: link_on,
      return_properties: Keyword.get(opts, :return_properties),
      return_references: Keyword.get(opts, :return_references),
      return_metadata: normalize_metadata(Keyword.get(opts, :return_metadata)),
      include_vector: Keyword.get(opts, :include_vector, false)
    }
  end

  @doc """
  Create a multi-target reference query.

  For reference properties that can point to multiple collections,
  specify which target collection to query.

  ## Arguments

    - `link_on` - Reference property name
    - `target_collection` - Specific collection to query

  ## Options

    Same as `new/2`

  ## Examples

      QueryReference.multi_target("relatedTo", "Article",
        return_properties: ["title", "content"]
      )

      QueryReference.multi_target("mentions", "Person",
        return_properties: ["name"],
        return_metadata: :full
      )
  """
  @spec multi_target(String.t(), String.t(), keyword()) :: t()
  def multi_target(link_on, target_collection, opts \\ [])
      when is_binary(link_on) and is_binary(target_collection) do
    %__MODULE__{
      link_on: link_on,
      target_collection: target_collection,
      return_properties: Keyword.get(opts, :return_properties),
      return_references: Keyword.get(opts, :return_references),
      return_metadata: normalize_metadata(Keyword.get(opts, :return_metadata)),
      include_vector: Keyword.get(opts, :include_vector, false)
    }
  end

  @doc """
  Check if this is a multi-target reference query.
  """
  @spec multi_target?(t()) :: boolean()
  def multi_target?(%__MODULE__{target_collection: nil}), do: false
  def multi_target?(%__MODULE__{target_collection: _}), do: true

  @doc """
  Convert query reference configuration to GraphQL format.

  ## Examples

      ref = QueryReference.new("hasAuthor", return_properties: ["name"])
      QueryReference.to_graphql(ref)
  """
  @spec to_graphql(t()) :: String.t()
  def to_graphql(%__MODULE__{} = ref) do
    build_reference_graphql(ref)
  end

  @doc """
  Convert a list of query references to GraphQL format.

  ## Examples

      refs = [QueryReference.new("hasAuthor", return_properties: ["name"])]
      QueryReference.list_to_graphql(refs)
  """
  @spec list_to_graphql([t()]) :: String.t()
  def list_to_graphql(refs) when is_list(refs) do
    Enum.map_join(refs, "\n", &to_graphql/1)
  end

  # Private helpers

  defp normalize_metadata(nil), do: nil
  defp normalize_metadata(:full), do: :full
  defp normalize_metadata(:common), do: :common
  defp normalize_metadata(fields) when is_list(fields), do: fields

  defp build_reference_graphql(%__MODULE__{} = ref) do
    properties = build_properties_section(ref)
    additional = build_additional_section(ref)
    nested_refs = build_nested_refs_section(ref)

    content =
      [properties, additional, nested_refs]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    class_name = get_class_name(ref)

    if content == "" do
      "#{ref.link_on} { ... on #{class_name} { _additional { id } } }"
    else
      "#{ref.link_on} { ... on #{class_name} { #{content} } }"
    end
  end

  # Get class name from target_collection or infer from link_on
  defp get_class_name(%__MODULE__{target_collection: target}) when is_binary(target), do: target
  defp get_class_name(%__MODULE__{link_on: link_on}), do: infer_class_name(link_on)

  defp build_properties_section(%__MODULE__{return_properties: nil}), do: nil

  defp build_properties_section(%__MODULE__{return_properties: props}) do
    Enum.join(props, "\n")
  end

  defp build_additional_section(%__MODULE__{
         return_metadata: metadata,
         include_vector: include_vector
       }) do
    fields = build_metadata_fields(metadata, include_vector)
    "_additional { #{fields} }"
  end

  defp build_metadata_fields(nil, true), do: "id vector"
  defp build_metadata_fields(nil, false), do: "id"

  defp build_metadata_fields(:full, include_vector) do
    base = Metadata.full() |> Enum.join(" ")
    if include_vector, do: "#{base} vector", else: base
  end

  defp build_metadata_fields(:common, include_vector) do
    base = Metadata.common() |> Enum.join(" ")
    if include_vector, do: "#{base} vector", else: base
  end

  defp build_metadata_fields(fields, include_vector) when is_list(fields) do
    # Convert atom fields to strings
    field_strings =
      fields
      |> Enum.map(&metadata_field_to_string/1)
      |> Enum.uniq()

    # Always include id if not present
    field_strings =
      if "id" in field_strings, do: field_strings, else: ["id" | field_strings]

    # Add vector if requested
    field_strings =
      if include_vector and "vector" not in field_strings do
        field_strings ++ ["vector"]
      else
        field_strings
      end

    Enum.join(field_strings, " ")
  end

  defp metadata_field_to_string(:uuid), do: "id"
  defp metadata_field_to_string(:id), do: "id"
  defp metadata_field_to_string(:distance), do: "distance"
  defp metadata_field_to_string(:certainty), do: "certainty"
  defp metadata_field_to_string(:score), do: "score"
  defp metadata_field_to_string(:explain_score), do: "explainScore"
  defp metadata_field_to_string(:explainScore), do: "explainScore"
  defp metadata_field_to_string(:creation_time), do: "creationTimeUnix"
  defp metadata_field_to_string(:creationTimeUnix), do: "creationTimeUnix"
  defp metadata_field_to_string(:last_update_time), do: "lastUpdateTimeUnix"
  defp metadata_field_to_string(:lastUpdateTimeUnix), do: "lastUpdateTimeUnix"
  defp metadata_field_to_string(:is_consistent), do: "isConsistent"
  defp metadata_field_to_string(:isConsistent), do: "isConsistent"
  defp metadata_field_to_string(:vector), do: "vector"
  defp metadata_field_to_string(field) when is_atom(field), do: Atom.to_string(field)
  defp metadata_field_to_string(field) when is_binary(field), do: field

  defp build_nested_refs_section(%__MODULE__{return_references: nil}), do: nil

  defp build_nested_refs_section(%__MODULE__{return_references: refs}) do
    Enum.map_join(refs, "\n", &build_reference_graphql/1)
  end

  # Infer class name from reference property (e.g., "hasAuthor" -> "Author")
  defp infer_class_name(ref_prop) do
    ref_prop
    |> String.replace_leading("has", "")
    |> String.replace_leading("Has", "")
  end
end
