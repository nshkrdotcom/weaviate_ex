defmodule WeaviateEx.Config.AutoTenantTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Config.AutoTenant

  describe "enable/1" do
    test "enables auto-tenant with defaults (auto_creation true)" do
      config = AutoTenant.enable()

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == false
      assert config.auto_delete_timeout == nil
    end

    test "enables auto-tenant with auto_delete_timeout" do
      config = AutoTenant.enable(auto_delete_timeout: 86_400)

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_delete_timeout == 86_400
    end

    test "enables auto-tenant with auto_activation" do
      config = AutoTenant.enable(auto_activation: true)

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == true
    end

    test "enables auto-tenant with both auto_creation and auto_activation" do
      config = AutoTenant.enable(auto_creation: true, auto_activation: true)

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == true
    end

    test "can disable auto_creation while enabling auto_activation" do
      config = AutoTenant.enable(auto_creation: false, auto_activation: true)

      assert config.enabled == true
      assert config.auto_creation == false
      assert config.auto_activation == true
    end
  end

  describe "disable/0" do
    test "disables auto-tenant" do
      config = AutoTenant.disable()

      assert config.enabled == false
      assert config.auto_creation == false
      assert config.auto_activation == false
      assert config.auto_delete_timeout == nil
    end
  end

  describe "new/1" do
    test "creates config with defaults (both false)" do
      config = AutoTenant.new([])

      assert config.enabled == false
      assert config.auto_creation == false
      assert config.auto_activation == false
    end

    test "creates custom config with all options" do
      config =
        AutoTenant.new(
          enabled: true,
          auto_creation: true,
          auto_activation: true,
          auto_delete_timeout: 3600
        )

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == true
      assert config.auto_delete_timeout == 3600
    end

    test "enables auto_creation only" do
      config = AutoTenant.new(auto_creation: true)

      assert config.enabled == false
      assert config.auto_creation == true
      assert config.auto_activation == false
    end

    test "enables auto_activation only" do
      config = AutoTenant.new(auto_activation: true)

      assert config.enabled == false
      assert config.auto_creation == false
      assert config.auto_activation == true
    end

    test "enables both auto_creation and auto_activation" do
      config = AutoTenant.new(auto_creation: true, auto_activation: true)

      assert config.enabled == false
      assert config.auto_creation == true
      assert config.auto_activation == true
    end
  end

  describe "with_auto_creation/0" do
    test "creates config with auto_creation enabled" do
      config = AutoTenant.with_auto_creation()

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == false
    end
  end

  describe "with_auto_activation/0" do
    test "creates config with auto_activation enabled" do
      config = AutoTenant.with_auto_activation()

      assert config.enabled == true
      assert config.auto_creation == false
      assert config.auto_activation == true
    end
  end

  describe "fully_automatic/0" do
    test "creates config with both auto_creation and auto_activation enabled" do
      config = AutoTenant.fully_automatic()

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == true
    end
  end

  describe "to_map/1" do
    test "converts enabled config to map with all fields" do
      config = AutoTenant.enable()
      map = AutoTenant.to_map(config)

      assert map == %{
               "enabled" => true,
               "autoTenantCreation" => true,
               "autoTenantActivation" => false
             }
    end

    test "includes auto_delete_timeout when set" do
      config = AutoTenant.enable(auto_delete_timeout: 3600)
      map = AutoTenant.to_map(config)

      assert map == %{
               "enabled" => true,
               "autoTenantCreation" => true,
               "autoTenantActivation" => false,
               "autoDeleteTimeout" => 3600
             }
    end

    test "converts disabled config to map" do
      config = AutoTenant.disable()
      map = AutoTenant.to_map(config)

      assert map == %{
               "enabled" => false,
               "autoTenantCreation" => false,
               "autoTenantActivation" => false
             }
    end

    test "converts fully_automatic config to map" do
      config = AutoTenant.fully_automatic()
      map = AutoTenant.to_map(config)

      assert map == %{
               "enabled" => true,
               "autoTenantCreation" => true,
               "autoTenantActivation" => true
             }
    end
  end

  describe "from_map/1" do
    test "parses enabled config from map" do
      map = %{"enabled" => true}
      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_creation == false
      assert config.auto_activation == false
      assert config.auto_delete_timeout == nil
    end

    test "parses config with auto_delete_timeout" do
      map = %{"enabled" => true, "autoDeleteTimeout" => 7200}
      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_delete_timeout == 7200
    end

    test "parses config with autoTenantCreation" do
      map = %{"autoTenantCreation" => true}
      config = AutoTenant.from_map(map)

      assert config.auto_creation == true
      assert config.auto_activation == false
    end

    test "parses config with autoTenantActivation" do
      map = %{"autoTenantActivation" => true}
      config = AutoTenant.from_map(map)

      assert config.auto_creation == false
      assert config.auto_activation == true
    end

    test "parses full config from map" do
      map = %{
        "enabled" => true,
        "autoTenantCreation" => true,
        "autoTenantActivation" => true,
        "autoDeleteTimeout" => 3600
      }

      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_creation == true
      assert config.auto_activation == true
      assert config.auto_delete_timeout == 3600
    end

    test "defaults to disabled for missing enabled key" do
      map = %{}
      config = AutoTenant.from_map(map)

      assert config.enabled == false
      assert config.auto_creation == false
      assert config.auto_activation == false
    end

    test "handles missing fields gracefully" do
      map = %{"enabled" => true}
      config = AutoTenant.from_map(map)

      assert config.enabled == true
      assert config.auto_creation == false
      assert config.auto_activation == false
      assert config.auto_delete_timeout == nil
    end

    test "round-trip conversion maintains values" do
      original =
        AutoTenant.new(
          enabled: true,
          auto_creation: true,
          auto_activation: true,
          auto_delete_timeout: 86_400
        )

      map = AutoTenant.to_map(original)
      restored = AutoTenant.from_map(map)

      assert restored.enabled == original.enabled
      assert restored.auto_creation == original.auto_creation
      assert restored.auto_activation == original.auto_activation
      assert restored.auto_delete_timeout == original.auto_delete_timeout
    end

    test "round-trip conversion for fully_automatic" do
      original = AutoTenant.fully_automatic()
      map = AutoTenant.to_map(original)
      restored = AutoTenant.from_map(map)

      assert restored.enabled == original.enabled
      assert restored.auto_creation == original.auto_creation
      assert restored.auto_activation == original.auto_activation
    end
  end
end
