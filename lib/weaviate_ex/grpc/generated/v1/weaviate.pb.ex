defmodule Weaviate.V1.Weaviate.Service do
  @moduledoc false

  use GRPC.Service, name: "weaviate.v1.Weaviate", protoc_gen_elixir_version: "0.15.0"

  rpc(:Search, Weaviate.V1.SearchRequest, Weaviate.V1.SearchReply)

  rpc(:BatchObjects, Weaviate.V1.BatchObjectsRequest, Weaviate.V1.BatchObjectsReply)

  rpc(:BatchReferences, Weaviate.V1.BatchReferencesRequest, Weaviate.V1.BatchReferencesReply)

  rpc(:BatchDelete, Weaviate.V1.BatchDeleteRequest, Weaviate.V1.BatchDeleteReply)

  rpc(:TenantsGet, Weaviate.V1.TenantsGetRequest, Weaviate.V1.TenantsGetReply)

  rpc(:Aggregate, Weaviate.V1.AggregateRequest, Weaviate.V1.AggregateReply)

  rpc(:BatchStream, stream(Weaviate.V1.BatchStreamRequest), stream(Weaviate.V1.BatchStreamReply))
end

defmodule Weaviate.V1.Weaviate.Stub do
  @moduledoc false

  use GRPC.Stub, service: Weaviate.V1.Weaviate.Service
end
