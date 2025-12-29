defmodule WeaviateEx.GRPC.Services.Aggregate do
  @moduledoc """
  gRPC Aggregate service for aggregation queries.

  This module provides high-level functions for performing aggregations
  on Weaviate collections using gRPC.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      {:ok, result} = Aggregate.count(channel, "Article")
      {:ok, result} = Aggregate.over_property(channel, "Article", "wordCount",
        aggregations: [:sum, :mean, :minimum, :maximum]
      )
  """

  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel

  alias Weaviate.V1.AggregateRequest

  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @type aggregate_opts :: [
          tenant: String.t(),
          filters: map(),
          group_by: String.t() | [String.t()],
          near_vector: [float()],
          near_text: String.t(),
          aggregations: [atom()],
          limit: non_neg_integer(),
          timeout: non_neg_integer()
        ]

  @doc """
  Count objects in a collection.

  ## Examples

      {:ok, result} = Aggregate.count(channel, "Article")
      {:ok, result} = Aggregate.count(channel, "Article", tenant: "tenant_a")
  """
  @spec count(GRPC.Channel.t(), String.t(), aggregate_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def count(channel, collection, opts \\ []) do
    request = build_aggregate_request(collection, opts)
    request = %{request | objects_count: true}

    execute_aggregate(channel, request, opts)
  end

  @doc """
  Aggregate over a specific property.

  ## Options

    * `:aggregations` - List of aggregation types to compute
      - For numbers: `:count`, `:sum`, `:mean`, `:median`, `:mode`, `:minimum`, `:maximum`
      - For text: `:count`, `:top_occurrences`
      - For boolean: `:count`, `:total_true`, `:total_false`, `:percentage_true`, `:percentage_false`

  ## Examples

      {:ok, result} = Aggregate.over_property(channel, "Article", "wordCount",
        aggregations: [:sum, :mean, :minimum, :maximum]
      )
  """
  @spec over_property(GRPC.Channel.t(), String.t(), String.t(), aggregate_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def over_property(channel, collection, property, opts \\ []) do
    aggregations = Keyword.get(opts, :aggregations, [:count])
    property_type = Keyword.get(opts, :property_type, :number)

    aggregation = build_aggregation(property, property_type, aggregations)

    request = build_aggregate_request(collection, opts)
    request = %{request | aggregations: [aggregation]}

    execute_aggregate(channel, request, opts)
  end

  @doc """
  Aggregate with grouping.

  ## Examples

      {:ok, result} = Aggregate.group_by(channel, "Article", "category",
        aggregations: [:count]
      )
  """
  @spec group_by(GRPC.Channel.t(), String.t(), String.t(), aggregate_opts()) ::
          {:ok, struct()} | {:error, Error.t()}
  def group_by(channel, collection, property, opts \\ []) do
    group_by = %AggregateRequest.GroupBy{
      collection: collection,
      property: property
    }

    request = build_aggregate_request(collection, opts)
    request = %{request | group_by: group_by, objects_count: true}

    execute_aggregate(channel, request, opts)
  end

  @doc """
  Execute a raw AggregateRequest.

  ## Examples

      request = %AggregateRequest{
        collection: "Article",
        count_by_meta: true
      }
      {:ok, result} = Aggregate.execute(channel, request)
  """
  @spec execute(GRPC.Channel.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, Error.t()}
  def execute(channel, %AggregateRequest{} = request, opts \\ []) do
    execute_aggregate(channel, request, opts)
  end

  # Private functions

  defp build_aggregate_request(collection, opts) do
    base = %AggregateRequest{
      collection: collection,
      tenant: Keyword.get(opts, :tenant, ""),
      filters: build_filter(Keyword.get(opts, :filters))
    }

    # Add search oneof if specified
    cond do
      near_vector = Keyword.get(opts, :near_vector) ->
        %{base | search: {:near_vector, build_near_vector(near_vector, opts)}}

      near_text = Keyword.get(opts, :near_text) ->
        %{base | search: {:near_text, build_near_text(near_text, opts)}}

      true ->
        base
    end
  end

  defp build_aggregation(property, :number, aggregations) do
    number_agg = %AggregateRequest.Aggregation.Number{
      count: :count in aggregations,
      type: :type in aggregations,
      sum: :sum in aggregations,
      mean: :mean in aggregations,
      mode: :mode in aggregations,
      median: :median in aggregations,
      maximum: :maximum in aggregations,
      minimum: :minimum in aggregations
    }

    %AggregateRequest.Aggregation{
      property: property,
      aggregation: {:number, number_agg}
    }
  end

  defp build_aggregation(property, :integer, aggregations) do
    int_agg = %AggregateRequest.Aggregation.Integer{
      count: :count in aggregations,
      type: :type in aggregations,
      sum: :sum in aggregations,
      mean: :mean in aggregations,
      mode: :mode in aggregations,
      median: :median in aggregations,
      maximum: :maximum in aggregations,
      minimum: :minimum in aggregations
    }

    %AggregateRequest.Aggregation{
      property: property,
      aggregation: {:int, int_agg}
    }
  end

  defp build_aggregation(property, :text, aggregations) do
    limit = Keyword.get(aggregations, :top_occurrences_limit)

    text_agg = %AggregateRequest.Aggregation.Text{
      count: :count in aggregations,
      type: :type in aggregations,
      top_occurences: :top_occurrences in aggregations,
      top_occurences_limit: limit
    }

    %AggregateRequest.Aggregation{
      property: property,
      aggregation: {:text, text_agg}
    }
  end

  defp build_aggregation(property, :boolean, aggregations) do
    bool_agg = %AggregateRequest.Aggregation.Boolean{
      count: :count in aggregations,
      type: :type in aggregations,
      total_true: :total_true in aggregations,
      total_false: :total_false in aggregations,
      percentage_true: :percentage_true in aggregations,
      percentage_false: :percentage_false in aggregations
    }

    %AggregateRequest.Aggregation{
      property: property,
      aggregation: {:boolean, bool_agg}
    }
  end

  defp build_aggregation(property, :date, aggregations) do
    date_agg = %AggregateRequest.Aggregation.Date{
      count: :count in aggregations,
      type: :type in aggregations,
      median: :median in aggregations,
      mode: :mode in aggregations,
      maximum: :maximum in aggregations,
      minimum: :minimum in aggregations
    }

    %AggregateRequest.Aggregation{
      property: property,
      aggregation: {:date, date_agg}
    }
  end

  defp build_aggregation(property, _type, aggregations) do
    # Default to number aggregation
    build_aggregation(property, :number, aggregations)
  end

  defp build_filter(nil), do: nil

  defp build_filter(filter) when is_map(filter) do
    operator = map_operator(filter[:operator] || filter["operator"])
    path = filter[:path] || filter["path"] || []

    base_filter = %Weaviate.V1.Filters{
      operator: operator,
      target: %Weaviate.V1.FilterTarget{
        target: {:property, Enum.join(path, ".")}
      }
    }

    apply_filter_value(base_filter, filter)
  end

  defp apply_filter_value(base_filter, filter) do
    filter
    |> extract_filter_value()
    |> set_filter_test_value(base_filter)
  end

  defp extract_filter_value(filter) do
    extract_value_text(filter) ||
      extract_value_int(filter) ||
      extract_value_number(filter) ||
      extract_value_boolean(filter)
  end

  defp extract_value_text(filter) do
    case filter[:value_text] || filter["value_text"] do
      nil -> nil
      value -> {:value_text, value}
    end
  end

  defp extract_value_int(filter) do
    case filter[:value_int] || filter["value_int"] do
      nil -> nil
      value -> {:value_int, value}
    end
  end

  defp extract_value_number(filter) do
    case filter[:value_number] || filter["value_number"] do
      nil -> nil
      value -> {:value_number, value}
    end
  end

  defp extract_value_boolean(filter) do
    case filter[:value_boolean] || filter["value_boolean"] do
      nil -> nil
      value -> {:value_boolean, value}
    end
  end

  defp set_filter_test_value(nil, base_filter), do: base_filter
  defp set_filter_test_value(test_value, base_filter), do: %{base_filter | test_value: test_value}

  defp build_near_vector(nil, _opts), do: nil

  defp build_near_vector(vector, opts) when is_list(vector) do
    vector_bytes =
      vector
      |> Enum.map(&<<&1::float-little-32>>)
      |> IO.iodata_to_binary()

    %Weaviate.V1.NearVector{
      vector_bytes: vector_bytes,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  defp build_near_text(nil, _opts), do: nil

  defp build_near_text(query, opts) when is_binary(query) do
    %Weaviate.V1.NearTextSearch{
      query: [query],
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  defp map_operator(:equal), do: :OPERATOR_EQUAL
  defp map_operator(:not_equal), do: :OPERATOR_NOT_EQUAL
  defp map_operator(:greater_than), do: :OPERATOR_GREATER_THAN
  defp map_operator(:greater_than_equal), do: :OPERATOR_GREATER_THAN_EQUAL
  defp map_operator(:less_than), do: :OPERATOR_LESS_THAN
  defp map_operator(:less_than_equal), do: :OPERATOR_LESS_THAN_EQUAL
  defp map_operator(:like), do: :OPERATOR_LIKE
  defp map_operator(:is_null), do: :OPERATOR_IS_NULL
  defp map_operator(_), do: :OPERATOR_UNSPECIFIED

  defp execute_aggregate(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.aggregate(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end
end
