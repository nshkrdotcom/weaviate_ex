defmodule WeaviateEx.Batch.ConfigTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.Config

  @moduletag :unit

  describe "new/0" do
    test "creates config with default values" do
      config = Config.new()

      assert config.max_stored_results == 100_000
      assert config.auto_retry == true
      assert config.max_retries == 3
      assert config.retry_delay_ms == 1000
      assert config.max_retry_delay_ms == 60_000
      assert config.on_permanent_failure == nil
      assert config.on_retry == nil
    end
  end

  describe "new/1" do
    test "allows overriding max_stored_results" do
      config = Config.new(max_stored_results: 50_000)
      assert config.max_stored_results == 50_000
    end

    test "allows overriding auto_retry" do
      config = Config.new(auto_retry: false)
      assert config.auto_retry == false
    end

    test "allows overriding max_retries" do
      config = Config.new(max_retries: 5)
      assert config.max_retries == 5
    end

    test "allows overriding retry_delay_ms" do
      config = Config.new(retry_delay_ms: 2000)
      assert config.retry_delay_ms == 2000
    end

    test "allows setting on_permanent_failure callback" do
      callback = fn _objects -> :ok end
      config = Config.new(on_permanent_failure: callback)
      assert config.on_permanent_failure == callback
    end

    test "allows setting on_retry callback" do
      callback = fn _objects, _attempt -> :ok end
      config = Config.new(on_retry: callback)
      assert config.on_retry == callback
    end

    test "accepts multiple overrides" do
      config =
        Config.new(
          max_stored_results: 10_000,
          max_retries: 10,
          retry_delay_ms: 500,
          auto_retry: false
        )

      assert config.max_stored_results == 10_000
      assert config.max_retries == 10
      assert config.retry_delay_ms == 500
      assert config.auto_retry == false
    end
  end

  describe "default_max_stored_results/0" do
    test "returns 100,000" do
      assert Config.default_max_stored_results() == 100_000
    end
  end

  describe "default_retry_delay_ms/0" do
    test "returns 1000" do
      assert Config.default_retry_delay_ms() == 1000
    end
  end

  describe "default_max_retries/0" do
    test "returns 3" do
      assert Config.default_max_retries() == 3
    end
  end

  describe "auto_retry_enabled?/1" do
    test "returns true when auto_retry is true" do
      config = Config.new(auto_retry: true)
      assert Config.auto_retry_enabled?(config)
    end

    test "returns false when auto_retry is false" do
      config = Config.new(auto_retry: false)
      refute Config.auto_retry_enabled?(config)
    end
  end

  describe "merge/2" do
    test "merges two configs with second taking precedence" do
      base = Config.new(max_retries: 3, retry_delay_ms: 1000)
      override = Config.new(max_retries: 5)

      merged = Config.merge(base, override)

      assert merged.max_retries == 5
      # Unchanged values should be preserved
      assert merged.max_stored_results == 100_000
    end

    test "merges config with keyword list" do
      base = Config.new(max_retries: 3)
      merged = Config.merge(base, max_retries: 10, auto_retry: false)

      assert merged.max_retries == 10
      assert merged.auto_retry == false
    end

    test "ignores nil values in override" do
      base = Config.new(max_retries: 5)
      merged = Config.merge(base, max_retries: nil)

      assert merged.max_retries == 5
    end
  end

  describe "to_keyword/1" do
    test "converts config to keyword list" do
      config = Config.new(max_retries: 5, retry_delay_ms: 2000)
      kw = Config.to_keyword(config)

      assert kw[:max_retries] == 5
      assert kw[:retry_delay_ms] == 2000
      assert kw[:max_stored_results] == 100_000
    end

    test "excludes nil values" do
      config = Config.new()
      kw = Config.to_keyword(config)

      refute Keyword.has_key?(kw, :on_permanent_failure)
      refute Keyword.has_key?(kw, :on_retry)
    end
  end
end
