defmodule WeaviateEx.API.InvertedIndexConfig do
  @moduledoc """
  Configuration builders for Weaviate inverted index settings.

  This module provides helpers for configuring BM25 parameters, stopwords,
  and other inverted index settings for collection schema definitions.

  ## BM25 Parameters

  BM25 (Best Match 25) is the ranking algorithm used for keyword search:
  - `b` - Length normalization (0.0-1.0), default 0.75
  - `k1` - Term frequency saturation, default 1.2

  ## Stopwords

  Stopwords are common words filtered from indexing:
  - `:en` preset includes English stopwords
  - `:none` disables stopword filtering
  - Custom additions and removals can be specified

  ## Examples

      # Basic BM25 configuration
      bm25 = InvertedIndexConfig.bm25(b: 0.8, k1: 1.5)

      # Stopwords with additions
      stopwords = InvertedIndexConfig.stopwords(
        preset: :en,
        additions: ["foo", "bar"]
      )

      # Full configuration for collection creation
      config = InvertedIndexConfig.build(
        bm25: [b: 0.8, k1: 1.5],
        stopwords: [preset: :en, additions: ["foo"]],
        cleanup_interval_seconds: 60,
        index_timestamps: true,
        index_property_length: true,
        index_null_state: false
      )

      Collections.create("Article", %{
        properties: [...],
        invertedIndexConfig: config
      })
  """

  @type stopwords_preset :: :en | :none
  @type bm25_config :: %{b: float(), k1: float()}
  @type stopwords_config :: %{
          optional(:preset) => String.t(),
          optional(:additions) => [String.t()],
          optional(:removals) => [String.t()]
        }
  @type inverted_index_config :: %{
          optional(:bm25) => bm25_config(),
          optional(:stopwords) => stopwords_config(),
          optional(:cleanupIntervalSeconds) => non_neg_integer(),
          optional(:indexTimestamps) => boolean(),
          optional(:indexPropertyLength) => boolean(),
          optional(:indexNullState) => boolean()
        }

  @default_bm25_b 0.75
  @default_bm25_k1 1.2

  @doc """
  Create BM25 ranking configuration.

  ## Parameters

  - `:b` - Length normalization parameter (0.0-1.0), default: 0.75
    - 0.0 = no length normalization
    - 1.0 = full length normalization
  - `:k1` - Term frequency saturation parameter, default: 1.2
    - Higher values give more weight to term frequency

  ## Examples

      # Default configuration
      InvertedIndexConfig.bm25()
      # => %{b: 0.75, k1: 1.2}

      # Custom configuration
      InvertedIndexConfig.bm25(b: 0.5, k1: 2.0)
      # => %{b: 0.5, k1: 2.0}
  """
  @spec bm25(keyword()) :: bm25_config()
  def bm25(opts \\ []) do
    %{
      b: Keyword.get(opts, :b, @default_bm25_b),
      k1: Keyword.get(opts, :k1, @default_bm25_k1)
    }
  end

  @doc """
  Create stopwords configuration.

  ## Parameters

  - `:preset` - Stopwords preset (`:en` or `:none`)
  - `:additions` - List of words to add to stopwords
  - `:removals` - List of words to remove from stopwords

  ## Examples

      # Use English stopwords
      InvertedIndexConfig.stopwords(preset: :en)

      # English stopwords with custom additions
      InvertedIndexConfig.stopwords(
        preset: :en,
        additions: ["foo", "bar"]
      )

      # Remove specific words from English stopwords
      InvertedIndexConfig.stopwords(
        preset: :en,
        removals: ["the", "a"]
      )
  """
  @spec stopwords(keyword()) :: stopwords_config()
  def stopwords(opts \\ []) do
    config = %{}

    config =
      case Keyword.get(opts, :preset) do
        nil -> config
        preset -> Map.put(config, :preset, preset_to_string(preset))
      end

    config =
      case Keyword.get(opts, :additions) do
        nil -> config
        additions -> Map.put(config, :additions, additions)
      end

    case Keyword.get(opts, :removals) do
      nil -> config
      removals -> Map.put(config, :removals, removals)
    end
  end

  @doc """
  Create configuration to enable/disable timestamp indexing.

  When enabled, Weaviate indexes creation and update timestamps,
  allowing filtering by `creationTimeUnix` and `lastUpdateTimeUnix`.

  ## Examples

      InvertedIndexConfig.index_timestamps(true)
      # => %{indexTimestamps: true}
  """
  @spec index_timestamps(boolean()) :: map()
  def index_timestamps(enabled) when is_boolean(enabled) do
    %{indexTimestamps: enabled}
  end

  @doc """
  Create configuration to enable/disable property length indexing.

  When enabled, Weaviate indexes the length of text properties,
  allowing efficient filtering by property length.

  ## Examples

      InvertedIndexConfig.index_property_length(true)
      # => %{indexPropertyLength: true}
  """
  @spec index_property_length(boolean()) :: map()
  def index_property_length(enabled) when is_boolean(enabled) do
    %{indexPropertyLength: enabled}
  end

  @doc """
  Create configuration to enable/disable null state indexing.

  When enabled, Weaviate indexes whether properties are null,
  allowing efficient filtering for null/non-null values.

  ## Examples

      InvertedIndexConfig.index_null_state(true)
      # => %{indexNullState: true}
  """
  @spec index_null_state(boolean()) :: map()
  def index_null_state(enabled) when is_boolean(enabled) do
    %{indexNullState: enabled}
  end

  @doc """
  Create configuration for cleanup interval.

  Sets the interval in seconds for cleaning up deleted entries
  from the inverted index.

  ## Examples

      # Cleanup every 5 minutes
      InvertedIndexConfig.cleanup_interval_seconds(300)

      # Immediate cleanup (not recommended for production)
      InvertedIndexConfig.cleanup_interval_seconds(0)
  """
  @spec cleanup_interval_seconds(non_neg_integer()) :: map()
  def cleanup_interval_seconds(seconds) when is_integer(seconds) and seconds >= 0 do
    %{cleanupIntervalSeconds: seconds}
  end

  @doc """
  Build a complete inverted index configuration from options.

  ## Options

  - `:bm25` - BM25 configuration options (see `bm25/1`)
  - `:stopwords` - Stopwords configuration options (see `stopwords/1`)
  - `:cleanup_interval_seconds` - Cleanup interval in seconds
  - `:index_timestamps` - Enable timestamp indexing
  - `:index_property_length` - Enable property length indexing
  - `:index_null_state` - Enable null state indexing

  ## Examples

      InvertedIndexConfig.build(
        bm25: [b: 0.8, k1: 1.5],
        stopwords: [preset: :en],
        cleanup_interval_seconds: 60,
        index_timestamps: true
      )
  """
  @spec build(keyword()) :: inverted_index_config()
  def build(opts \\ []) do
    config = %{}

    config = maybe_add_bm25(config, Keyword.get(opts, :bm25))
    config = maybe_add_stopwords(config, Keyword.get(opts, :stopwords))
    config = maybe_add_cleanup_interval(config, Keyword.get(opts, :cleanup_interval_seconds))
    config = maybe_add_index_timestamps(config, Keyword.get(opts, :index_timestamps))
    config = maybe_add_index_property_length(config, Keyword.get(opts, :index_property_length))
    maybe_add_index_null_state(config, Keyword.get(opts, :index_null_state))
  end

  @doc """
  Merge two inverted index configurations.

  The second configuration takes precedence for conflicting keys.

  ## Examples

      base = %{bm25: %{b: 0.75, k1: 1.2}}
      override = %{indexTimestamps: true}
      InvertedIndexConfig.merge(base, override)
      # => %{bm25: %{b: 0.75, k1: 1.2}, indexTimestamps: true}
  """
  @spec merge(inverted_index_config(), inverted_index_config()) :: inverted_index_config()
  def merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override)
  end

  @doc """
  Validate an inverted index configuration.

  ## Returns

  - `{:ok, config}` if valid
  - `{:error, message}` if invalid

  ## Examples

      InvertedIndexConfig.validate(%{bm25: %{b: 0.5, k1: 1.2}})
      # => {:ok, %{bm25: %{b: 0.5, k1: 1.2}}}

      InvertedIndexConfig.validate(%{bm25: %{b: 1.5, k1: 1.2}})
      # => {:error, "b must be between 0 and 1"}
  """
  @spec validate(inverted_index_config()) :: {:ok, inverted_index_config()} | {:error, String.t()}
  def validate(config) when is_map(config) do
    with :ok <- validate_bm25(config[:bm25]),
         :ok <- validate_stopwords(config[:stopwords]),
         :ok <- validate_cleanup_interval(config[:cleanupIntervalSeconds]) do
      {:ok, config}
    end
  end

  # Private helpers

  defp preset_to_string(:en), do: "en"
  defp preset_to_string(:none), do: "none"
  defp preset_to_string(other) when is_binary(other), do: other

  defp maybe_add_bm25(config, nil), do: config

  defp maybe_add_bm25(config, bm25_opts) when is_list(bm25_opts) do
    Map.put(config, :bm25, bm25(bm25_opts))
  end

  defp maybe_add_stopwords(config, nil), do: config

  defp maybe_add_stopwords(config, stopwords_opts) when is_list(stopwords_opts) do
    Map.put(config, :stopwords, stopwords(stopwords_opts))
  end

  defp maybe_add_cleanup_interval(config, nil), do: config

  defp maybe_add_cleanup_interval(config, seconds) do
    Map.put(config, :cleanupIntervalSeconds, seconds)
  end

  defp maybe_add_index_timestamps(config, nil), do: config

  defp maybe_add_index_timestamps(config, enabled) do
    Map.put(config, :indexTimestamps, enabled)
  end

  defp maybe_add_index_property_length(config, nil), do: config

  defp maybe_add_index_property_length(config, enabled) do
    Map.put(config, :indexPropertyLength, enabled)
  end

  defp maybe_add_index_null_state(config, nil), do: config

  defp maybe_add_index_null_state(config, enabled) do
    Map.put(config, :indexNullState, enabled)
  end

  defp validate_bm25(nil), do: :ok

  defp validate_bm25(%{b: b, k1: k1}) do
    cond do
      b < 0 or b > 1 -> {:error, "b must be between 0 and 1"}
      k1 < 0 -> {:error, "k1 must be positive"}
      true -> :ok
    end
  end

  defp validate_bm25(_), do: :ok

  defp validate_stopwords(nil), do: :ok

  defp validate_stopwords(%{preset: preset}) when preset not in ["en", "none"] do
    {:error, "preset must be 'en' or 'none', got: #{inspect(preset)}"}
  end

  defp validate_stopwords(_), do: :ok

  defp validate_cleanup_interval(nil), do: :ok

  defp validate_cleanup_interval(seconds) when is_integer(seconds) and seconds < 0 do
    {:error, "cleanupIntervalSeconds must be non-negative"}
  end

  defp validate_cleanup_interval(_), do: :ok
end
