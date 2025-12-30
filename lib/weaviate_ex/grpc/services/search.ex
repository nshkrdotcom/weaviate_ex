defmodule WeaviateEx.GRPC.Services.Search do
  @moduledoc """
  gRPC Search service for vector queries.

  This module provides high-level functions for performing vector searches
  against Weaviate using gRPC.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      {:ok, results} = Search.near_vector(channel, "Article", [0.1, 0.2, ...],
        limit: 10,
        return_properties: ["title", "content"]
      )
  """

  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel
  alias WeaviateEx.GRPC.Retry
  alias WeaviateEx.Query.GroupBy, as: QueryGroupBy
  alias WeaviateEx.Query.Metadata, as: QueryMetadata
  alias WeaviateEx.Query.{NearImage, NearMedia, QueryReference, TargetVectors}

  # Import generated protobuf modules
  alias Weaviate.V1.{
    BM25,
    Filters,
    GroupBy,
    Hybrid,
    MetadataRequest,
    NearAudioSearch,
    NearDepthSearch,
    NearImageSearch,
    NearIMUSearch,
    NearObject,
    NearTextSearch,
    NearThermalSearch,
    NearVector,
    NearVideoSearch,
    PropertiesRequest,
    RefPropertiesRequest,
    SearchOperatorOptions,
    SearchRequest
  }

  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @type search_opts :: [
          limit: non_neg_integer(),
          offset: non_neg_integer(),
          return_properties: [String.t()],
          return_references: [QueryReference.t()],
          return_metadata: [atom()],
          filters: map(),
          group_by: QueryGroupBy.t(),
          tenant: String.t(),
          certainty: float(),
          distance: float(),
          move_to: map(),
          move_away: map(),
          target_vectors: TargetVectors.t(),
          bm25_search_operator: map(),
          max_vector_distance: float(),
          fusion_type: atom(),
          after: String.t(),
          sort: list(),
          autocut: non_neg_integer()
        ]

  @doc """
  Perform a vector similarity search.

  ## Options

    * `:limit` - Maximum number of results (default: 10)
    * `:offset` - Number of results to skip
    * `:return_properties` - List of property names to return
    * `:return_metadata` - List of metadata fields (e.g., [:uuid, :distance, :vector])
    * `:tenant` - Tenant name for multi-tenant collections
    * `:certainty` - Minimum certainty threshold (0.0 to 1.0)
    * `:distance` - Maximum distance threshold

  ## Examples

      {:ok, results} = Search.near_vector(channel, "Article", vector,
        limit: 10,
        return_properties: ["title", "content"]
      )
  """
  @spec near_vector(GRPC.Channel.t(), String.t(), [float()], search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def near_vector(channel, collection, vector, opts \\ []) do
    request = build_near_vector_request(collection, vector, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_near_vector_request(String.t(), [float()], search_opts()) :: SearchRequest.t()
  def build_near_vector_request(collection, vector, opts \\ []) do
    near_vector_msg = build_near_vector(vector, opts)

    request = build_search_request(collection, opts)
    %{request | near_vector: near_vector_msg}
  end

  @doc """
  Perform a text-based vector search using a text-to-vector model.

  ## Options

    * `:move_to` - Concepts to move towards
    * `:move_away` - Concepts to move away from
    * Plus all options from `near_vector/4`

  ## Examples

      {:ok, results} = Search.near_text(channel, "Article", "machine learning",
        limit: 10
      )
  """
  @spec near_text(GRPC.Channel.t(), String.t(), String.t() | [String.t()], search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def near_text(channel, collection, query, opts \\ []) do
    request = build_near_text_request(collection, query, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_near_text_request(String.t(), String.t() | [String.t()], search_opts()) ::
          SearchRequest.t()
  def build_near_text_request(collection, query, opts \\ []) do
    concepts = if is_binary(query), do: [query], else: query

    near_text_msg = %NearTextSearch{
      query: concepts,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance),
      move_to: build_move_to(Keyword.get(opts, :move_to)),
      move_away: build_move_to(Keyword.get(opts, :move_away)),
      targets: build_targets(Keyword.get(opts, :target_vectors))
    }

    request = build_search_request(collection, opts)
    %{request | near_text: near_text_msg}
  end

  @doc """
  Perform a search for objects similar to a given object.

  ## Examples

      {:ok, results} = Search.near_object(channel, "Article", "uuid-of-object",
        limit: 10
      )
  """
  @spec near_object(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def near_object(channel, collection, object_id, opts \\ []) do
    request = build_near_object_request(collection, object_id, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_near_object_request(String.t(), String.t(), search_opts()) :: SearchRequest.t()
  def build_near_object_request(collection, object_id, opts \\ []) do
    near_object_msg = %NearObject{
      id: object_id,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance),
      targets: build_targets(Keyword.get(opts, :target_vectors))
    }

    request = build_search_request(collection, opts)
    %{request | near_object: near_object_msg}
  end

  @doc """
  Perform a BM25 keyword search.

  ## Options

    * `:properties` - List of properties to search in

  ## Examples

      {:ok, results} = Search.bm25(channel, "Article", "machine learning",
        properties: ["title", "content"],
        limit: 10
      )
  """
  @spec bm25(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def bm25(channel, collection, query, opts \\ []) do
    request = build_bm25_request(collection, query, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_bm25_request(String.t(), String.t(), search_opts()) :: SearchRequest.t()
  def build_bm25_request(collection, query, opts \\ []) do
    bm25_msg = %BM25{
      query: query,
      properties: Keyword.get(opts, :properties, [])
    }

    request = build_search_request(collection, opts)
    %{request | bm25_search: bm25_msg}
  end

  @doc """
  Perform a hybrid search combining vector and keyword search.

  ## Options

    * `:alpha` - Weight between vector (1.0) and keyword (0.0) search
    * `:fusion_type` - Fusion algorithm (:ranked or :relative_score)
    * `:properties` - Properties to search for BM25

  ## Examples

      {:ok, results} = Search.hybrid(channel, "Article", "machine learning",
        alpha: 0.5,
        limit: 10
      )
  """
  @spec hybrid(GRPC.Channel.t(), String.t(), String.t(), search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def hybrid(channel, collection, query, opts \\ []) do
    request = build_hybrid_request(collection, query, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_hybrid_request(String.t(), String.t(), search_opts()) :: SearchRequest.t()
  def build_hybrid_request(collection, query, opts \\ []) do
    alpha = Keyword.get(opts, :alpha, 0.5)
    properties = Keyword.get(opts, :properties, [])

    hybrid_msg = %Hybrid{
      query: query,
      alpha: alpha,
      properties: properties,
      fusion_type: build_fusion_type(Keyword.get(opts, :fusion_type)),
      targets: build_targets(Keyword.get(opts, :target_vectors)),
      bm25_search_operator: build_bm25_search_operator(Keyword.get(opts, :bm25_search_operator))
    }

    hybrid_msg =
      case Keyword.get(opts, :max_vector_distance) do
        nil -> hybrid_msg
        max_vector_distance -> %{hybrid_msg | threshold: {:vector_distance, max_vector_distance}}
      end

    request = build_search_request(collection, opts)
    %{request | hybrid_search: hybrid_msg}
  end

  @doc """
  Perform a multimodal image search.

  ## Options

    * `:limit` - Maximum number of results (default: 10)
    * `:offset` - Number of results to skip
    * `:return_properties` - List of property names to return
    * `:return_metadata` - List of metadata fields (e.g., [:uuid, :distance, :vector])
    * `:tenant` - Tenant name for multi-tenant collections

  """
  @spec near_image(GRPC.Channel.t(), String.t(), NearImage.t(), search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def near_image(channel, collection, %NearImage{} = near_image, opts \\ []) do
    request = build_near_image_request(collection, near_image, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_near_image_request(String.t(), NearImage.t(), search_opts()) :: SearchRequest.t()
  def build_near_image_request(collection, %NearImage{} = near_image, opts \\ []) do
    near_image_msg = build_near_image(near_image)

    request = build_search_request(collection, opts)
    %{request | near_image: near_image_msg}
  end

  @doc """
  Perform a multimodal media search (audio, video, depth, thermal, IMU).
  """
  @spec near_media(GRPC.Channel.t(), String.t(), NearMedia.t(), search_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def near_media(channel, collection, %NearMedia{} = near_media, opts \\ []) do
    request = build_near_media_request(collection, near_media, opts)
    execute_search(channel, request, opts)
  end

  @doc false
  @spec build_near_media_request(String.t(), NearMedia.t(), search_opts()) :: SearchRequest.t()
  def build_near_media_request(collection, %NearMedia{} = near_media, opts \\ []) do
    {field, message} = build_near_media(near_media)

    request = build_search_request(collection, opts)
    struct(request, %{field => message})
  end

  @doc """
  Execute a raw SearchRequest.

  Useful for complex queries that need full control over the request.

  ## Examples

      request = %SearchRequest{
        collection: "Article",
        limit: 10,
        near_vector: %NearVector{vector_bytes: <<...>>}
      }
      {:ok, results} = Search.execute(channel, request)
  """
  @spec execute(GRPC.Channel.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, Error.t()}
  def execute(channel, %SearchRequest{} = request, opts \\ []) do
    execute_search(channel, request, opts)
  end

  @doc """
  Perform a generic search with a filter request map.

  This is a lower-level function used by the Debug module for protocol comparison.

  ## Options

    * `:metadata` - gRPC metadata headers

  ## Examples

      request = %{collection: "Article", filters: %{...}, limit: 1}
      {:ok, results} = Search.search(channel, "Article", request, metadata: metadata)
  """
  @spec search(GRPC.Channel.t(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, Error.t()}
  def search(channel, collection, request, opts \\ []) do
    # Build a search request from the request map
    search_request = %SearchRequest{
      collection: collection,
      tenant: Map.get(request, :tenant, ""),
      limit: Map.get(request, :limit, 10),
      offset: Map.get(request, :offset, 0),
      properties: build_properties_request([]),
      metadata: build_metadata_request(return_metadata: [:uuid, :vector]),
      group_by: build_group_by(Map.get(request, :group_by)),
      filters: build_filters(Map.get(request, :filters)),
      uses_127_api: true
    }

    execute_search(channel, search_request, opts)
  end

  # Private functions

  defp build_search_request(collection, opts) do
    %SearchRequest{
      collection: collection,
      tenant: Keyword.get(opts, :tenant, ""),
      limit: Keyword.get(opts, :limit, 10),
      offset: Keyword.get(opts, :offset, 0),
      autocut: Keyword.get(opts, :autocut, 0),
      properties: build_properties_request(opts),
      metadata: build_metadata_request(opts),
      group_by: build_group_by(Keyword.get(opts, :group_by)),
      filters: build_filters(Keyword.get(opts, :filters)),
      uses_127_api: true
    }
  end

  defp build_near_vector(vector, opts) when is_list(vector) do
    # Convert float list to bytes for efficiency
    vector_bytes =
      vector
      |> Enum.map(&<<&1::float-little-32>>)
      |> IO.iodata_to_binary()

    %NearVector{
      vector_bytes: vector_bytes,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance),
      targets: build_targets(Keyword.get(opts, :target_vectors))
    }
  end

  defp build_properties_request(opts) do
    props = Keyword.get(opts, :return_properties)
    refs = Keyword.get(opts, :return_references)

    if is_nil(props) and is_nil(refs) do
      nil
    else
      %PropertiesRequest{
        non_ref_properties: props || [],
        return_all_nonref_properties: false,
        ref_properties: build_ref_properties(refs)
      }
    end
  end

  defp build_metadata_request(opts) do
    case Keyword.get(opts, :return_metadata) do
      nil ->
        # Return common metadata by default
        %MetadataRequest{
          uuid: true,
          distance: true,
          certainty: true
        }

      fields when is_list(fields) ->
        normalized = normalize_metadata_fields(fields)

        %MetadataRequest{
          uuid: :uuid in normalized,
          vector: :vector in normalized,
          creation_time_unix: :creation_time in normalized,
          last_update_time_unix: :update_time in normalized,
          distance: :distance in normalized,
          certainty: :certainty in normalized,
          score: :score in normalized,
          explain_score: :explain_score in normalized,
          is_consistent: :is_consistent in normalized
        }
    end
  end

  defp build_ref_properties(nil), do: []
  defp build_ref_properties([]), do: []

  defp build_ref_properties(refs) when is_list(refs) do
    Enum.map(refs, &build_ref_properties_request/1)
  end

  defp build_ref_properties_request(%QueryReference{} = ref) do
    %RefPropertiesRequest{
      reference_property: ref.link_on,
      properties: build_reference_properties_request(ref),
      metadata: build_reference_metadata(ref),
      target_collection: ref.target_collection || ""
    }
  end

  defp build_reference_properties_request(%QueryReference{} = ref) do
    props = ref.return_properties
    refs = ref.return_references

    if is_nil(props) and is_nil(refs) do
      nil
    else
      %PropertiesRequest{
        non_ref_properties: props || [],
        return_all_nonref_properties: false,
        ref_properties: build_ref_properties(refs)
      }
    end
  end

  defp build_reference_metadata(%QueryReference{} = ref) do
    fields =
      ref.return_metadata
      |> normalize_reference_metadata_fields(ref.include_vector)

    build_metadata_request(return_metadata: fields)
  end

  defp normalize_reference_metadata_fields(nil, include_vector) do
    fields = [:uuid]
    maybe_add_vector(fields, include_vector)
  end

  defp normalize_reference_metadata_fields(:full, include_vector) do
    QueryMetadata.full()
    |> normalize_metadata_fields()
    |> ensure_uuid()
    |> maybe_add_vector(include_vector)
  end

  defp normalize_reference_metadata_fields(:common, include_vector) do
    QueryMetadata.common()
    |> normalize_metadata_fields()
    |> ensure_uuid()
    |> maybe_add_vector(include_vector)
  end

  defp normalize_reference_metadata_fields(fields, include_vector) when is_list(fields) do
    fields
    |> normalize_metadata_fields()
    |> ensure_uuid()
    |> maybe_add_vector(include_vector)
  end

  defp normalize_metadata_fields(fields) when is_list(fields) do
    fields
    |> Enum.map(&metadata_key_to_atom/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp metadata_key_to_atom(:id), do: :uuid
  defp metadata_key_to_atom(:uuid), do: :uuid
  defp metadata_key_to_atom("id"), do: :uuid
  defp metadata_key_to_atom("uuid"), do: :uuid
  defp metadata_key_to_atom(:distance), do: :distance
  defp metadata_key_to_atom("distance"), do: :distance
  defp metadata_key_to_atom(:certainty), do: :certainty
  defp metadata_key_to_atom("certainty"), do: :certainty
  defp metadata_key_to_atom(:score), do: :score
  defp metadata_key_to_atom("score"), do: :score
  defp metadata_key_to_atom(:explain_score), do: :explain_score
  defp metadata_key_to_atom("explainScore"), do: :explain_score
  defp metadata_key_to_atom(:creation_time), do: :creation_time
  defp metadata_key_to_atom("creationTimeUnix"), do: :creation_time
  defp metadata_key_to_atom(:last_update_time), do: :update_time
  defp metadata_key_to_atom(:update_time), do: :update_time
  defp metadata_key_to_atom("lastUpdateTimeUnix"), do: :update_time
  defp metadata_key_to_atom(:is_consistent), do: :is_consistent
  defp metadata_key_to_atom("isConsistent"), do: :is_consistent
  defp metadata_key_to_atom(:vector), do: :vector
  defp metadata_key_to_atom("vector"), do: :vector
  defp metadata_key_to_atom(_), do: nil

  defp ensure_uuid(fields) do
    if :uuid in fields, do: fields, else: [:uuid | fields]
  end

  defp maybe_add_vector(fields, true) do
    if :vector in fields, do: fields, else: [:vector | fields]
  end

  defp maybe_add_vector(fields, _), do: fields

  defp build_group_by(nil), do: nil

  defp build_group_by(%QueryGroupBy{} = group_by) do
    %GroupBy{
      path: normalize_path(group_by.path),
      objects_per_group: group_by.objects_per_group,
      number_of_groups: group_by.number_of_groups
    }
  end

  defp build_group_by(group_by) when is_map(group_by) do
    %GroupBy{
      path: normalize_path(get_group_by_path(group_by)),
      objects_per_group: get_objects_per_group(group_by),
      number_of_groups: get_number_of_groups(group_by)
    }
  end

  defp get_group_by_path(group_by) do
    get_field(group_by, [:path, "path"]) || []
  end

  defp get_objects_per_group(group_by) do
    get_field(group_by, [
      :objects_per_group,
      "objects_per_group",
      :objectsPerGroup,
      "objectsPerGroup"
    ]) || 10
  end

  defp get_number_of_groups(group_by) do
    get_field(group_by, [:number_of_groups, "number_of_groups", :numberOfGroups, "numberOfGroups"]) ||
      10
  end

  defp normalize_path(path) when is_binary(path), do: [path]
  defp normalize_path(path) when is_list(path), do: path

  defp build_filters(nil), do: nil
  defp build_filters(%Filters{} = filters), do: filters

  defp build_filters(filter) when is_map(filter) do
    operands = get_field(filter, [:operands, "operands", :filters, "filters"])
    operator = map_operator(get_field(filter, [:operator, "operator"]))

    if is_list(operands) do
      %Filters{
        operator: operator,
        filters: Enum.map(operands, &build_filters/1)
      }
    else
      target = build_filter_target(get_field(filter, [:path, "path", :on, "on"]))

      %Filters{
        operator: operator,
        target: target
      }
      |> add_filter_value(filter)
    end
  end

  defp build_filter_target(nil), do: nil

  defp build_filter_target(path) when is_binary(path) do
    %Weaviate.V1.FilterTarget{target: {:property, path}}
  end

  defp build_filter_target(path) when is_list(path) do
    %Weaviate.V1.FilterTarget{target: {:property, Enum.join(path, ".")}}
  end

  defp add_filter_value(filter, source) do
    case extract_filter_value(source) do
      nil -> filter
      test_value -> %{filter | test_value: test_value}
    end
  end

  defp extract_filter_value(source) do
    extract_text_value(source) ||
      extract_int_value(source) ||
      extract_number_value(source) ||
      extract_boolean_value(source)
  end

  defp extract_text_value(source) do
    case get_field(source, [:value_text, "value_text", :valueText, "valueText"]) do
      nil ->
        nil

      value when is_list(value) ->
        {:value_text_array, %Weaviate.V1.TextArray{values: value}}

      value ->
        {:value_text, value}
    end
  end

  defp extract_int_value(source) do
    case get_field(source, [:value_int, "value_int", :valueInt, "valueInt"]) do
      nil ->
        nil

      value when is_list(value) ->
        {:value_int_array, %Weaviate.V1.IntArray{values: value}}

      value ->
        {:value_int, value}
    end
  end

  defp extract_number_value(source) do
    case get_field(source, [:value_number, "value_number", :valueNumber, "valueNumber"]) do
      nil ->
        nil

      value when is_list(value) ->
        {:value_number_array, %Weaviate.V1.NumberArray{values: value}}

      value ->
        {:value_number, value}
    end
  end

  defp extract_boolean_value(source) do
    case get_field(source, [:value_boolean, "value_boolean", :valueBoolean, "valueBoolean"]) do
      nil ->
        nil

      value when is_list(value) ->
        {:value_boolean_array, %Weaviate.V1.BooleanArray{values: value}}

      value ->
        {:value_boolean, value}
    end
  end

  defp map_operator(nil), do: :OPERATOR_UNSPECIFIED
  defp map_operator(:equal), do: :OPERATOR_EQUAL
  defp map_operator("Equal"), do: :OPERATOR_EQUAL
  defp map_operator(:not_equal), do: :OPERATOR_NOT_EQUAL
  defp map_operator("NotEqual"), do: :OPERATOR_NOT_EQUAL
  defp map_operator(:greater_than), do: :OPERATOR_GREATER_THAN
  defp map_operator("GreaterThan"), do: :OPERATOR_GREATER_THAN
  defp map_operator(:greater_than_equal), do: :OPERATOR_GREATER_THAN_EQUAL
  defp map_operator("GreaterThanEqual"), do: :OPERATOR_GREATER_THAN_EQUAL
  defp map_operator(:less_than), do: :OPERATOR_LESS_THAN
  defp map_operator("LessThan"), do: :OPERATOR_LESS_THAN
  defp map_operator(:less_than_equal), do: :OPERATOR_LESS_THAN_EQUAL
  defp map_operator("LessThanEqual"), do: :OPERATOR_LESS_THAN_EQUAL
  defp map_operator(:and), do: :OPERATOR_AND
  defp map_operator("And"), do: :OPERATOR_AND
  defp map_operator(:or), do: :OPERATOR_OR
  defp map_operator("Or"), do: :OPERATOR_OR
  defp map_operator(:like), do: :OPERATOR_LIKE
  defp map_operator("Like"), do: :OPERATOR_LIKE
  defp map_operator(:is_null), do: :OPERATOR_IS_NULL
  defp map_operator("IsNull"), do: :OPERATOR_IS_NULL
  defp map_operator(:contains_any), do: :OPERATOR_CONTAINS_ANY
  defp map_operator("ContainsAny"), do: :OPERATOR_CONTAINS_ANY
  defp map_operator(:contains_all), do: :OPERATOR_CONTAINS_ALL
  defp map_operator("ContainsAll"), do: :OPERATOR_CONTAINS_ALL
  defp map_operator(:contains_none), do: :OPERATOR_CONTAINS_NONE
  defp map_operator("ContainsNone"), do: :OPERATOR_CONTAINS_NONE
  defp map_operator(:not), do: :OPERATOR_NOT
  defp map_operator("Not"), do: :OPERATOR_NOT
  defp map_operator(_), do: :OPERATOR_UNSPECIFIED

  defp get_field(map, keys) do
    Enum.reduce_while(keys, nil, fn key, _acc ->
      if Map.has_key?(map, key) do
        {:halt, Map.get(map, key)}
      else
        {:cont, nil}
      end
    end)
  end

  defp build_targets(nil), do: nil
  defp build_targets(targets), do: TargetVectors.to_grpc(targets)

  defp build_move_to(nil), do: nil

  defp build_move_to(%WeaviateEx.Query.Move{} = move) do
    %NearTextSearch.Move{
      force: move.force,
      concepts: move.concepts || [],
      uuids: move.objects || []
    }
  end

  defp build_move_to(move) when is_map(move) do
    %NearTextSearch.Move{
      force: move[:force] || move["force"],
      concepts: move[:concepts] || move["concepts"] || [],
      uuids: move[:objects] || move["objects"] || move[:uuids] || move["uuids"] || []
    }
  end

  defp build_near_image(%NearImage{} = near_image) do
    %NearImageSearch{
      image: NearImage.get_encoded_image(near_image),
      certainty: near_image.certainty,
      distance: near_image.distance,
      targets: build_targets(near_image.target_vectors)
    }
  end

  defp build_near_media(%NearMedia{} = near_media) do
    payload = %{
      certainty: near_media.certainty,
      distance: near_media.distance,
      targets: build_targets(near_media.target_vectors)
    }

    case near_media.type do
      :audio ->
        {:near_audio,
         struct(
           NearAudioSearch,
           Map.put(payload, :audio, NearMedia.get_encoded_media(near_media))
         )}

      :video ->
        {:near_video,
         struct(
           NearVideoSearch,
           Map.put(payload, :video, NearMedia.get_encoded_media(near_media))
         )}

      :depth ->
        {:near_depth,
         struct(
           NearDepthSearch,
           Map.put(payload, :depth, NearMedia.get_encoded_media(near_media))
         )}

      :thermal ->
        {:near_thermal,
         struct(
           NearThermalSearch,
           Map.put(payload, :thermal, NearMedia.get_encoded_media(near_media))
         )}

      :imu ->
        {:near_imu,
         struct(NearIMUSearch, Map.put(payload, :imu, NearMedia.get_encoded_media(near_media)))}
    end
  end

  defp build_fusion_type(nil), do: :FUSION_TYPE_UNSPECIFIED
  defp build_fusion_type(:ranked), do: :FUSION_TYPE_RANKED
  defp build_fusion_type(:relative_score), do: :FUSION_TYPE_RELATIVE_SCORE
  defp build_fusion_type("rankedFusion"), do: :FUSION_TYPE_RANKED
  defp build_fusion_type("relativeScoreFusion"), do: :FUSION_TYPE_RELATIVE_SCORE
  defp build_fusion_type(_), do: :FUSION_TYPE_UNSPECIFIED

  defp build_bm25_search_operator(nil), do: nil

  defp build_bm25_search_operator(%SearchOperatorOptions{} = operator), do: operator

  defp build_bm25_search_operator(%{operator: operator} = config) do
    %SearchOperatorOptions{
      operator: map_bm25_operator(operator),
      minimum_or_tokens_match: config[:minimumShouldMatch] || config["minimumShouldMatch"]
    }
  end

  defp build_bm25_search_operator(config) when is_map(config) do
    operator = config[:operator] || config["operator"]

    %SearchOperatorOptions{
      operator: map_bm25_operator(operator),
      minimum_or_tokens_match: config[:minimumShouldMatch] || config["minimumShouldMatch"]
    }
  end

  defp map_bm25_operator(nil), do: :OPERATOR_UNSPECIFIED
  defp map_bm25_operator("And"), do: :OPERATOR_AND
  defp map_bm25_operator("Or"), do: :OPERATOR_OR
  defp map_bm25_operator(:and), do: :OPERATOR_AND
  defp map_bm25_operator(:or), do: :OPERATOR_OR
  defp map_bm25_operator(_), do: :OPERATOR_UNSPECIFIED

  defp execute_search(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    metadata = Channel.build_metadata(opts)
    retry_opts = Keyword.get(opts, :retry, [])

    Retry.with_retry(
      fn ->
        case WeaviateStub.search(channel, request, timeout: timeout, metadata: metadata) do
          {:ok, reply} ->
            {:ok, reply}

          {:error, %GRPC.RPCError{} = error} ->
            {:error, error}

          {:error, reason} ->
            {:error, Error.exception(type: :connection_error, message: inspect(reason))}
        end
      end,
      retry_opts
    )
    |> wrap_grpc_error()
  end

  defp wrap_grpc_error({:error, %GRPC.RPCError{} = error}) do
    {:error, Error.from_grpc_error(error)}
  end

  defp wrap_grpc_error(result), do: result
end
