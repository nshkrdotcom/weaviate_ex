defmodule WeaviateEx.API.QuantizerTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.Quantizer
  alias WeaviateEx.API.Quantizer.{BQConfig, PQConfig, RQConfig, SQConfig}

  describe "PQConfig" do
    test "new/0 creates default PQ config" do
      config = PQConfig.new()

      assert %PQConfig{} = config
      assert config.enabled == true
      assert config.training_limit == nil
      assert config.segments == nil
      assert config.centroids == nil
      assert config.encoder == nil
    end

    test "new/1 creates PQ config with options" do
      config =
        PQConfig.new(
          enabled: true,
          training_limit: 100_000,
          segments: 0,
          centroids: 256,
          encoder: %{type: "kmeans", distribution: "log-normal"}
        )

      assert %PQConfig{} = config
      assert config.enabled == true
      assert config.training_limit == 100_000
      assert config.segments == 0
      assert config.centroids == 256
      assert config.encoder == %{type: "kmeans", distribution: "log-normal"}
    end

    test "to_api/1 converts to API format" do
      config =
        PQConfig.new(
          enabled: true,
          training_limit: 100_000,
          segments: 0,
          centroids: 256,
          encoder: %{type: "kmeans", distribution: "log-normal"}
        )

      api_format = PQConfig.to_api(config)

      assert api_format == %{
               "pq" => %{
                 "enabled" => true,
                 "trainingLimit" => 100_000,
                 "segments" => 0,
                 "centroids" => 256,
                 "encoder" => %{
                   "type" => "kmeans",
                   "distribution" => "log-normal"
                 }
               }
             }
    end

    test "to_api/1 omits nil values" do
      config = PQConfig.new(enabled: true)
      api_format = PQConfig.to_api(config)

      assert api_format == %{
               "pq" => %{
                 "enabled" => true
               }
             }
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "pq" => %{
          "enabled" => true,
          "trainingLimit" => 100_000,
          "segments" => 0,
          "centroids" => 256,
          "encoder" => %{
            "type" => "kmeans",
            "distribution" => "log-normal"
          }
        }
      }

      config = PQConfig.from_api(api_data)

      assert %PQConfig{} = config
      assert config.enabled == true
      assert config.training_limit == 100_000
      assert config.segments == 0
      assert config.centroids == 256
      assert config.encoder == %{"type" => "kmeans", "distribution" => "log-normal"}
    end

    test "from_api/1 handles minimal API response" do
      api_data = %{"pq" => %{"enabled" => false}}
      config = PQConfig.from_api(api_data)

      assert %PQConfig{} = config
      assert config.enabled == false
      assert config.training_limit == nil
    end

    test "serialization round-trip preserves data" do
      original =
        PQConfig.new(
          enabled: true,
          training_limit: 50_000,
          segments: 128,
          centroids: 256
        )

      round_tripped =
        original
        |> PQConfig.to_api()
        |> PQConfig.from_api()

      assert round_tripped.enabled == original.enabled
      assert round_tripped.training_limit == original.training_limit
      assert round_tripped.segments == original.segments
      assert round_tripped.centroids == original.centroids
    end
  end

  describe "BQConfig" do
    test "new/0 creates default BQ config" do
      config = BQConfig.new()

      assert %BQConfig{} = config
      assert config.enabled == true
      assert config.cache == nil
      assert config.rescore_limit == nil
    end

    test "new/1 creates BQ config with options" do
      config =
        BQConfig.new(
          enabled: true,
          cache: true,
          rescore_limit: 200
        )

      assert %BQConfig{} = config
      assert config.enabled == true
      assert config.cache == true
      assert config.rescore_limit == 200
    end

    test "to_api/1 converts to API format" do
      config =
        BQConfig.new(
          enabled: true,
          cache: true,
          rescore_limit: 200
        )

      api_format = BQConfig.to_api(config)

      assert api_format == %{
               "bq" => %{
                 "enabled" => true,
                 "cache" => true,
                 "rescoreLimit" => 200
               }
             }
    end

    test "to_api/1 omits nil values" do
      config = BQConfig.new(enabled: false)
      api_format = BQConfig.to_api(config)

      assert api_format == %{
               "bq" => %{
                 "enabled" => false
               }
             }
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "bq" => %{
          "enabled" => true,
          "cache" => true,
          "rescoreLimit" => 200
        }
      }

      config = BQConfig.from_api(api_data)

      assert %BQConfig{} = config
      assert config.enabled == true
      assert config.cache == true
      assert config.rescore_limit == 200
    end

    test "serialization round-trip preserves data" do
      original =
        BQConfig.new(
          enabled: true,
          cache: false,
          rescore_limit: 100
        )

      round_tripped =
        original
        |> BQConfig.to_api()
        |> BQConfig.from_api()

      assert round_tripped.enabled == original.enabled
      assert round_tripped.cache == original.cache
      assert round_tripped.rescore_limit == original.rescore_limit
    end
  end

  describe "SQConfig" do
    test "new/0 creates default SQ config" do
      config = SQConfig.new()

      assert %SQConfig{} = config
      assert config.enabled == true
      assert config.cache == nil
      assert config.rescore_limit == nil
      assert config.training_limit == nil
    end

    test "new/1 creates SQ config with options" do
      config =
        SQConfig.new(
          enabled: true,
          cache: true,
          rescore_limit: 200,
          training_limit: 100_000
        )

      assert %SQConfig{} = config
      assert config.enabled == true
      assert config.cache == true
      assert config.rescore_limit == 200
      assert config.training_limit == 100_000
    end

    test "to_api/1 converts to API format" do
      config =
        SQConfig.new(
          enabled: true,
          cache: true,
          rescore_limit: 200,
          training_limit: 100_000
        )

      api_format = SQConfig.to_api(config)

      assert api_format == %{
               "sq" => %{
                 "enabled" => true,
                 "cache" => true,
                 "rescoreLimit" => 200,
                 "trainingLimit" => 100_000
               }
             }
    end

    test "to_api/1 omits nil values" do
      config = SQConfig.new(enabled: true, cache: true)
      api_format = SQConfig.to_api(config)

      assert api_format == %{
               "sq" => %{
                 "enabled" => true,
                 "cache" => true
               }
             }
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "sq" => %{
          "enabled" => true,
          "cache" => true,
          "rescoreLimit" => 200,
          "trainingLimit" => 100_000
        }
      }

      config = SQConfig.from_api(api_data)

      assert %SQConfig{} = config
      assert config.enabled == true
      assert config.cache == true
      assert config.rescore_limit == 200
      assert config.training_limit == 100_000
    end

    test "serialization round-trip preserves data" do
      original =
        SQConfig.new(
          enabled: true,
          cache: true,
          rescore_limit: 150,
          training_limit: 50_000
        )

      round_tripped =
        original
        |> SQConfig.to_api()
        |> SQConfig.from_api()

      assert round_tripped.enabled == original.enabled
      assert round_tripped.cache == original.cache
      assert round_tripped.rescore_limit == original.rescore_limit
      assert round_tripped.training_limit == original.training_limit
    end
  end

  describe "RQConfig" do
    test "new/0 creates default RQ config" do
      config = RQConfig.new()

      assert %RQConfig{} = config
      assert config.enabled == true
      assert config.bits == nil
      assert config.cache == nil
      assert config.rescore_limit == nil
      assert config.training_limit == nil
    end

    test "new/1 creates RQ config with options" do
      config =
        RQConfig.new(
          enabled: true,
          bits: 8,
          cache: true,
          rescore_limit: 200,
          training_limit: 100_000
        )

      assert %RQConfig{} = config
      assert config.enabled == true
      assert config.bits == 8
      assert config.cache == true
      assert config.rescore_limit == 200
      assert config.training_limit == 100_000
    end

    test "to_api/1 converts to API format" do
      config =
        RQConfig.new(
          enabled: true,
          bits: 8,
          cache: true,
          rescore_limit: 200,
          training_limit: 100_000
        )

      api_format = RQConfig.to_api(config)

      assert api_format == %{
               "rq" => %{
                 "enabled" => true,
                 "bits" => 8,
                 "cache" => true,
                 "rescoreLimit" => 200,
                 "trainingLimit" => 100_000
               }
             }
    end

    test "to_api/1 omits nil values" do
      config = RQConfig.new(enabled: true, bits: 8)
      api_format = RQConfig.to_api(config)

      assert api_format == %{
               "rq" => %{
                 "enabled" => true,
                 "bits" => 8
               }
             }
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "rq" => %{
          "enabled" => true,
          "bits" => 8,
          "cache" => true,
          "rescoreLimit" => 200,
          "trainingLimit" => 100_000
        }
      }

      config = RQConfig.from_api(api_data)

      assert %RQConfig{} = config
      assert config.enabled == true
      assert config.bits == 8
      assert config.cache == true
      assert config.rescore_limit == 200
      assert config.training_limit == 100_000
    end

    test "serialization round-trip preserves data" do
      original =
        RQConfig.new(
          enabled: true,
          bits: 4,
          cache: false,
          rescore_limit: 100,
          training_limit: 25_000
        )

      round_tripped =
        original
        |> RQConfig.to_api()
        |> RQConfig.from_api()

      assert round_tripped.enabled == original.enabled
      assert round_tripped.bits == original.bits
      assert round_tripped.cache == original.cache
      assert round_tripped.rescore_limit == original.rescore_limit
      assert round_tripped.training_limit == original.training_limit
    end
  end

  describe "Quantizer module" do
    test "detect_type/1 detects PQ from API response" do
      api_data = %{"pq" => %{"enabled" => true}}
      assert Quantizer.detect_type(api_data) == :pq
    end

    test "detect_type/1 detects BQ from API response" do
      api_data = %{"bq" => %{"enabled" => true}}
      assert Quantizer.detect_type(api_data) == :bq
    end

    test "detect_type/1 detects SQ from API response" do
      api_data = %{"sq" => %{"enabled" => true}}
      assert Quantizer.detect_type(api_data) == :sq
    end

    test "detect_type/1 detects RQ from API response" do
      api_data = %{"rq" => %{"enabled" => true}}
      assert Quantizer.detect_type(api_data) == :rq
    end

    test "detect_type/1 returns nil for no quantizer" do
      api_data = %{}
      assert Quantizer.detect_type(api_data) == nil
    end

    test "from_api/1 returns appropriate config struct" do
      pq_data = %{"pq" => %{"enabled" => true, "segments" => 128}}
      assert %PQConfig{segments: 128} = Quantizer.from_api(pq_data)

      bq_data = %{"bq" => %{"enabled" => true, "cache" => true}}
      assert %BQConfig{cache: true} = Quantizer.from_api(bq_data)

      sq_data = %{"sq" => %{"enabled" => true, "trainingLimit" => 50_000}}
      assert %SQConfig{training_limit: 50_000} = Quantizer.from_api(sq_data)

      rq_data = %{"rq" => %{"enabled" => true, "bits" => 8}}
      assert %RQConfig{bits: 8} = Quantizer.from_api(rq_data)
    end

    test "from_api/1 returns nil for no quantizer" do
      assert Quantizer.from_api(%{}) == nil
      assert Quantizer.from_api(%{"other" => "data"}) == nil
    end

    test "to_api/1 dispatches to appropriate config module" do
      pq = PQConfig.new(enabled: true, segments: 128)
      assert Quantizer.to_api(pq) == %{"pq" => %{"enabled" => true, "segments" => 128}}

      bq = BQConfig.new(enabled: true, cache: true)
      assert Quantizer.to_api(bq) == %{"bq" => %{"enabled" => true, "cache" => true}}

      sq = SQConfig.new(enabled: true, training_limit: 50_000)
      assert Quantizer.to_api(sq) == %{"sq" => %{"enabled" => true, "trainingLimit" => 50_000}}

      rq = RQConfig.new(enabled: true, bits: 8)
      assert Quantizer.to_api(rq) == %{"rq" => %{"enabled" => true, "bits" => 8}}
    end

    test "to_api/1 returns empty map for nil" do
      assert Quantizer.to_api(nil) == %{}
    end

    test "pq/1 is a convenience alias for PQConfig.new/1" do
      config = Quantizer.pq(segments: 128)
      assert %PQConfig{segments: 128, enabled: true} = config
    end

    test "bq/1 is a convenience alias for BQConfig.new/1" do
      config = Quantizer.bq(cache: true)
      assert %BQConfig{cache: true, enabled: true} = config
    end

    test "sq/1 is a convenience alias for SQConfig.new/1" do
      config = Quantizer.sq(training_limit: 50_000)
      assert %SQConfig{training_limit: 50_000, enabled: true} = config
    end

    test "rq/1 is a convenience alias for RQConfig.new/1" do
      config = Quantizer.rq(bits: 8)
      assert %RQConfig{bits: 8, enabled: true} = config
    end
  end

  describe "edge cases" do
    test "PQConfig encoder with tile encoder type" do
      config =
        PQConfig.new(
          enabled: true,
          encoder: %{type: "tile", distribution: "normal"}
        )

      api_format = PQConfig.to_api(config)
      assert get_in(api_format, ["pq", "encoder", "type"]) == "tile"
      assert get_in(api_format, ["pq", "encoder", "distribution"]) == "normal"
    end

    test "PQConfig with segments = 0 means auto-calculated" do
      config = PQConfig.new(segments: 0)
      api_format = PQConfig.to_api(config)
      assert get_in(api_format, ["pq", "segments"]) == 0
    end

    test "BQConfig with cache explicitly false" do
      config = BQConfig.new(enabled: true, cache: false)
      api_format = BQConfig.to_api(config)
      assert get_in(api_format, ["bq", "cache"]) == false
    end

    test "RQConfig with different bit depths" do
      for bits <- [4, 8, 16] do
        config = RQConfig.new(bits: bits)
        api_format = RQConfig.to_api(config)
        assert get_in(api_format, ["rq", "bits"]) == bits
      end
    end

    test "SQConfig handles explicit false for cache" do
      config = SQConfig.new(cache: false)
      api_format = SQConfig.to_api(config)
      assert get_in(api_format, ["sq", "cache"]) == false
    end
  end

  describe "type specs validation" do
    test "PQConfig struct has correct fields" do
      config = %PQConfig{}
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :training_limit)
      assert Map.has_key?(config, :segments)
      assert Map.has_key?(config, :centroids)
      assert Map.has_key?(config, :encoder)
    end

    test "BQConfig struct has correct fields" do
      config = %BQConfig{}
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :cache)
      assert Map.has_key?(config, :rescore_limit)
    end

    test "SQConfig struct has correct fields" do
      config = %SQConfig{}
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :cache)
      assert Map.has_key?(config, :rescore_limit)
      assert Map.has_key?(config, :training_limit)
    end

    test "RQConfig struct has correct fields" do
      config = %RQConfig{}
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :bits)
      assert Map.has_key?(config, :cache)
      assert Map.has_key?(config, :rescore_limit)
      assert Map.has_key?(config, :training_limit)
    end
  end
end
