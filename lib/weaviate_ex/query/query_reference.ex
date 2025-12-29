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

  @type t :: %__MODULE__{
          link_on: String.t(),
          return_properties: [String.t()] | nil,
          return_references: [t()] | nil,
          include_vector: boolean()
        }

  defstruct [:link_on, :return_properties, :return_references, include_vector: false]

  @doc """
  Create a new query reference configuration.

  ## Parameters

    - `link_on` - The reference property name
    - `opts` - Options:
      - `:return_properties` - List of properties to return from referenced objects
      - `:return_references` - List of nested QueryReference for further traversal
      - `:include_vector` - Whether to include vector in response

  ## Examples

      QueryReference.new("hasAuthor")
      QueryReference.new("hasAuthor", return_properties: ["name", "bio"])
  """
  @spec new(String.t(), keyword()) :: t()
  def new(link_on, opts \\ []) when is_binary(link_on) do
    %__MODULE__{
      link_on: link_on,
      return_properties: Keyword.get(opts, :return_properties),
      return_references: Keyword.get(opts, :return_references),
      include_vector: Keyword.get(opts, :include_vector, false)
    }
  end

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

  defp build_reference_graphql(%__MODULE__{} = ref) do
    properties = build_properties_section(ref)
    additional = build_additional_section(ref)
    nested_refs = build_nested_refs_section(ref)

    content =
      [properties, additional, nested_refs]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    if content == "" do
      "#{ref.link_on} { ... on #{infer_class_name(ref.link_on)} { _additional { id } } }"
    else
      "#{ref.link_on} { ... on #{infer_class_name(ref.link_on)} { #{content} } }"
    end
  end

  defp build_properties_section(%__MODULE__{return_properties: nil}), do: nil

  defp build_properties_section(%__MODULE__{return_properties: props}) do
    Enum.join(props, "\n")
  end

  defp build_additional_section(%__MODULE__{include_vector: true}) do
    "_additional { id vector }"
  end

  defp build_additional_section(_), do: "_additional { id }"

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
