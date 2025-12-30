defmodule WeaviateEx.Config.ObjectTTLTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.ObjectTTL

  describe "from_duration/1" do
    test "converts days to seconds" do
      config = ObjectTTL.from_duration(days: 7)

      assert config.enabled == true
      assert config.delete_on == "_creationTimeUnix"
      assert config.default_ttl == 7 * 86_400
    end

    test "converts hours to seconds" do
      config = ObjectTTL.from_duration(hours: 24)

      assert config.enabled == true
      assert config.delete_on == "_creationTimeUnix"
      assert config.default_ttl == 24 * 3_600
    end

    test "converts minutes to seconds" do
      config = ObjectTTL.from_duration(minutes: 30)

      assert config.enabled == true
      assert config.default_ttl == 30 * 60
    end

    test "converts seconds directly" do
      config = ObjectTTL.from_duration(seconds: 3600)

      assert config.enabled == true
      assert config.default_ttl == 3600
    end

    test "combines multiple duration units" do
      config = ObjectTTL.from_duration(days: 1, hours: 12, minutes: 30, seconds: 15)

      expected = 1 * 86_400 + 12 * 3_600 + 30 * 60 + 15
      assert config.default_ttl == expected
    end

    test "raises on zero duration" do
      assert_raise ArgumentError, ~r/Duration must be positive/, fn ->
        ObjectTTL.from_duration([])
      end
    end

    test "raises on negative duration" do
      assert_raise ArgumentError, ~r/Duration must be positive/, fn ->
        ObjectTTL.from_duration(hours: -1)
      end
    end
  end

  describe "delete_by_update_time/2" do
    test "creates config with update time deletion" do
      config = ObjectTTL.delete_by_update_time(3600)

      assert config.enabled == true
      assert config.delete_on == "_lastUpdateTimeUnix"
      assert config.default_ttl == 3600
      assert config.filter_expired_objects == nil
    end

    test "accepts filter_expired_objects option" do
      config = ObjectTTL.delete_by_update_time(86_400, true)

      assert config.enabled == true
      assert config.delete_on == "_lastUpdateTimeUnix"
      assert config.default_ttl == 86_400
      assert config.filter_expired_objects == true
    end

    test "rejects non-positive TTL" do
      assert_raise FunctionClauseError, fn ->
        ObjectTTL.delete_by_update_time(0)
      end

      assert_raise FunctionClauseError, fn ->
        ObjectTTL.delete_by_update_time(-100)
      end
    end
  end

  describe "delete_by_creation_time/2" do
    test "creates config with creation time deletion" do
      config = ObjectTTL.delete_by_creation_time(7200)

      assert config.enabled == true
      assert config.delete_on == "_creationTimeUnix"
      assert config.default_ttl == 7200
      assert config.filter_expired_objects == nil
    end

    test "accepts filter_expired_objects option" do
      config = ObjectTTL.delete_by_creation_time(3600, false)

      assert config.filter_expired_objects == false
    end
  end

  describe "delete_by_date_property/3" do
    test "creates config with custom date property" do
      config = ObjectTTL.delete_by_date_property("expiry_date")

      assert config.enabled == true
      assert config.delete_on == "expiry_date"
      assert config.default_ttl == 0
      assert config.filter_expired_objects == nil
    end

    test "accepts ttl_offset parameter" do
      config = ObjectTTL.delete_by_date_property("event_date", 3600)

      assert config.delete_on == "event_date"
      assert config.default_ttl == 3600
    end

    test "accepts negative ttl_offset" do
      config = ObjectTTL.delete_by_date_property("deadline", -86_400)

      assert config.delete_on == "deadline"
      assert config.default_ttl == -86_400
    end

    test "accepts all parameters" do
      config = ObjectTTL.delete_by_date_property("scheduled_deletion", 1800, true)

      assert config.enabled == true
      assert config.delete_on == "scheduled_deletion"
      assert config.default_ttl == 1800
      assert config.filter_expired_objects == true
    end
  end

  describe "disable/0" do
    test "creates disabled config" do
      config = ObjectTTL.disable()

      assert config.enabled == false
      assert config.delete_on == nil
      assert config.default_ttl == nil
      assert config.filter_expired_objects == nil
    end
  end

  describe "to_map/1" do
    test "converts update time config to map" do
      config = ObjectTTL.delete_by_update_time(3600, true)
      map = ObjectTTL.to_map(config)

      assert map == %{
               "enabled" => true,
               "deleteOn" => "_lastUpdateTimeUnix",
               "defaultTtl" => 3600,
               "filterExpiredObjects" => true
             }
    end

    test "excludes nil values from map" do
      config = ObjectTTL.delete_by_creation_time(7200)
      map = ObjectTTL.to_map(config)

      assert map == %{
               "enabled" => true,
               "deleteOn" => "_creationTimeUnix",
               "defaultTtl" => 7200
             }

      refute Map.has_key?(map, "filterExpiredObjects")
    end

    test "converts disabled config to map" do
      config = ObjectTTL.disable()
      map = ObjectTTL.to_map(config)

      assert map == %{"enabled" => false}
    end
  end

  describe "from_map/1" do
    test "creates config from API response map" do
      map = %{
        "enabled" => true,
        "deleteOn" => "_creationTimeUnix",
        "defaultTtl" => 3600,
        "filterExpiredObjects" => true
      }

      config = ObjectTTL.from_map(map)

      assert config.enabled == true
      assert config.delete_on == "_creationTimeUnix"
      assert config.default_ttl == 3600
      assert config.filter_expired_objects == true
    end

    test "handles missing optional fields" do
      map = %{"enabled" => true, "deleteOn" => "my_date", "defaultTtl" => 0}

      config = ObjectTTL.from_map(map)

      assert config.enabled == true
      assert config.delete_on == "my_date"
      assert config.default_ttl == 0
      assert config.filter_expired_objects == nil
    end

    test "handles empty map" do
      config = ObjectTTL.from_map(%{})

      assert config.enabled == false
      assert config.delete_on == nil
      assert config.default_ttl == nil
      assert config.filter_expired_objects == nil
    end
  end

  describe "roundtrip" do
    test "to_map and from_map are inverse operations" do
      original = ObjectTTL.delete_by_update_time(86_400, true)
      map = ObjectTTL.to_map(original)
      restored = ObjectTTL.from_map(map)

      assert restored.enabled == original.enabled
      assert restored.delete_on == original.delete_on
      assert restored.default_ttl == original.default_ttl
      assert restored.filter_expired_objects == original.filter_expired_objects
    end
  end
end
