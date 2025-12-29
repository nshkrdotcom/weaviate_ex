defmodule Weaviate.V1.CombinationMethod do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:COMBINATION_METHOD_UNSPECIFIED, 0)
  field(:COMBINATION_METHOD_TYPE_SUM, 1)
  field(:COMBINATION_METHOD_TYPE_MIN, 2)
  field(:COMBINATION_METHOD_TYPE_AVERAGE, 3)
  field(:COMBINATION_METHOD_TYPE_RELATIVE_SCORE, 4)
  field(:COMBINATION_METHOD_TYPE_MANUAL, 5)
end

defmodule Weaviate.V1.SearchOperatorOptions.Operator do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:OPERATOR_UNSPECIFIED, 0)
  field(:OPERATOR_OR, 1)
  field(:OPERATOR_AND, 2)
end

defmodule Weaviate.V1.Hybrid.FusionType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:FUSION_TYPE_UNSPECIFIED, 0)
  field(:FUSION_TYPE_RANKED, 1)
  field(:FUSION_TYPE_RELATIVE_SCORE, 2)
end

defmodule Weaviate.V1.WeightsForTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:target, 1, type: :string)
  field(:weight, 2, type: :float)
end

defmodule Weaviate.V1.Targets do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:target_vectors, 1, repeated: true, type: :string, json_name: "targetVectors")
  field(:combination, 2, type: Weaviate.V1.CombinationMethod, enum: true)

  field(:weights_for_targets, 4,
    repeated: true,
    type: Weaviate.V1.WeightsForTarget,
    json_name: "weightsForTargets"
  )
end

defmodule Weaviate.V1.VectorForTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:vector_bytes, 2, type: :bytes, json_name: "vectorBytes", deprecated: true)
  field(:vectors, 3, repeated: true, type: Weaviate.V1.Vectors)
end

defmodule Weaviate.V1.SearchOperatorOptions do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:operator, 1, type: Weaviate.V1.SearchOperatorOptions.Operator, enum: true)

  field(:minimum_or_tokens_match, 2,
    proto3_optional: true,
    type: :int32,
    json_name: "minimumOrTokensMatch"
  )
end

defmodule Weaviate.V1.Hybrid do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:threshold, 0)

  field(:query, 1, type: :string)
  field(:properties, 2, repeated: true, type: :string)
  field(:vector, 3, repeated: true, type: :float, deprecated: true)
  field(:alpha, 4, type: :float)
  field(:fusion_type, 5, type: Weaviate.V1.Hybrid.FusionType, json_name: "fusionType", enum: true)
  field(:vector_bytes, 6, type: :bytes, json_name: "vectorBytes", deprecated: true)

  field(:target_vectors, 7,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:near_text, 8, type: Weaviate.V1.NearTextSearch, json_name: "nearText")
  field(:near_vector, 9, type: Weaviate.V1.NearVector, json_name: "nearVector")
  field(:targets, 10, type: Weaviate.V1.Targets)

  field(:bm25_search_operator, 11,
    proto3_optional: true,
    type: Weaviate.V1.SearchOperatorOptions,
    json_name: "bm25SearchOperator"
  )

  field(:vector_distance, 20, type: :float, json_name: "vectorDistance", oneof: 0)
  field(:vectors, 21, repeated: true, type: Weaviate.V1.Vectors)
end

defmodule Weaviate.V1.NearVector.VectorPerTargetEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: :bytes)
end

defmodule Weaviate.V1.NearVector do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:vector, 1, repeated: true, type: :float, deprecated: true)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)
  field(:vector_bytes, 4, type: :bytes, json_name: "vectorBytes", deprecated: true)

  field(:target_vectors, 5,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 6, type: Weaviate.V1.Targets)

  field(:vector_per_target, 7,
    repeated: true,
    type: Weaviate.V1.NearVector.VectorPerTargetEntry,
    json_name: "vectorPerTarget",
    map: true,
    deprecated: true
  )

  field(:vector_for_targets, 8,
    repeated: true,
    type: Weaviate.V1.VectorForTarget,
    json_name: "vectorForTargets"
  )

  field(:vectors, 9, repeated: true, type: Weaviate.V1.Vectors)
end

defmodule Weaviate.V1.NearObject do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearTextSearch.Move do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:force, 1, type: :float)
  field(:concepts, 2, repeated: true, type: :string)
  field(:uuids, 3, repeated: true, type: :string)
end

defmodule Weaviate.V1.NearTextSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:query, 1, repeated: true, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:move_to, 4,
    proto3_optional: true,
    type: Weaviate.V1.NearTextSearch.Move,
    json_name: "moveTo"
  )

  field(:move_away, 5,
    proto3_optional: true,
    type: Weaviate.V1.NearTextSearch.Move,
    json_name: "moveAway"
  )

  field(:target_vectors, 6,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 7, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearImageSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:image, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearAudioSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:audio, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearVideoSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:video, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearDepthSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:depth, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearThermalSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:thermal, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.NearIMUSearch do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:imu, 1, type: :string)
  field(:certainty, 2, proto3_optional: true, type: :double)
  field(:distance, 3, proto3_optional: true, type: :double)

  field(:target_vectors, 4,
    repeated: true,
    type: :string,
    json_name: "targetVectors",
    deprecated: true
  )

  field(:targets, 5, type: Weaviate.V1.Targets)
end

defmodule Weaviate.V1.BM25 do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:query, 1, type: :string)
  field(:properties, 2, repeated: true, type: :string)

  field(:search_operator, 3,
    proto3_optional: true,
    type: Weaviate.V1.SearchOperatorOptions,
    json_name: "searchOperator"
  )
end
