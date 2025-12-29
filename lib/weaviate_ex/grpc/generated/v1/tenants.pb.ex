defmodule Weaviate.V1.TenantActivityStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:TENANT_ACTIVITY_STATUS_UNSPECIFIED, 0)
  field(:TENANT_ACTIVITY_STATUS_HOT, 1)
  field(:TENANT_ACTIVITY_STATUS_COLD, 2)
  field(:TENANT_ACTIVITY_STATUS_FROZEN, 4)
  field(:TENANT_ACTIVITY_STATUS_UNFREEZING, 5)
  field(:TENANT_ACTIVITY_STATUS_FREEZING, 6)
  field(:TENANT_ACTIVITY_STATUS_ACTIVE, 7)
  field(:TENANT_ACTIVITY_STATUS_INACTIVE, 8)
  field(:TENANT_ACTIVITY_STATUS_OFFLOADED, 9)
  field(:TENANT_ACTIVITY_STATUS_OFFLOADING, 10)
  field(:TENANT_ACTIVITY_STATUS_ONLOADING, 11)
end

defmodule Weaviate.V1.TenantsGetRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:params, 0)

  field(:collection, 1, type: :string)
  field(:names, 2, type: Weaviate.V1.TenantNames, oneof: 0)
end

defmodule Weaviate.V1.TenantNames do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
end

defmodule Weaviate.V1.TenantsGetReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:took, 1, type: :float)
  field(:tenants, 2, repeated: true, type: Weaviate.V1.Tenant)
end

defmodule Weaviate.V1.Tenant do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:name, 1, type: :string)

  field(:activity_status, 2,
    type: Weaviate.V1.TenantActivityStatus,
    json_name: "activityStatus",
    enum: true
  )
end
