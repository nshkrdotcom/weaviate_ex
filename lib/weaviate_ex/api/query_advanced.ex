defmodule WeaviateEx.API.QueryAdvanced do
  @moduledoc """
  Advanced query operations for Phase 2.

  Provides advanced search capabilities including:
  - Image similarity search (near_image)
  - Multi-media search (near_audio, near_video, near_thermal, etc.)
  - Result sorting
  - Result grouping
  - Automatic result cutoff (autocut)
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type collection_name :: String.t()
  @type opts :: keyword()
  @type query :: map()
  @type media_type :: :audio | :video | :image | :depth | :thermal | :imu

  ## Near Image Search

  @doc """
  Perform image similarity search using base64-encoded image data.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `image_data` - Base64-encoded image data
    * `opts` - Options (`:limit`, `:certainty`, `:distance`, `:fields`)

  ## Examples

      {:ok, results} = QueryAdvanced.near_image(client, "Article", base64_image,
        limit: 10,
        certainty: 0.7
      )

  ## Returns
    * `{:ok, [map()]}` - List of matching objects
    * `{:error, Error.t()}` - Error if search fails
  """
  @spec near_image(Client.t(), collection_name(), binary(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def near_image(client, collection_name, image_data, opts \\ []) do
    # Extract options
    limit = Keyword.get(opts, :limit, 10)
    fields = Keyword.get(opts, :fields, ["_additional { distance }"])
    certainty = Keyword.get(opts, :certainty)
    distance = Keyword.get(opts, :distance)

    # Build nearImage clause
    near_clause = build_near_image_clause(image_data, certainty, distance)

    # Build full GraphQL query
    query = """
    {
      Get {
        #{collection_name}(
          nearImage: #{near_clause}
          limit: #{limit}
        ) {
          #{Enum.join(fields, "\n          ")}
        }
      }
    }
    """

    # Execute query
    case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
      {:ok, %{"data" => %{"Get" => get_results}}} ->
        results = Map.get(get_results, collection_name, [])
        {:ok, results}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  defp build_near_image_clause(image_data, certainty, distance) do
    parts = [~s(image: "#{image_data}")]

    parts =
      if certainty do
        [~s(certainty: #{certainty}) | parts]
      else
        parts
      end

    parts =
      if distance do
        [~s(distance: #{distance}) | parts]
      else
        parts
      end

    "{ #{Enum.join(Enum.reverse(parts), ", ")} }"
  end

  ## Near Media Search

  @doc """
  Perform multi-media similarity search.

  Supports various media types for multi2vec-bind module:
  - `:audio` - Audio similarity (nearAudio)
  - `:video` - Video similarity (nearVideo)
  - `:image` - Image similarity (nearImage, alternative to near_image/4)
  - `:depth` - Depth map similarity (nearDepth)
  - `:thermal` - Thermal image similarity (nearThermal)
  - `:imu` - IMU data similarity (nearIMU)

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `media_type` - Type of media (`:audio`, `:video`, etc.)
    * `media_data` - Base64-encoded media data
    * `opts` - Options (`:limit`, `:certainty`, `:distance`, `:fields`)

  ## Examples

      {:ok, results} = QueryAdvanced.near_media(client, "Podcast", :audio, audio_data,
        limit: 5,
        certainty: 0.75
      )

  ## Returns
    * `{:ok, [map()]}` - List of matching objects
    * `{:error, Error.t()}` - Error if search fails or media type unsupported
  """
  @spec near_media(Client.t(), collection_name(), media_type(), binary(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def near_media(client, collection_name, media_type, media_data, opts \\ []) do
    # Validate media type
    unless media_type in [:audio, :video, :image, :depth, :thermal, :imu] do
      {:error,
       %Error{
         type: :validation_error,
         message: "Unsupported media type: #{media_type}"
       }}
    else
      # Extract options
      limit = Keyword.get(opts, :limit, 10)
      fields = Keyword.get(opts, :fields, ["_additional { distance }"])
      certainty = Keyword.get(opts, :certainty)
      distance = Keyword.get(opts, :distance)

      # Build near{Media} clause
      near_field = media_type_to_near_field(media_type)
      near_clause = build_near_media_clause(media_data, certainty, distance)

      # Build full GraphQL query
      query = """
      {
        Get {
          #{collection_name}(
            #{near_field}: #{near_clause}
            limit: #{limit}
          ) {
            #{Enum.join(fields, "\n          ")}
          }
        }
      }
      """

      # Execute query
      case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
        {:ok, %{"data" => %{"Get" => get_results}}} ->
          results = Map.get(get_results, collection_name, [])
          {:ok, results}

        {:ok, _} ->
          {:ok, []}

        {:error, _} = error ->
          error
      end
    end
  end

  defp media_type_to_near_field(:audio), do: "nearAudio"
  defp media_type_to_near_field(:video), do: "nearVideo"
  defp media_type_to_near_field(:image), do: "nearImage"
  defp media_type_to_near_field(:depth), do: "nearDepth"
  defp media_type_to_near_field(:thermal), do: "nearThermal"
  defp media_type_to_near_field(:imu), do: "nearIMU"

  defp build_near_media_clause(media_data, certainty, distance) do
    # Same as build_near_image_clause but more generic
    parts = [~s(media: "#{media_data}")]

    parts =
      if certainty do
        [~s(certainty: #{certainty}) | parts]
      else
        parts
      end

    parts =
      if distance do
        [~s(distance: #{distance}) | parts]
      else
        parts
      end

    "{ #{Enum.join(Enum.reverse(parts), ", ")} }"
  end

  ## Sort

  @doc """
  Add sorting to a query.

  ## Parameters
    * `query` - Query map to modify
    * `sort_fields` - List of `{field, direction}` tuples where direction is `:asc` or `:desc`

  ## Examples

      query
      |> QueryAdvanced.sort([{:publishedAt, :desc}, {:title, :asc}])

      query
      |> QueryAdvanced.sort([{:views, :desc}])

  ## Returns
    * `query` - Modified query with sort parameters
  """
  @spec sort(query(), [{atom() | String.t(), :asc | :desc}]) :: query()
  def sort(query, sort_fields) do
    # Convert sort fields to proper format
    sort_specs =
      Enum.map(sort_fields, fn {field, direction} ->
        field_str = if is_atom(field), do: Atom.to_string(field), else: field
        dir_str = if direction == :asc, do: "asc", else: "desc"
        %{path: [field_str], order: dir_str}
      end)

    # Add or replace sort in query
    Map.put(query, :sort, sort_specs)
  end

  ## Group By

  @doc """
  Group query results by property.

  ## Parameters
    * `query` - Query map to modify
    * `property` - Property to group by (supports nested paths like "author.name")
    * `opts` - Options (`:groups`, `:objects_per_group`)

  ## Examples

      query
      |> QueryAdvanced.group_by("category", groups: 5, objects_per_group: 3)

      query
      |> QueryAdvanced.group_by("author.name")

  ## Returns
    * `query` - Modified query with groupBy parameters
  """
  @spec group_by(query(), String.t(), opts()) :: query()
  def group_by(query, property, opts \\ []) do
    # Parse nested property paths (e.g., "author.name" -> ["author", "name"])
    path =
      property
      |> String.split(".")
      |> Enum.map(&String.trim/1)

    # Build groupBy spec
    group_spec = %{
      path: path,
      groups: Keyword.get(opts, :groups, 1),
      objects_per_group: Keyword.get(opts, :objects_per_group, 10)
    }

    # Add groupBy to query
    Map.put(query, :group_by, group_spec)
  end

  ## Autocut

  @doc """
  Add autocut to automatically limit results based on score quality.

  Autocut uses the score distribution to determine a natural cutoff point,
  only returning results that are significantly better than the rest.

  ## Parameters
    * `query` - Query map to modify
    * `max_results` - Maximum number of results to return

  ## Examples

      query
      |> QueryAdvanced.autocut(5)

  ## Returns
    * `query` - Modified query with autocut parameter
  """
  @spec autocut(query(), pos_integer()) :: query()
  def autocut(query, max_results) do
    # Add autocut parameter to query
    Map.put(query, :autocut, max_results)
  end
end
