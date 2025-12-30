defmodule WeaviateEx.Config.AutoTenantTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.AutoTenant

  describe "enable/1" do
    test "enables auto-tenant with defaults" do
      config = AutoTenant.enable()

      assert config.enabled == true
      assert config.auto_delete_timeout == nil
    end

    test "enables auto-tenant with auto_delete_timeout" do
      config = AutoTenant.enable(auto_delete_timeout: 86_400)

      assert config.enabled == true
      assert config.auto_delete_timeout == 86_400
    end
  end

  describe "disable/0" do
    test "disables auto-tenant" do
      config = AutoTenant.disable()

      assert config.enabled == false
      assert config.auto_delete_timeout == nil
    end
  end

  describe "new/1" do
    test "creates custom config" do
      config = AutoTenant.new(enabled: true, auto_delete_timeout: 3600)

      assert config.enabled == true
      assert config.auto_delete_timeout == 3600
    end

    test "defaults to disabled when not specified" do
      config = AutoTenant.new([])

      assert config.enabled == false
    end
  end

  describe "to_map/1" do
    test "converts enabled config to map" do
      config = AutoTenant.enable()
      map = AutoTenant.to_map(config)

      assert map == %{"enabled" => true}
    end

    test "includes auto_delete_timeout when set" do
      config = AutoTenant.enable(auto_delete_timeout: 3600)
      map = AutoTenant.to_map(config)

      assert map == %{"enabled" => true, "autoDeleteTimeout" => 3600}
    end

    test "converts disabled config to map" do
      config = AutoTenant.disable()
      map = AutoTenant.to_map(config)

      assert map == %{"enabled" => false}
    end
  end

  describe "from_map/1" do
    test "parses enabled config from map" do
      map = %{"enabled" => true}
      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_delete_timeout == nil
    end

    test "parses config with auto_delete_timeout" do
      map = %{"enabled" => true, "autoDeleteTimeout" => 7200}
      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_delete_timeout == 7200
    end

    test "defaults to disabled for missing enabled key" do
      map = %{}
      config = AutoTenant.from_map(map)

      assert config.enabled == false
    end

    test "round-trip conversion maintains values" do
      original = AutoTenant.enable(auto_delete_timeout: 86_400)
      map = AutoTenant.to_map(original)
      restored = AutoTenant.from_map(map)

      assert restored.enabled == original.enabled
      assert restored.auto_delete_timeout == original.auto_delete_timeout
    end
  end
end
