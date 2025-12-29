defmodule WeaviateEx.API.InvertedIndexConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.InvertedIndexConfig

  describe "bm25/1" do
    test "creates BM25 configuration with default values" do
      config = InvertedIndexConfig.bm25()

      assert config == %{b: 0.75, k1: 1.2}
    end

    test "creates BM25 configuration with custom b value" do
      config = InvertedIndexConfig.bm25(b: 0.5)

      assert config.b == 0.5
      assert config.k1 == 1.2
    end

    test "creates BM25 configuration with custom k1 value" do
      config = InvertedIndexConfig.bm25(k1: 1.5)

      assert config.b == 0.75
      assert config.k1 == 1.5
    end

    test "creates BM25 configuration with both custom values" do
      config = InvertedIndexConfig.bm25(b: 0.8, k1: 2.0)

      assert config.b == 0.8
      assert config.k1 == 2.0
    end
  end

  describe "stopwords/1" do
    test "creates stopwords configuration with :en preset" do
      config = InvertedIndexConfig.stopwords(preset: :en)

      assert config == %{preset: "en"}
    end

    test "creates stopwords configuration with :none preset" do
      config = InvertedIndexConfig.stopwords(preset: :none)

      assert config == %{preset: "none"}
    end

    test "creates stopwords configuration with additions" do
      config = InvertedIndexConfig.stopwords(preset: :en, additions: ["foo", "bar"])

      assert config.preset == "en"
      assert config.additions == ["foo", "bar"]
    end

    test "creates stopwords configuration with removals" do
      config = InvertedIndexConfig.stopwords(preset: :en, removals: ["the", "a"])

      assert config.preset == "en"
      assert config.removals == ["the", "a"]
    end

    test "creates stopwords configuration with all options" do
      config =
        InvertedIndexConfig.stopwords(
          preset: :en,
          additions: ["foo"],
          removals: ["the"]
        )

      assert config == %{
               preset: "en",
               additions: ["foo"],
               removals: ["the"]
             }
    end
  end

  describe "index_timestamps/1" do
    test "enables timestamp indexing" do
      config = InvertedIndexConfig.index_timestamps(true)

      assert config == %{indexTimestamps: true}
    end

    test "disables timestamp indexing" do
      config = InvertedIndexConfig.index_timestamps(false)

      assert config == %{indexTimestamps: false}
    end
  end

  describe "index_property_length/1" do
    test "enables property length indexing" do
      config = InvertedIndexConfig.index_property_length(true)

      assert config == %{indexPropertyLength: true}
    end

    test "disables property length indexing" do
      config = InvertedIndexConfig.index_property_length(false)

      assert config == %{indexPropertyLength: false}
    end
  end

  describe "index_null_state/1" do
    test "enables null state indexing" do
      config = InvertedIndexConfig.index_null_state(true)

      assert config == %{indexNullState: true}
    end

    test "disables null state indexing" do
      config = InvertedIndexConfig.index_null_state(false)

      assert config == %{indexNullState: false}
    end
  end

  describe "cleanup_interval_seconds/1" do
    test "sets cleanup interval" do
      config = InvertedIndexConfig.cleanup_interval_seconds(300)

      assert config == %{cleanupIntervalSeconds: 300}
    end

    test "sets cleanup interval to 0 for immediate cleanup" do
      config = InvertedIndexConfig.cleanup_interval_seconds(0)

      assert config == %{cleanupIntervalSeconds: 0}
    end
  end

  describe "build/1" do
    test "builds full inverted index configuration" do
      config =
        InvertedIndexConfig.build(
          bm25: [b: 0.8, k1: 1.5],
          stopwords: [preset: :en, additions: ["foo"]],
          cleanup_interval_seconds: 60,
          index_timestamps: true,
          index_property_length: true,
          index_null_state: false
        )

      assert config == %{
               bm25: %{b: 0.8, k1: 1.5},
               stopwords: %{preset: "en", additions: ["foo"]},
               cleanupIntervalSeconds: 60,
               indexTimestamps: true,
               indexPropertyLength: true,
               indexNullState: false
             }
    end

    test "builds partial configuration" do
      config =
        InvertedIndexConfig.build(
          bm25: [b: 0.5],
          index_timestamps: true
        )

      assert config == %{
               bm25: %{b: 0.5, k1: 1.2},
               indexTimestamps: true
             }
    end

    test "builds configuration with only stopwords" do
      config = InvertedIndexConfig.build(stopwords: [preset: :none])

      assert config == %{
               stopwords: %{preset: "none"}
             }
    end

    test "returns empty map when no options" do
      config = InvertedIndexConfig.build([])

      assert config == %{}
    end
  end

  describe "merge/2" do
    test "merges two configurations" do
      base = %{bm25: %{b: 0.75, k1: 1.2}}
      override = %{indexTimestamps: true}

      result = InvertedIndexConfig.merge(base, override)

      assert result == %{
               bm25: %{b: 0.75, k1: 1.2},
               indexTimestamps: true
             }
    end

    test "override takes precedence" do
      base = %{bm25: %{b: 0.75, k1: 1.2}}
      override = %{bm25: %{b: 0.5, k1: 1.5}}

      result = InvertedIndexConfig.merge(base, override)

      assert result.bm25.b == 0.5
      assert result.bm25.k1 == 1.5
    end
  end

  describe "validate/1" do
    test "validates correct BM25 b range" do
      config = %{bm25: %{b: 0.5, k1: 1.2}}

      assert {:ok, _} = InvertedIndexConfig.validate(config)
    end

    test "validates b must be between 0 and 1" do
      config = %{bm25: %{b: 1.5, k1: 1.2}}

      assert {:error, error} = InvertedIndexConfig.validate(config)
      assert error =~ "b must be between 0 and 1"
    end

    test "validates negative b value" do
      config = %{bm25: %{b: -0.1, k1: 1.2}}

      assert {:error, error} = InvertedIndexConfig.validate(config)
      assert error =~ "b must be between 0 and 1"
    end

    test "validates k1 must be positive" do
      config = %{bm25: %{b: 0.5, k1: -1.0}}

      assert {:error, error} = InvertedIndexConfig.validate(config)
      assert error =~ "k1 must be positive"
    end

    test "validates valid stopwords preset" do
      config = %{stopwords: %{preset: "en"}}

      assert {:ok, _} = InvertedIndexConfig.validate(config)
    end

    test "validates invalid stopwords preset" do
      config = %{stopwords: %{preset: "invalid"}}

      assert {:error, error} = InvertedIndexConfig.validate(config)
      assert error =~ "preset must be"
    end

    test "validates cleanup_interval_seconds must be non-negative" do
      config = %{cleanupIntervalSeconds: -1}

      assert {:error, error} = InvertedIndexConfig.validate(config)
      assert error =~ "cleanupIntervalSeconds must be non-negative"
    end

    test "validates empty config is valid" do
      assert {:ok, _} = InvertedIndexConfig.validate(%{})
    end
  end
end
