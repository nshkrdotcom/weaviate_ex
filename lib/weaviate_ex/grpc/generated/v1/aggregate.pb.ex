defmodule Weaviate.V1.AggregateRequest.Aggregation.Integer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, type: :bool)
  field(:type, 2, type: :bool)
  field(:sum, 3, type: :bool)
  field(:mean, 4, type: :bool)
  field(:mode, 5, type: :bool)
  field(:median, 6, type: :bool)
  field(:maximum, 7, type: :bool)
  field(:minimum, 8, type: :bool)
end

defmodule Weaviate.V1.AggregateRequest.Aggregation.Number do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, type: :bool)
  field(:type, 2, type: :bool)
  field(:sum, 3, type: :bool)
  field(:mean, 4, type: :bool)
  field(:mode, 5, type: :bool)
  field(:median, 6, type: :bool)
  field(:maximum, 7, type: :bool)
  field(:minimum, 8, type: :bool)
end

defmodule Weaviate.V1.AggregateRequest.Aggregation.Text do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, type: :bool)
  field(:type, 2, type: :bool)
  field(:top_occurences, 3, type: :bool, json_name: "topOccurences")

  field(:top_occurences_limit, 4,
    proto3_optional: true,
    type: :uint32,
    json_name: "topOccurencesLimit"
  )
end

defmodule Weaviate.V1.AggregateRequest.Aggregation.Boolean do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, type: :bool)
  field(:type, 2, type: :bool)
  field(:total_true, 3, type: :bool, json_name: "totalTrue")
  field(:total_false, 4, type: :bool, json_name: "totalFalse")
  field(:percentage_true, 5, type: :bool, json_name: "percentageTrue")
  field(:percentage_false, 6, type: :bool, json_name: "percentageFalse")
end

defmodule Weaviate.V1.AggregateRequest.Aggregation.Date do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, type: :bool)
  field(:type, 2, type: :bool)
  field(:median, 3, type: :bool)
  field(:mode, 4, type: :bool)
  field(:maximum, 5, type: :bool)
  field(:minimum, 6, type: :bool)
end

defmodule Weaviate.V1.AggregateRequest.Aggregation.Reference do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:type, 1, type: :bool)
  field(:pointing_to, 2, type: :bool, json_name: "pointingTo")
end

defmodule Weaviate.V1.AggregateRequest.Aggregation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:aggregation, 0)

  field(:property, 1, type: :string)
  field(:int, 2, type: Weaviate.V1.AggregateRequest.Aggregation.Integer, oneof: 0)
  field(:number, 3, type: Weaviate.V1.AggregateRequest.Aggregation.Number, oneof: 0)
  field(:text, 4, type: Weaviate.V1.AggregateRequest.Aggregation.Text, oneof: 0)
  field(:boolean, 5, type: Weaviate.V1.AggregateRequest.Aggregation.Boolean, oneof: 0)
  field(:date, 6, type: Weaviate.V1.AggregateRequest.Aggregation.Date, oneof: 0)
  field(:reference, 7, type: Weaviate.V1.AggregateRequest.Aggregation.Reference, oneof: 0)
end

defmodule Weaviate.V1.AggregateRequest.GroupBy do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:collection, 1, type: :string)
  field(:property, 2, type: :string)
end

defmodule Weaviate.V1.AggregateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:search, 0)

  field(:collection, 1, type: :string)
  field(:tenant, 10, type: :string)
  field(:objects_count, 20, type: :bool, json_name: "objectsCount")
  field(:aggregations, 21, repeated: true, type: Weaviate.V1.AggregateRequest.Aggregation)
  field(:object_limit, 30, proto3_optional: true, type: :uint32, json_name: "objectLimit")

  field(:group_by, 31,
    proto3_optional: true,
    type: Weaviate.V1.AggregateRequest.GroupBy,
    json_name: "groupBy"
  )

  field(:limit, 32, proto3_optional: true, type: :uint32)
  field(:filters, 40, proto3_optional: true, type: Weaviate.V1.Filters)
  field(:hybrid, 41, type: Weaviate.V1.Hybrid, oneof: 0)
  field(:near_vector, 42, type: Weaviate.V1.NearVector, json_name: "nearVector", oneof: 0)
  field(:near_object, 43, type: Weaviate.V1.NearObject, json_name: "nearObject", oneof: 0)
  field(:near_text, 44, type: Weaviate.V1.NearTextSearch, json_name: "nearText", oneof: 0)
  field(:near_image, 45, type: Weaviate.V1.NearImageSearch, json_name: "nearImage", oneof: 0)
  field(:near_audio, 46, type: Weaviate.V1.NearAudioSearch, json_name: "nearAudio", oneof: 0)
  field(:near_video, 47, type: Weaviate.V1.NearVideoSearch, json_name: "nearVideo", oneof: 0)
  field(:near_depth, 48, type: Weaviate.V1.NearDepthSearch, json_name: "nearDepth", oneof: 0)

  field(:near_thermal, 49,
    type: Weaviate.V1.NearThermalSearch,
    json_name: "nearThermal",
    oneof: 0
  )

  field(:near_imu, 50, type: Weaviate.V1.NearIMUSearch, json_name: "nearImu", oneof: 0)
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Integer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, proto3_optional: true, type: :int64)
  field(:type, 2, proto3_optional: true, type: :string)
  field(:mean, 3, proto3_optional: true, type: :double)
  field(:median, 4, proto3_optional: true, type: :double)
  field(:mode, 5, proto3_optional: true, type: :int64)
  field(:maximum, 6, proto3_optional: true, type: :int64)
  field(:minimum, 7, proto3_optional: true, type: :int64)
  field(:sum, 8, proto3_optional: true, type: :int64)
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Number do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, proto3_optional: true, type: :int64)
  field(:type, 2, proto3_optional: true, type: :string)
  field(:mean, 3, proto3_optional: true, type: :double)
  field(:median, 4, proto3_optional: true, type: :double)
  field(:mode, 5, proto3_optional: true, type: :double)
  field(:maximum, 6, proto3_optional: true, type: :double)
  field(:minimum, 7, proto3_optional: true, type: :double)
  field(:sum, 8, proto3_optional: true, type: :double)
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text.TopOccurrences.TopOccurrence do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:value, 1, type: :string)
  field(:occurs, 2, type: :int64)
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text.TopOccurrences do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:items, 1,
    repeated: true,
    type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text.TopOccurrences.TopOccurrence
  )
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, proto3_optional: true, type: :int64)
  field(:type, 2, proto3_optional: true, type: :string)

  field(:top_occurences, 3,
    proto3_optional: true,
    type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text.TopOccurrences,
    json_name: "topOccurences"
  )
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Boolean do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, proto3_optional: true, type: :int64)
  field(:type, 2, proto3_optional: true, type: :string)
  field(:total_true, 3, proto3_optional: true, type: :int64, json_name: "totalTrue")
  field(:total_false, 4, proto3_optional: true, type: :int64, json_name: "totalFalse")
  field(:percentage_true, 5, proto3_optional: true, type: :double, json_name: "percentageTrue")
  field(:percentage_false, 6, proto3_optional: true, type: :double, json_name: "percentageFalse")
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Date do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:count, 1, proto3_optional: true, type: :int64)
  field(:type, 2, proto3_optional: true, type: :string)
  field(:median, 3, proto3_optional: true, type: :string)
  field(:mode, 4, proto3_optional: true, type: :string)
  field(:maximum, 5, proto3_optional: true, type: :string)
  field(:minimum, 6, proto3_optional: true, type: :string)
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation.Reference do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:type, 1, proto3_optional: true, type: :string)
  field(:pointing_to, 2, repeated: true, type: :string, json_name: "pointingTo")
end

defmodule Weaviate.V1.AggregateReply.Aggregations.Aggregation do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:aggregation, 0)

  field(:property, 1, type: :string)
  field(:int, 2, type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Integer, oneof: 0)
  field(:number, 3, type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Number, oneof: 0)
  field(:text, 4, type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Text, oneof: 0)
  field(:boolean, 5, type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Boolean, oneof: 0)
  field(:date, 6, type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Date, oneof: 0)

  field(:reference, 7,
    type: Weaviate.V1.AggregateReply.Aggregations.Aggregation.Reference,
    oneof: 0
  )
end

defmodule Weaviate.V1.AggregateReply.Aggregations do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:aggregations, 1,
    repeated: true,
    type: Weaviate.V1.AggregateReply.Aggregations.Aggregation
  )
end

defmodule Weaviate.V1.AggregateReply.Single do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:objects_count, 1, proto3_optional: true, type: :int64, json_name: "objectsCount")
  field(:aggregations, 2, proto3_optional: true, type: Weaviate.V1.AggregateReply.Aggregations)
end

defmodule Weaviate.V1.AggregateReply.Group.GroupedBy do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:value, 0)

  field(:path, 1, repeated: true, type: :string)
  field(:text, 2, type: :string, oneof: 0)
  field(:int, 3, type: :int64, oneof: 0)
  field(:boolean, 4, type: :bool, oneof: 0)
  field(:number, 5, type: :double, oneof: 0)
  field(:texts, 6, type: Weaviate.V1.TextArray, oneof: 0)
  field(:ints, 7, type: Weaviate.V1.IntArray, oneof: 0)
  field(:booleans, 8, type: Weaviate.V1.BooleanArray, oneof: 0)
  field(:numbers, 9, type: Weaviate.V1.NumberArray, oneof: 0)
  field(:geo, 10, type: Weaviate.V1.GeoCoordinatesFilter, oneof: 0)
end

defmodule Weaviate.V1.AggregateReply.Group do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:objects_count, 1, proto3_optional: true, type: :int64, json_name: "objectsCount")
  field(:aggregations, 2, proto3_optional: true, type: Weaviate.V1.AggregateReply.Aggregations)

  field(:grouped_by, 3,
    proto3_optional: true,
    type: Weaviate.V1.AggregateReply.Group.GroupedBy,
    json_name: "groupedBy"
  )
end

defmodule Weaviate.V1.AggregateReply.Grouped do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:groups, 1, repeated: true, type: Weaviate.V1.AggregateReply.Group)
end

defmodule Weaviate.V1.AggregateReply do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:result, 0)

  field(:took, 1, type: :float)

  field(:single_result, 2,
    type: Weaviate.V1.AggregateReply.Single,
    json_name: "singleResult",
    oneof: 0
  )

  field(:grouped_results, 3,
    type: Weaviate.V1.AggregateReply.Grouped,
    json_name: "groupedResults",
    oneof: 0
  )
end
