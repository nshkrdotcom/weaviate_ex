defmodule Weaviate.V1.SearchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:collection, 1, type: :string)
  field(:tenant, 10, type: :string)

  field(:consistency_level, 11,
    proto3_optional: true,
    type: Weaviate.V1.ConsistencyLevel,
    json_name: "consistencyLevel",
    enum: true
  )

  field(:properties, 20, proto3_optional: true, type: Weaviate.V1.PropertiesRequest)
  field(:metadata, 21, proto3_optional: true, type: Weaviate.V1.MetadataRequest)
  field(:group_by, 22, proto3_optional: true, type: Weaviate.V1.GroupBy, json_name: "groupBy")
  field(:limit, 30, type: :uint32)
  field(:offset, 31, type: :uint32)
  field(:autocut, 32, type: :uint32)
  field(:after, 33, type: :string)
  field(:sort_by, 34, repeated: true, type: Weaviate.V1.SortBy, json_name: "sortBy")
  field(:filters, 40, proto3_optional: true, type: Weaviate.V1.Filters)

  field(:hybrid_search, 41,
    proto3_optional: true,
    type: Weaviate.V1.Hybrid,
    json_name: "hybridSearch"
  )

  field(:bm25_search, 42, proto3_optional: true, type: Weaviate.V1.BM25, json_name: "bm25Search")

  field(:near_vector, 43,
    proto3_optional: true,
    type: Weaviate.V1.NearVector,
    json_name: "nearVector"
  )

  field(:near_object, 44,
    proto3_optional: true,
    type: Weaviate.V1.NearObject,
    json_name: "nearObject"
  )

  field(:near_text, 45,
    proto3_optional: true,
    type: Weaviate.V1.NearTextSearch,
    json_name: "nearText"
  )

  field(:near_image, 46,
    proto3_optional: true,
    type: Weaviate.V1.NearImageSearch,
    json_name: "nearImage"
  )

  field(:near_audio, 47,
    proto3_optional: true,
    type: Weaviate.V1.NearAudioSearch,
    json_name: "nearAudio"
  )

  field(:near_video, 48,
    proto3_optional: true,
    type: Weaviate.V1.NearVideoSearch,
    json_name: "nearVideo"
  )

  field(:near_depth, 49,
    proto3_optional: true,
    type: Weaviate.V1.NearDepthSearch,
    json_name: "nearDepth"
  )

  field(:near_thermal, 50,
    proto3_optional: true,
    type: Weaviate.V1.NearThermalSearch,
    json_name: "nearThermal"
  )

  field(:near_imu, 51,
    proto3_optional: true,
    type: Weaviate.V1.NearIMUSearch,
    json_name: "nearImu"
  )

  field(:generative, 60, proto3_optional: true, type: Weaviate.V1.GenerativeSearch)
  field(:rerank, 61, proto3_optional: true, type: Weaviate.V1.Rerank)
  field(:uses_123_api, 100, type: :bool, json_name: "uses123Api", deprecated: true)
  field(:uses_125_api, 101, type: :bool, json_name: "uses125Api", deprecated: true)
  field(:uses_127_api, 102, type: :bool, json_name: "uses127Api")
end

defmodule Weaviate.V1.GroupBy do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:path, 1, repeated: true, type: :string)
  field(:number_of_groups, 2, type: :int32, json_name: "numberOfGroups")
  field(:objects_per_group, 3, type: :int32, json_name: "objectsPerGroup")
end

defmodule Weaviate.V1.SortBy do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:ascending, 1, type: :bool)
  field(:path, 2, repeated: true, type: :string)
end

defmodule Weaviate.V1.MetadataRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuid, 1, type: :bool)
  field(:vector, 2, type: :bool)
  field(:creation_time_unix, 3, type: :bool, json_name: "creationTimeUnix")
  field(:last_update_time_unix, 4, type: :bool, json_name: "lastUpdateTimeUnix")
  field(:distance, 5, type: :bool)
  field(:certainty, 6, type: :bool)
  field(:score, 7, type: :bool)
  field(:explain_score, 8, type: :bool, json_name: "explainScore")
  field(:is_consistent, 9, type: :bool, json_name: "isConsistent")
  field(:vectors, 10, repeated: true, type: :string)
end

defmodule Weaviate.V1.PropertiesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:non_ref_properties, 1, repeated: true, type: :string, json_name: "nonRefProperties")

  field(:ref_properties, 2,
    repeated: true,
    type: Weaviate.V1.RefPropertiesRequest,
    json_name: "refProperties"
  )

  field(:object_properties, 3,
    repeated: true,
    type: Weaviate.V1.ObjectPropertiesRequest,
    json_name: "objectProperties"
  )

  field(:return_all_nonref_properties, 11, type: :bool, json_name: "returnAllNonrefProperties")
end

defmodule Weaviate.V1.ObjectPropertiesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:prop_name, 1, type: :string, json_name: "propName")
  field(:primitive_properties, 2, repeated: true, type: :string, json_name: "primitiveProperties")

  field(:object_properties, 3,
    repeated: true,
    type: Weaviate.V1.ObjectPropertiesRequest,
    json_name: "objectProperties"
  )
end

defmodule Weaviate.V1.RefPropertiesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:reference_property, 1, type: :string, json_name: "referenceProperty")
  field(:properties, 2, type: Weaviate.V1.PropertiesRequest)
  field(:metadata, 3, type: Weaviate.V1.MetadataRequest)
  field(:target_collection, 4, type: :string, json_name: "targetCollection")
end

defmodule Weaviate.V1.Rerank do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:property, 1, type: :string)
  field(:query, 2, proto3_optional: true, type: :string)
end

defmodule Weaviate.V1.SearchReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:took, 1, type: :float)
  field(:results, 2, repeated: true, type: Weaviate.V1.SearchResult)

  field(:generative_grouped_result, 3,
    proto3_optional: true,
    type: :string,
    json_name: "generativeGroupedResult",
    deprecated: true
  )

  field(:group_by_results, 4,
    repeated: true,
    type: Weaviate.V1.GroupByResult,
    json_name: "groupByResults"
  )

  field(:generative_grouped_results, 5,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeResult,
    json_name: "generativeGroupedResults"
  )
end

defmodule Weaviate.V1.RerankReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:score, 1, type: :double)
end

defmodule Weaviate.V1.GroupByResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:min_distance, 2, type: :float, json_name: "minDistance")
  field(:max_distance, 3, type: :float, json_name: "maxDistance")
  field(:number_of_objects, 4, type: :int64, json_name: "numberOfObjects")
  field(:objects, 5, repeated: true, type: Weaviate.V1.SearchResult)
  field(:rerank, 6, proto3_optional: true, type: Weaviate.V1.RerankReply)

  field(:generative, 7,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeReply,
    deprecated: true
  )

  field(:generative_result, 8,
    proto3_optional: true,
    type: Weaviate.V1.GenerativeResult,
    json_name: "generativeResult"
  )
end

defmodule Weaviate.V1.SearchResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:properties, 1, type: Weaviate.V1.PropertiesResult)
  field(:metadata, 2, type: Weaviate.V1.MetadataResult)
  field(:generative, 3, proto3_optional: true, type: Weaviate.V1.GenerativeResult)
end

defmodule Weaviate.V1.MetadataResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:vector, 2, repeated: true, type: :float, deprecated: true)
  field(:creation_time_unix, 3, type: :int64, json_name: "creationTimeUnix")
  field(:creation_time_unix_present, 4, type: :bool, json_name: "creationTimeUnixPresent")
  field(:last_update_time_unix, 5, type: :int64, json_name: "lastUpdateTimeUnix")
  field(:last_update_time_unix_present, 6, type: :bool, json_name: "lastUpdateTimeUnixPresent")
  field(:distance, 7, type: :float)
  field(:distance_present, 8, type: :bool, json_name: "distancePresent")
  field(:certainty, 9, type: :float)
  field(:certainty_present, 10, type: :bool, json_name: "certaintyPresent")
  field(:score, 11, type: :float)
  field(:score_present, 12, type: :bool, json_name: "scorePresent")
  field(:explain_score, 13, type: :string, json_name: "explainScore")
  field(:explain_score_present, 14, type: :bool, json_name: "explainScorePresent")
  field(:is_consistent, 15, proto3_optional: true, type: :bool, json_name: "isConsistent")
  field(:generative, 16, type: :string, deprecated: true)
  field(:generative_present, 17, type: :bool, json_name: "generativePresent", deprecated: true)
  field(:is_consistent_present, 18, type: :bool, json_name: "isConsistentPresent")
  field(:vector_bytes, 19, type: :bytes, json_name: "vectorBytes")
  field(:id_as_bytes, 20, type: :bytes, json_name: "idAsBytes")
  field(:rerank_score, 21, type: :double, json_name: "rerankScore")
  field(:rerank_score_present, 22, type: :bool, json_name: "rerankScorePresent")
  field(:vectors, 23, repeated: true, type: Weaviate.V1.Vectors)
end

defmodule Weaviate.V1.PropertiesResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:ref_props, 2,
    repeated: true,
    type: Weaviate.V1.RefPropertiesResult,
    json_name: "refProps"
  )

  field(:target_collection, 3, type: :string, json_name: "targetCollection")
  field(:metadata, 4, type: Weaviate.V1.MetadataResult)
  field(:non_ref_props, 11, type: Weaviate.V1.Properties, json_name: "nonRefProps")
  field(:ref_props_requested, 12, type: :bool, json_name: "refPropsRequested")
end

defmodule Weaviate.V1.RefPropertiesResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:properties, 1, repeated: true, type: Weaviate.V1.PropertiesResult)
  field(:prop_name, 2, type: :string, json_name: "propName")
end
