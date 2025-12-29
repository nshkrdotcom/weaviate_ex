defmodule Weaviate.V1.Properties.FieldsEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: Weaviate.V1.Value)
end

defmodule Weaviate.V1.Properties do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:fields, 1, repeated: true, type: Weaviate.V1.Properties.FieldsEntry, map: true)
end

defmodule Weaviate.V1.Value do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:kind, 0)

  field(:number_value, 1, type: :double, json_name: "numberValue", oneof: 0)
  field(:bool_value, 3, type: :bool, json_name: "boolValue", oneof: 0)
  field(:object_value, 4, type: Weaviate.V1.Properties, json_name: "objectValue", oneof: 0)
  field(:list_value, 5, type: Weaviate.V1.ListValue, json_name: "listValue", oneof: 0)
  field(:date_value, 6, type: :string, json_name: "dateValue", oneof: 0)
  field(:uuid_value, 7, type: :string, json_name: "uuidValue", oneof: 0)
  field(:int_value, 8, type: :int64, json_name: "intValue", oneof: 0)
  field(:geo_value, 9, type: Weaviate.V1.GeoCoordinate, json_name: "geoValue", oneof: 0)
  field(:blob_value, 10, type: :string, json_name: "blobValue", oneof: 0)
  field(:phone_value, 11, type: Weaviate.V1.PhoneNumber, json_name: "phoneValue", oneof: 0)

  field(:null_value, 12,
    type: Google.Protobuf.NullValue,
    json_name: "nullValue",
    enum: true,
    oneof: 0
  )

  field(:text_value, 13, type: :string, json_name: "textValue", oneof: 0)
end

defmodule Weaviate.V1.ListValue do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:kind, 0)

  field(:number_values, 2, type: Weaviate.V1.NumberValues, json_name: "numberValues", oneof: 0)
  field(:bool_values, 3, type: Weaviate.V1.BoolValues, json_name: "boolValues", oneof: 0)
  field(:object_values, 4, type: Weaviate.V1.ObjectValues, json_name: "objectValues", oneof: 0)
  field(:date_values, 5, type: Weaviate.V1.DateValues, json_name: "dateValues", oneof: 0)
  field(:uuid_values, 6, type: Weaviate.V1.UuidValues, json_name: "uuidValues", oneof: 0)
  field(:int_values, 7, type: Weaviate.V1.IntValues, json_name: "intValues", oneof: 0)
  field(:text_values, 8, type: Weaviate.V1.TextValues, json_name: "textValues", oneof: 0)
end

defmodule Weaviate.V1.NumberValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, type: :bytes)
end

defmodule Weaviate.V1.TextValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
end

defmodule Weaviate.V1.BoolValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :bool)
end

defmodule Weaviate.V1.ObjectValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Weaviate.V1.Properties)
end

defmodule Weaviate.V1.DateValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
end

defmodule Weaviate.V1.UuidValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, repeated: true, type: :string)
end

defmodule Weaviate.V1.IntValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:values, 1, type: :bytes)
end

defmodule Weaviate.V1.GeoCoordinate do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:longitude, 1, type: :float)
  field(:latitude, 2, type: :float)
end

defmodule Weaviate.V1.PhoneNumber do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:country_code, 1, type: :uint64, json_name: "countryCode")
  field(:default_country, 2, type: :string, json_name: "defaultCountry")
  field(:input, 3, type: :string)
  field(:international_formatted, 4, type: :string, json_name: "internationalFormatted")
  field(:national, 5, type: :uint64)
  field(:national_formatted, 6, type: :string, json_name: "nationalFormatted")
  field(:valid, 7, type: :bool)
end
