defmodule Weaviate.V1.WeaviateHealthCheckResponse.ServingStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:UNKNOWN, 0)
  field(:SERVING, 1)
  field(:NOT_SERVING, 2)
end

defmodule Weaviate.V1.WeaviateHealthCheckRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:service, 1, type: :string)
end

defmodule Weaviate.V1.WeaviateHealthCheckResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:status, 1, type: Weaviate.V1.WeaviateHealthCheckResponse.ServingStatus, enum: true)
end
