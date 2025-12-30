defmodule WeaviateEx.Aggregate.Metrics do
  @moduledoc """
  Helper module for building aggregate metrics.

  Provides a cleaner API for specifying which metrics to compute during
  aggregation operations.

  ## Usage

      alias WeaviateEx.Aggregate.Metrics

      # Use metrics in aggregation
      Aggregate.over_all(client, "Products",
        metrics: [Metrics.count()],
        properties: [
          Metrics.number("price", sum: true, mean: true, minimum: true, maximum: true),
          Metrics.text("category", top_occurrences: 5),
          Metrics.boolean("inStock")
        ]
      )
  """

  @type metric_opt ::
          {:count, boolean()}
          | {:sum, boolean()}
          | {:mean, boolean()}
          | {:median, boolean()}
          | {:mode, boolean()}
          | {:minimum, boolean()}
          | {:maximum, boolean()}
          | {:top_occurrences, non_neg_integer()}
          | {:percentage_true, boolean()}
          | {:percentage_false, boolean()}
          | {:total_true, boolean()}
          | {:total_false, boolean()}

  @doc """
  Count metric for meta aggregation.

  Returns the total number of objects.

  ## Examples

      Aggregate.over_all(client, "Articles", metrics: [Metrics.count()])
  """
  @spec count() :: :count
  def count, do: :count

  @doc """
  Build a text property metric specification.

  ## Options

    * `:count` - Include count of values (default: false)
    * `:top_occurrences` - Number of top values to return (default: nil)

  ## Examples

      # Get top 5 categories
      Metrics.text("category", top_occurrences: 5)

      # Just count
      Metrics.text("title", count: true)
  """
  @spec text(String.t() | atom(), keyword()) :: {atom() | String.t(), list(), keyword()}
  def text(property, opts \\ []) do
    metrics = build_text_metrics(opts)
    metric_opts = Keyword.take(opts, [:limit])

    # Convert top_occurrences limit to :limit option
    metric_opts =
      case Keyword.get(opts, :top_occurrences) do
        nil -> metric_opts
        limit when is_integer(limit) -> Keyword.put(metric_opts, :limit, limit)
        true -> metric_opts
      end

    {property, metrics, metric_opts}
  end

  @doc """
  Build a number property metric specification.

  ## Options

    * `:count` - Include count (default: false)
    * `:sum` - Include sum (default: false)
    * `:mean` - Include mean (default: false)
    * `:median` - Include median (default: false)
    * `:mode` - Include mode (default: false)
    * `:minimum` - Include minimum (default: false)
    * `:maximum` - Include maximum (default: false)

  ## Examples

      # Get basic stats
      Metrics.number("price", sum: true, mean: true, minimum: true, maximum: true)

      # All stats
      Metrics.number("quantity",
        count: true, sum: true, mean: true, median: true,
        mode: true, minimum: true, maximum: true
      )
  """
  @spec number(String.t() | atom(), keyword()) :: {atom() | String.t(), list()}
  def number(property, opts \\ []) do
    metrics = build_number_metrics(opts)
    {property, metrics}
  end

  @doc """
  Build an integer property metric specification.

  Same options as `number/2`.

  ## Examples

      Metrics.integer("quantity", sum: true, mean: true)
  """
  @spec integer(String.t() | atom(), keyword()) :: {atom() | String.t(), list()}
  def integer(property, opts \\ []) do
    # Integer uses the same metrics as number
    number(property, opts)
  end

  @doc """
  Build a boolean property metric specification.

  ## Options

    * `:count` - Include count (default: true)
    * `:percentage_true` - Include percentage of true values (default: true)
    * `:percentage_false` - Include percentage of false values (default: true)
    * `:total_true` - Include count of true values (default: true)
    * `:total_false` - Include count of false values (default: true)

  ## Examples

      # Get all boolean metrics
      Metrics.boolean("inStock")

      # Only percentages
      Metrics.boolean("isActive", percentage_true: true, percentage_false: true)
  """
  @spec boolean(String.t() | atom(), keyword()) :: {atom() | String.t(), list()}
  def boolean(property, opts \\ []) do
    metrics = build_boolean_metrics(opts)
    {property, metrics}
  end

  @doc """
  Build a date property metric specification.

  ## Options

    * `:count` - Include count (default: false)
    * `:median` - Include median date (default: false)
    * `:mode` - Include mode date (default: false)
    * `:minimum` - Include earliest date (default: false)
    * `:maximum` - Include latest date (default: false)

  ## Examples

      Metrics.date("createdAt", minimum: true, maximum: true)
  """
  @spec date(String.t() | atom(), keyword()) :: {atom() | String.t(), list()}
  def date(property, opts \\ []) do
    metrics = build_date_metrics(opts)
    {property, metrics}
  end

  # Private helpers

  defp build_text_metrics(opts) do
    metrics = []

    metrics = if Keyword.get(opts, :count), do: [:count | metrics], else: metrics

    metrics =
      case Keyword.get(opts, :top_occurrences) do
        nil -> metrics
        _value -> [:topOccurrences | metrics]
      end

    if Enum.empty?(metrics), do: [:topOccurrences], else: Enum.reverse(metrics)
  end

  defp build_number_metrics(opts) do
    metrics = []

    metrics = if Keyword.get(opts, :count), do: [:count | metrics], else: metrics
    metrics = if Keyword.get(opts, :sum), do: [:sum | metrics], else: metrics
    metrics = if Keyword.get(opts, :mean), do: [:mean | metrics], else: metrics
    metrics = if Keyword.get(opts, :median), do: [:median | metrics], else: metrics
    metrics = if Keyword.get(opts, :mode), do: [:mode | metrics], else: metrics
    metrics = if Keyword.get(opts, :minimum), do: [:minimum | metrics], else: metrics
    metrics = if Keyword.get(opts, :maximum), do: [:maximum | metrics], else: metrics

    if Enum.empty?(metrics), do: [:count], else: Enum.reverse(metrics)
  end

  defp build_boolean_metrics(opts) do
    # Default to all boolean metrics if no options specified
    has_opts =
      Keyword.keys(opts)
      |> Enum.any?(
        &(&1 in [:count, :percentage_true, :percentage_false, :total_true, :total_false])
      )

    if has_opts do
      metrics = []
      metrics = if Keyword.get(opts, :count), do: [:count | metrics], else: metrics

      metrics =
        if Keyword.get(opts, :percentage_true), do: [:percentageTrue | metrics], else: metrics

      metrics =
        if Keyword.get(opts, :percentage_false), do: [:percentageFalse | metrics], else: metrics

      metrics = if Keyword.get(opts, :total_true), do: [:totalTrue | metrics], else: metrics
      metrics = if Keyword.get(opts, :total_false), do: [:totalFalse | metrics], else: metrics
      Enum.reverse(metrics)
    else
      # Default: all boolean metrics
      [:percentageTrue, :percentageFalse, :totalTrue, :totalFalse]
    end
  end

  defp build_date_metrics(opts) do
    metrics = []

    metrics = if Keyword.get(opts, :count), do: [:count | metrics], else: metrics
    metrics = if Keyword.get(opts, :median), do: [:median | metrics], else: metrics
    metrics = if Keyword.get(opts, :mode), do: [:mode | metrics], else: metrics
    metrics = if Keyword.get(opts, :minimum), do: [:minimum | metrics], else: metrics
    metrics = if Keyword.get(opts, :maximum), do: [:maximum | metrics], else: metrics

    if Enum.empty?(metrics), do: [:minimum, :maximum], else: Enum.reverse(metrics)
  end
end
