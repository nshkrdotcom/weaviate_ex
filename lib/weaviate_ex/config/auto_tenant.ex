defmodule WeaviateEx.Config.AutoTenant do
  @moduledoc """
  Auto-tenant configuration for multi-tenant collections.

  Weaviate supports automatic tenant management that can:
  - Automatically create tenants when inserting data for non-existent tenants
  - Automatically activate tenants (set to HOT) on first operation
  - Automatically delete empty tenants after a specified period

  ## Usage

      # Enable auto-tenant creation
      auto_tenant = WeaviateEx.Config.AutoTenant.enable()

      # Enable with auto-deletion of empty tenants
      auto_tenant = WeaviateEx.Config.AutoTenant.enable(auto_delete_timeout: 86400)

      # Enable with auto-creation and auto-activation
      auto_tenant = WeaviateEx.Config.AutoTenant.new(
        auto_creation: true,
        auto_activation: true
      )

      # Include in collection creation
      WeaviateEx.Collections.create(client, "MyClass", %{
        properties: [...],
        multi_tenancy: %{enabled: true},
        auto_tenant: auto_tenant
      })

      # Disable auto-tenant
      WeaviateEx.Collections.update("MyClass", %{
        auto_tenant: WeaviateEx.Config.AutoTenant.disable()
      })
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          auto_creation: boolean(),
          auto_activation: boolean(),
          auto_delete_timeout: non_neg_integer() | nil
        }

  defstruct enabled: false,
            auto_creation: false,
            auto_activation: false,
            auto_delete_timeout: nil

  @doc """
  Enable auto-tenant creation.

  When enabled, Weaviate will automatically create tenants when data is
  inserted for a tenant that doesn't exist yet.

  ## Options

    - `:auto_creation` - Enable auto-creation of tenants (default: true when using enable/1)
    - `:auto_activation` - Enable auto-activation of tenants (default: false)
    - `:auto_delete_timeout` - Time in seconds after which empty tenants are
      automatically deleted. If not specified, auto-deletion is disabled.

  ## Examples

      # Just enable auto-creation
      WeaviateEx.Config.AutoTenant.enable()

      # Enable with auto-deletion after 24 hours of inactivity
      WeaviateEx.Config.AutoTenant.enable(auto_delete_timeout: 86400)

      # Enable with auto-activation
      WeaviateEx.Config.AutoTenant.enable(auto_activation: true)

      # Enable both auto-creation and auto-activation
      WeaviateEx.Config.AutoTenant.enable(auto_creation: true, auto_activation: true)
  """
  @spec enable(keyword()) :: t()
  def enable(opts \\ []) do
    %__MODULE__{
      enabled: true,
      auto_creation: Keyword.get(opts, :auto_creation, true),
      auto_activation: Keyword.get(opts, :auto_activation, false),
      auto_delete_timeout: Keyword.get(opts, :auto_delete_timeout)
    }
  end

  @doc """
  Disable auto-tenant functionality.

  Use this when updating a collection to turn off automatic tenant management.

  ## Examples

      WeaviateEx.Collections.update("MyClass", %{
        auto_tenant: WeaviateEx.Config.AutoTenant.disable()
      })
  """
  @spec disable() :: t()
  def disable do
    %__MODULE__{enabled: false}
  end

  @doc """
  Create an auto-tenant config with custom settings.

  ## Options

    - `:enabled` - Enable auto-tenant features (default: false)
    - `:auto_creation` - Enable auto-creation of tenants (default: false)
    - `:auto_activation` - Enable auto-activation of tenants (default: false)
    - `:auto_delete_timeout` - Time in seconds after which empty tenants are
      automatically deleted. If not specified, auto-deletion is disabled.

  ## Examples

      # Custom configuration with auto-deletion
      WeaviateEx.Config.AutoTenant.new(enabled: true, auto_delete_timeout: 3600)

      # Enable auto-creation and auto-activation
      WeaviateEx.Config.AutoTenant.new(auto_creation: true, auto_activation: true)

      # Full configuration
      WeaviateEx.Config.AutoTenant.new(
        enabled: true,
        auto_creation: true,
        auto_activation: true,
        auto_delete_timeout: 86400
      )
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      auto_creation: Keyword.get(opts, :auto_creation, false),
      auto_activation: Keyword.get(opts, :auto_activation, false),
      auto_delete_timeout: Keyword.get(opts, :auto_delete_timeout)
    }
  end

  @doc """
  Convert an auto-tenant config struct to a map for the Weaviate API.

  ## Examples

      iex> config = WeaviateEx.Config.AutoTenant.enable(auto_delete_timeout: 3600)
      iex> WeaviateEx.Config.AutoTenant.to_map(config)
      %{
        "enabled" => true,
        "autoTenantCreation" => true,
        "autoTenantActivation" => false,
        "autoDeleteTimeout" => 3600
      }

      iex> config = WeaviateEx.Config.AutoTenant.new(auto_creation: true, auto_activation: true)
      iex> WeaviateEx.Config.AutoTenant.to_map(config)
      %{
        "enabled" => false,
        "autoTenantCreation" => true,
        "autoTenantActivation" => true
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    %{
      "enabled" => config.enabled,
      "autoTenantCreation" => config.auto_creation,
      "autoTenantActivation" => config.auto_activation
    }
    |> maybe_put("autoDeleteTimeout", config.auto_delete_timeout)
  end

  @doc """
  Create an auto-tenant config from a map (e.g., from API response).

  ## Examples

      iex> map = %{"enabled" => true, "autoDeleteTimeout" => 3600}
      iex> WeaviateEx.Config.AutoTenant.from_map(map)
      %WeaviateEx.Config.AutoTenant{enabled: true, auto_creation: false, auto_activation: false, auto_delete_timeout: 3600}

      iex> map = %{"autoTenantCreation" => true, "autoTenantActivation" => true}
      iex> WeaviateEx.Config.AutoTenant.from_map(map)
      %WeaviateEx.Config.AutoTenant{enabled: false, auto_creation: true, auto_activation: true, auto_delete_timeout: nil}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: Map.get(map, "enabled", false),
      auto_creation: Map.get(map, "autoTenantCreation", false),
      auto_activation: Map.get(map, "autoTenantActivation", false),
      auto_delete_timeout: Map.get(map, "autoDeleteTimeout")
    }
  end

  @doc """
  Create a configuration with auto-tenant creation enabled.

  When auto-tenant creation is enabled, tenants are automatically created
  when data is first inserted for a non-existent tenant.

  ## Examples

      WeaviateEx.Config.AutoTenant.with_auto_creation()
      # => %WeaviateEx.Config.AutoTenant{enabled: true, auto_creation: true, auto_activation: false}
  """
  @spec with_auto_creation() :: t()
  def with_auto_creation do
    %__MODULE__{enabled: true, auto_creation: true}
  end

  @doc """
  Create a configuration with auto-tenant activation enabled.

  When auto-tenant activation is enabled, inactive tenants are automatically
  activated (set to HOT) when they are accessed.

  ## Examples

      WeaviateEx.Config.AutoTenant.with_auto_activation()
      # => %WeaviateEx.Config.AutoTenant{enabled: true, auto_creation: false, auto_activation: true}
  """
  @spec with_auto_activation() :: t()
  def with_auto_activation do
    %__MODULE__{enabled: true, auto_activation: true}
  end

  @doc """
  Create a fully automatic tenant configuration.

  This enables both auto-tenant creation and activation.

  ## Examples

      WeaviateEx.Config.AutoTenant.fully_automatic()
      # => %WeaviateEx.Config.AutoTenant{enabled: true, auto_creation: true, auto_activation: true}
  """
  @spec fully_automatic() :: t()
  def fully_automatic do
    %__MODULE__{enabled: true, auto_creation: true, auto_activation: true}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
