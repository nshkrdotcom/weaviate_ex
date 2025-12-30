defmodule WeaviateEx.Schema.MultiTenancyConfig do
  @moduledoc """
  Multi-tenancy configuration for collection schema.

  Provides configuration options for multi-tenant collections including
  auto-tenant creation and activation features.

  ## Features

  - **Auto-Tenant Creation**: Automatically create tenants on first data insertion
  - **Auto-Tenant Activation**: Automatically activate tenants when accessed

  ## Examples

      # Basic multi-tenancy enabled
      config = MultiTenancyConfig.new(enabled: true)

      # With auto-tenant creation
      config = MultiTenancyConfig.new(
        enabled: true,
        auto_tenant_creation: true
      )

      # With auto-tenant activation
      config = MultiTenancyConfig.new(
        enabled: true,
        auto_tenant_activation: true
      )

      # Full configuration
      config = MultiTenancyConfig.new(
        enabled: true,
        auto_tenant_creation: true,
        auto_tenant_activation: true
      )
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          auto_tenant_creation: boolean(),
          auto_tenant_activation: boolean()
        }

  defstruct enabled: false, auto_tenant_creation: false, auto_tenant_activation: false

  @doc """
  Create a new multi-tenancy configuration.

  ## Options

  - `:enabled` - Enable multi-tenancy for the collection (default: false)
  - `:auto_tenant_creation` - Automatically create tenants on first data insertion (default: false)
  - `:auto_tenant_activation` - Automatically activate tenants when accessed (default: false)

  ## Examples

      MultiTenancyConfig.new(enabled: true)
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: false, auto_tenant_activation: false}

      MultiTenancyConfig.new(enabled: true, auto_tenant_creation: true)
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: true, auto_tenant_activation: false}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      auto_tenant_creation: Keyword.get(opts, :auto_tenant_creation, false),
      auto_tenant_activation: Keyword.get(opts, :auto_tenant_activation, false)
    }
  end

  @doc """
  Create a configuration with multi-tenancy enabled.

  This is a convenience function for creating a basic multi-tenant configuration.

  ## Examples

      MultiTenancyConfig.enabled()
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: false, auto_tenant_activation: false}
  """
  @spec enabled() :: t()
  def enabled, do: %__MODULE__{enabled: true}

  @doc """
  Create a configuration with multi-tenancy disabled.

  ## Examples

      MultiTenancyConfig.disabled()
      # => %MultiTenancyConfig{enabled: false, auto_tenant_creation: false, auto_tenant_activation: false}
  """
  @spec disabled() :: t()
  def disabled, do: %__MODULE__{enabled: false}

  @doc """
  Create a configuration with auto-tenant creation enabled.

  When auto-tenant creation is enabled, tenants are automatically created
  when data is first inserted for a non-existent tenant.

  ## Examples

      MultiTenancyConfig.with_auto_creation()
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: true, auto_tenant_activation: false}
  """
  @spec with_auto_creation() :: t()
  def with_auto_creation do
    %__MODULE__{enabled: true, auto_tenant_creation: true}
  end

  @doc """
  Create a configuration with auto-tenant activation enabled.

  When auto-tenant activation is enabled, inactive tenants are automatically
  activated when they are accessed.

  ## Examples

      MultiTenancyConfig.with_auto_activation()
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: false, auto_tenant_activation: true}
  """
  @spec with_auto_activation() :: t()
  def with_auto_activation do
    %__MODULE__{enabled: true, auto_tenant_activation: true}
  end

  @doc """
  Create a fully automatic tenant configuration.

  This enables both auto-tenant creation and activation.

  ## Examples

      MultiTenancyConfig.fully_automatic()
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: true, auto_tenant_activation: true}
  """
  @spec fully_automatic() :: t()
  def fully_automatic do
    %__MODULE__{enabled: true, auto_tenant_creation: true, auto_tenant_activation: true}
  end

  @doc """
  Convert the configuration to a map for the Weaviate API.

  ## Examples

      config = MultiTenancyConfig.new(enabled: true, auto_tenant_creation: true)
      MultiTenancyConfig.to_map(config)
      # => %{"enabled" => true, "autoTenantCreation" => true, "autoTenantActivation" => false}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    %{
      "enabled" => config.enabled,
      "autoTenantCreation" => config.auto_tenant_creation,
      "autoTenantActivation" => config.auto_tenant_activation
    }
  end

  @doc """
  Create a configuration from a map (e.g., from API response).

  ## Examples

      map = %{"enabled" => true, "autoTenantCreation" => true}
      MultiTenancyConfig.from_map(map)
      # => %MultiTenancyConfig{enabled: true, auto_tenant_creation: true, auto_tenant_activation: false}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: Map.get(map, "enabled", false),
      auto_tenant_creation: Map.get(map, "autoTenantCreation", false),
      auto_tenant_activation: Map.get(map, "autoTenantActivation", false)
    }
  end
end
