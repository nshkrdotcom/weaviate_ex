defmodule Weaviate.V1.BatchDeleteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:collection, 1, type: :string)
  field(:filters, 2, type: Weaviate.V1.Filters)
  field(:verbose, 3, type: :bool)
  field(:dry_run, 4, type: :bool, json_name: "dryRun")

  field(:consistency_level, 5,
    proto3_optional: true,
    type: Weaviate.V1.ConsistencyLevel,
    json_name: "consistencyLevel",
    enum: true
  )

  field(:tenant, 6, proto3_optional: true, type: :string)
end

defmodule Weaviate.V1.BatchDeleteReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:took, 1, type: :float)
  field(:failed, 2, type: :int64)
  field(:matches, 3, type: :int64)
  field(:successful, 4, type: :int64)
  field(:objects, 5, repeated: true, type: Weaviate.V1.BatchDeleteObject)
end

defmodule Weaviate.V1.BatchDeleteObject do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:uuid, 1, type: :bytes)
  field(:successful, 2, type: :bool)
  field(:error, 3, proto3_optional: true, type: :string)
end
