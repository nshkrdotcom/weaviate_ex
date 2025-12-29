defmodule Weaviate.V1.BatchObjectsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:objects, 1, repeated: true, type: Weaviate.V1.BatchObject)

  field(:consistency_level, 2,
    proto3_optional: true,
    type: Weaviate.V1.ConsistencyLevel,
    json_name: "consistencyLevel",
    enum: true
  )
end

defmodule Weaviate.V1.BatchReferencesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:references, 1, repeated: true, type: Weaviate.V1.BatchReference)

  field(:consistency_level, 2,
    proto3_optional: true,
    type: Weaviate.V1.ConsistencyLevel,
    json_name: "consistencyLevel",
    enum: true
  )
end

defmodule Weaviate.V1.BatchStreamRequest.Start do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:consistency_level, 1,
    proto3_optional: true,
    type: Weaviate.V1.ConsistencyLevel,
    json_name: "consistencyLevel",
    enum: true
  )
end

defmodule Weaviate.V1.BatchStreamRequest.Stop do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.BatchStreamRequest.Data.Objects do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Weaviate.V1.BatchObject)
end

defmodule Weaviate.V1.BatchStreamRequest.Data.References do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Weaviate.V1.BatchReference)
end

defmodule Weaviate.V1.BatchStreamRequest.Data do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:objects, 1, type: Weaviate.V1.BatchStreamRequest.Data.Objects)
  field(:references, 2, type: Weaviate.V1.BatchStreamRequest.Data.References)
end

defmodule Weaviate.V1.BatchStreamRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:message, 0)

  field(:start, 1, type: Weaviate.V1.BatchStreamRequest.Start, oneof: 0)
  field(:data, 2, type: Weaviate.V1.BatchStreamRequest.Data, oneof: 0)
  field(:stop, 3, type: Weaviate.V1.BatchStreamRequest.Stop, oneof: 0)
end

defmodule Weaviate.V1.BatchStreamReply.Started do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.BatchStreamReply.ShuttingDown do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.BatchStreamReply.Shutdown do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3
end

defmodule Weaviate.V1.BatchStreamReply.Backoff do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:batch_size, 1, type: :int32, json_name: "batchSize")
end

defmodule Weaviate.V1.BatchStreamReply.Acks do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuids, 1, repeated: true, type: :string)
  field(:beacons, 2, repeated: true, type: :string)
end

defmodule Weaviate.V1.BatchStreamReply.Results.Error do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:detail, 0)

  field(:error, 1, type: :string)
  field(:uuid, 2, type: :string, oneof: 0)
  field(:beacon, 3, type: :string, oneof: 0)
end

defmodule Weaviate.V1.BatchStreamReply.Results.Success do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:detail, 0)

  field(:uuid, 2, type: :string, oneof: 0)
  field(:beacon, 3, type: :string, oneof: 0)
end

defmodule Weaviate.V1.BatchStreamReply.Results do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:errors, 1, repeated: true, type: Weaviate.V1.BatchStreamReply.Results.Error)
  field(:successes, 2, repeated: true, type: Weaviate.V1.BatchStreamReply.Results.Success)
end

defmodule Weaviate.V1.BatchStreamReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:message, 0)

  field(:results, 1, type: Weaviate.V1.BatchStreamReply.Results, oneof: 0)

  field(:shutting_down, 2,
    type: Weaviate.V1.BatchStreamReply.ShuttingDown,
    json_name: "shuttingDown",
    oneof: 0
  )

  field(:shutdown, 3, type: Weaviate.V1.BatchStreamReply.Shutdown, oneof: 0)
  field(:started, 4, type: Weaviate.V1.BatchStreamReply.Started, oneof: 0)
  field(:backoff, 5, type: Weaviate.V1.BatchStreamReply.Backoff, oneof: 0)
  field(:acks, 6, type: Weaviate.V1.BatchStreamReply.Acks, oneof: 0)
end

defmodule Weaviate.V1.BatchObject.Properties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:non_ref_properties, 1, type: Google.Protobuf.Struct, json_name: "nonRefProperties")

  field(:single_target_ref_props, 2,
    repeated: true,
    type: Weaviate.V1.BatchObject.SingleTargetRefProps,
    json_name: "singleTargetRefProps"
  )

  field(:multi_target_ref_props, 3,
    repeated: true,
    type: Weaviate.V1.BatchObject.MultiTargetRefProps,
    json_name: "multiTargetRefProps"
  )

  field(:number_array_properties, 4,
    repeated: true,
    type: Weaviate.V1.NumberArrayProperties,
    json_name: "numberArrayProperties"
  )

  field(:int_array_properties, 5,
    repeated: true,
    type: Weaviate.V1.IntArrayProperties,
    json_name: "intArrayProperties"
  )

  field(:text_array_properties, 6,
    repeated: true,
    type: Weaviate.V1.TextArrayProperties,
    json_name: "textArrayProperties"
  )

  field(:boolean_array_properties, 7,
    repeated: true,
    type: Weaviate.V1.BooleanArrayProperties,
    json_name: "booleanArrayProperties"
  )

  field(:object_properties, 8,
    repeated: true,
    type: Weaviate.V1.ObjectProperties,
    json_name: "objectProperties"
  )

  field(:object_array_properties, 9,
    repeated: true,
    type: Weaviate.V1.ObjectArrayProperties,
    json_name: "objectArrayProperties"
  )

  field(:empty_list_props, 10, repeated: true, type: :string, json_name: "emptyListProps")
end

defmodule Weaviate.V1.BatchObject.SingleTargetRefProps do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuids, 1, repeated: true, type: :string)
  field(:prop_name, 2, type: :string, json_name: "propName")
end

defmodule Weaviate.V1.BatchObject.MultiTargetRefProps do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuids, 1, repeated: true, type: :string)
  field(:prop_name, 2, type: :string, json_name: "propName")
  field(:target_collection, 3, type: :string, json_name: "targetCollection")
end

defmodule Weaviate.V1.BatchObject do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuid, 1, type: :string)
  field(:vector, 2, repeated: true, type: :float, deprecated: true)
  field(:properties, 3, type: Weaviate.V1.BatchObject.Properties)
  field(:collection, 4, type: :string)
  field(:tenant, 5, type: :string)
  field(:vector_bytes, 6, type: :bytes, json_name: "vectorBytes")
  field(:vectors, 23, repeated: true, type: Weaviate.V1.Vectors)
end

defmodule Weaviate.V1.BatchReference do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:from_collection, 2, type: :string, json_name: "fromCollection")
  field(:from_uuid, 3, type: :string, json_name: "fromUuid")
  field(:to_collection, 4, proto3_optional: true, type: :string, json_name: "toCollection")
  field(:to_uuid, 5, type: :string, json_name: "toUuid")
  field(:tenant, 6, type: :string)
end

defmodule Weaviate.V1.BatchObjectsReply.BatchError do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:index, 1, type: :int32)
  field(:error, 2, type: :string)
end

defmodule Weaviate.V1.BatchObjectsReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:took, 1, type: :float)
  field(:errors, 2, repeated: true, type: Weaviate.V1.BatchObjectsReply.BatchError)
end

defmodule Weaviate.V1.BatchReferencesReply.BatchError do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:index, 1, type: :int32)
  field(:error, 2, type: :string)
end

defmodule Weaviate.V1.BatchReferencesReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:took, 1, type: :float)
  field(:errors, 2, repeated: true, type: Weaviate.V1.BatchReferencesReply.BatchError)
end
