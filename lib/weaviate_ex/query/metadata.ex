defmodule WeaviateEx.Query.Metadata do
  @moduledoc """
  Metadata selection helpers for queries.

  Controls which metadata fields are returned with query results.

  ## Examples

      # Return all metadata
      Query.get("Article")
      |> Query.return_metadata(Metadata.full())

      # Return only distance and certainty
      Query.get("Article")
      |> Query.return_metadata(Metadata.select(["distance", "certainty"]))

      # Return common metadata
      Query.get("Article")
      |> Query.return_metadata(Metadata.common())
  """

  @all_fields [
    "id",
    "creationTimeUnix",
    "lastUpdateTimeUnix",
    "distance",
    "certainty",
    "score",
    "explainScore",
    "isConsistent"
  ]

  @common_fields ["id", "distance", "certainty", "score"]

  @timestamp_fields ["creationTimeUnix", "lastUpdateTimeUnix"]

  @type fields :: [String.t()]

  @doc """
  Return all available metadata fields.

  Includes: id, creationTimeUnix, lastUpdateTimeUnix, distance,
  certainty, score, explainScore, isConsistent

  ## Examples

      Metadata.full()
  """
  @spec full() :: fields()
  def full, do: @all_fields

  @doc """
  Select specific metadata fields.

  ## Examples

      Metadata.select(["id", "distance"])
  """
  @spec select(fields()) :: fields()
  def select(fields) when is_list(fields), do: fields

  @doc """
  Return commonly used metadata fields.

  Includes: id, distance, certainty, score

  ## Examples

      Metadata.common()
  """
  @spec common() :: fields()
  def common, do: @common_fields

  @doc """
  Return timestamp metadata fields.

  Includes: creationTimeUnix, lastUpdateTimeUnix

  ## Examples

      Metadata.timestamps()
  """
  @spec timestamps() :: fields()
  def timestamps, do: @timestamp_fields

  @doc """
  Convert metadata fields to GraphQL format.

  ## Examples

      Metadata.to_graphql(["id", "distance"])
      # => "id distance"
  """
  @spec to_graphql(fields()) :: String.t()
  def to_graphql(fields) when is_list(fields) do
    Enum.join(fields, " ")
  end
end
