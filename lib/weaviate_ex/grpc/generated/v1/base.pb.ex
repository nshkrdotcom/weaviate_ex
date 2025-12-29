defmodule Weaviate.V1.ConsistencyLevel do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:CONSISTENCY_LEVEL_UNSPECIFIED, 0)
  field(:CONSISTENCY_LEVEL_ONE, 1)
  field(:CONSISTENCY_LEVEL_QUORUM, 2)
  field(:CONSISTENCY_LEVEL_ALL, 3)
end

defmodule Weaviate.V1.Filters.Operator do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:OPERATOR_UNSPECIFIED, 0)
  field(:OPERATOR_EQUAL, 1)
  field(:OPERATOR_NOT_EQUAL, 2)
  field(:OPERATOR_GREATER_THAN, 3)
  field(:OPERATOR_GREATER_THAN_EQUAL, 4)
  field(:OPERATOR_LESS_THAN, 5)
  field(:OPERATOR_LESS_THAN_EQUAL, 6)
  field(:OPERATOR_AND, 7)
  field(:OPERATOR_OR, 8)
  field(:OPERATOR_WITHIN_GEO_RANGE, 9)
  field(:OPERATOR_LIKE, 10)
  field(:OPERATOR_IS_NULL, 11)
  field(:OPERATOR_CONTAINS_ANY, 12)
  field(:OPERATOR_CONTAINS_ALL, 13)
  field(:OPERATOR_CONTAINS_NONE, 14)
  field(:OPERATOR_NOT, 15)
end

defmodule Weaviate.V1.Vectors.VectorType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:VECTOR_TYPE_UNSPECIFIED, 0)
  field(:VECTOR_TYPE_SINGLE_FP32, 1)
  field(:VECTOR_TYPE_MULTI_FP32, 2)
end

defmodule Weaviate.V1.NumberArrayProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :double, deprecated: true)
  field(:prop_name, 2, type: :string, json_name: "propName")
  field(:values_bytes, 3, type: :bytes, json_name: "valuesBytes")
end

defmodule Weaviate.V1.IntArrayProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :int64)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.TextArrayProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.BooleanArrayProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :bool)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.ObjectPropertiesValue do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:non_ref_properties, 1, type: Google.Protobuf.Struct, json_name: "nonRefProperties")

  field(:number_array_properties, 2,
    repeated: true,
    type: Weaviate.V1.NumberArrayProperties,
    json_name: "numberArrayProperties"
  )

  field(:int_array_properties, 3,
    repeated: true,
    type: Weaviate.V1.IntArrayProperties,
    json_name: "intArrayProperties"
  )

  field(:text_array_properties, 4,
    repeated: true,
    type: Weaviate.V1.TextArrayProperties,
    json_name: "textArrayProperties"
  )

  field(:boolean_array_properties, 5,
    repeated: true,
    type: Weaviate.V1.BooleanArrayProperties,
    json_name: "booleanArrayProperties"
  )

  field(:object_properties, 6,
    repeated: true,
    type: Weaviate.V1.ObjectProperties,
    json_name: "objectProperties"
  )

  field(:object_array_properties, 7,
    repeated: true,
    type: Weaviate.V1.ObjectArrayProperties,
    json_name: "objectArrayProperties"
  )

  field(:empty_list_props, 10, repeated: true, type: :string, json_name: "emptyListProps")
end

defmodule Weaviate.V1.ObjectArrayProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Weaviate.V1.ObjectPropertiesValue)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.ObjectProperties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:value, 1, type: Weaviate.V1.ObjectPropertiesValue)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.TextArray do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
end

defmodule Weaviate.V1.IntArray do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :int64)
end

defmodule Weaviate.V1.NumberArray do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :double)
end

defmodule Weaviate.V1.BooleanArray do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :bool)
end

defmodule Weaviate.V1.Filters do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:test_value, 0)

  field(:operator, 1, type: Weaviate.V1.Filters.Operator, enum: true)
  field(:on, 2, repeated: true, type: :string, deprecated: true)
  field(:filters, 3, repeated: true, type: Weaviate.V1.Filters)
  field(:value_text, 4, type: :string, json_name: "valueText", oneof: 0)
  field(:value_int, 5, type: :int64, json_name: "valueInt", oneof: 0)
  field(:value_boolean, 6, type: :bool, json_name: "valueBoolean", oneof: 0)
  field(:value_number, 7, type: :double, json_name: "valueNumber", oneof: 0)
  field(:value_text_array, 9, type: Weaviate.V1.TextArray, json_name: "valueTextArray", oneof: 0)
  field(:value_int_array, 10, type: Weaviate.V1.IntArray, json_name: "valueIntArray", oneof: 0)

  field(:value_boolean_array, 11,
    type: Weaviate.V1.BooleanArray,
    json_name: "valueBooleanArray",
    oneof: 0
  )

  field(:value_number_array, 12,
    type: Weaviate.V1.NumberArray,
    json_name: "valueNumberArray",
    oneof: 0
  )

  field(:value_geo, 13, type: Weaviate.V1.GeoCoordinatesFilter, json_name: "valueGeo", oneof: 0)
  field(:target, 20, type: Weaviate.V1.FilterTarget)
end

defmodule Weaviate.V1.FilterReferenceSingleTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:on, 1, type: :string)
  field(:target, 2, type: Weaviate.V1.FilterTarget)
end

defmodule Weaviate.V1.FilterReferenceMultiTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:on, 1, type: :string)
  field(:target, 2, type: Weaviate.V1.FilterTarget)
  field(:target_collection, 3, type: :string, json_name: "targetCollection")
end

defmodule Weaviate.V1.FilterReferenceCount do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:on, 1, type: :string)
end

defmodule Weaviate.V1.FilterTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:target, 0)

  field(:property, 1, type: :string, oneof: 0)

  field(:single_target, 2,
    type: Weaviate.V1.FilterReferenceSingleTarget,
    json_name: "singleTarget",
    oneof: 0
  )

  field(:multi_target, 3,
    type: Weaviate.V1.FilterReferenceMultiTarget,
    json_name: "multiTarget",
    oneof: 0
  )

  field(:count, 4, type: Weaviate.V1.FilterReferenceCount, oneof: 0)
end

defmodule Weaviate.V1.GeoCoordinatesFilter do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:latitude, 1, type: :float)
  field(:longitude, 2, type: :float)
  field(:distance, 3, type: :float)
end

defmodule Weaviate.V1.Vectors do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:index, 2, type: :uint64, deprecated: true)
  field(:vector_bytes, 3, type: :bytes, json_name: "vectorBytes")
  field(:type, 4, type: Weaviate.V1.Vectors.VectorType, enum: true)
end
