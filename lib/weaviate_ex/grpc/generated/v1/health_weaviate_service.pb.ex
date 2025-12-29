defmodule Weaviate.V1.WeaviateHealth.Service do
  @moduledoc false

  use GRPC.Service, name: "weaviate.v1.WeaviateHealth", protoc_gen_elixir_version: "0.15.0"

  rpc(:Check, Weaviate.V1.WeaviateHealthCheckRequest, Weaviate.V1.WeaviateHealthCheckResponse)
end

defmodule Weaviate.V1.WeaviateHealth.Stub do
  @moduledoc false

  use GRPC.Stub, service: Weaviate.V1.WeaviateHealth.Service
end
