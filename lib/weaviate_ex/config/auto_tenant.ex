defmodule WeaviateEx.Config.AutoTenant do
  @moduledoc """
  Auto-tenant configuration for multi-tenant collections.

  Weaviate supports automatic tenant management that can:
  - Automatically create tenants when inserting data for non-existent tenants
  - Automatically delete empty tenants after a specified period

  ## Usage

      # Enable auto-tenant creation
      auto_tenant = WeaviateEx.Config.AutoTenant.enable()

      # Enable with auto-deletion of empty tenants
      auto_tenant = WeaviateEx.Config.AutoTenant.enable(auto_delete_timeout: 86400)

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
          auto_delete_timeout: non_neg_integer() | nil
        }

  defstruct [
    :enabled,
    :auto_delete_timeout
  ]

  @doc """
  Enable auto-tenant creation.

  When enabled, Weaviate will automatically create tenants when data is
  inserted for a tenant that doesn't exist yet.

  ## Options

    - `:auto_delete_timeout` - Time in seconds after which empty tenants are
      automatically deleted. If not specified, auto-deletion is disabled.

  ## Examples

      # Just enable auto-creation
      WeaviateEx.Config.AutoTenant.enable()

      # Enable with auto-deletion after 24 hours of inactivity
      WeaviateEx.Config.AutoTenant.enable(auto_delete_timeout: 86400)
  """
  @spec enable(keyword()) :: t()
  def enable(opts \\ []) do
    %__MODULE__{
      enabled: true,
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

  ## Examples

      # Custom configuration
      WeaviateEx.Config.AutoTenant.new(enabled: true, auto_delete_timeout: 3600)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
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
        "autoDeleteTimeout" => 3600
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    %{"enabled" => config.enabled}
    |> maybe_put("autoDeleteTimeout", config.auto_delete_timeout)
  end

  @doc """
  Create an auto-tenant config from a map (e.g., from API response).

  ## Examples

      iex> map = %{"enabled" => true, "autoDeleteTimeout" => 3600}
      iex> WeaviateEx.Config.AutoTenant.from_map(map)
      %WeaviateEx.Config.AutoTenant{enabled: true, auto_delete_timeout: 3600}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: Map.get(map, "enabled", false),
      auto_delete_timeout: Map.get(map, "autoDeleteTimeout")
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
