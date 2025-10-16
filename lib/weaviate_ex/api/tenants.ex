defmodule WeaviateEx.API.Tenants do
  @moduledoc """
  Multi-tenancy operations for Phase 2.5.

  Provides complete tenant management:
  - CRUD operations (list, get, create, update, delete)
  - Activity status management (HOT, COLD, FROZEN)
  - Tenant isolation and filtering
  - Batch operations
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type collection_name :: String.t()
  @type tenant_name :: String.t()
  @type tenant_names :: tenant_name() | [tenant_name()]
  @type opts :: keyword()
  @type activity_status :: :hot | :cold | :frozen

  @doc """
  List all tenants for a collection.

  ## Examples

      {:ok, tenants} = Tenants.list(client, "Article")

  ## Returns
    * `{:ok, [map()]}` - List of tenants
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, collection_name) do
    Client.request(client, :get, "/v1/schema/#{collection_name}/tenants", nil, [])
  end

  @doc """
  Get specific tenant information.

  ## Examples

      {:ok, tenant} = Tenants.get(client, "Article", "TenantA")

  ## Returns
    * `{:ok, map()}` - Tenant information
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get(Client.t(), collection_name(), tenant_name()) ::
          {:ok, map()} | {:error, Error.t()}
  def get(client, collection_name, tenant_name) do
    Client.request(client, :get, "/v1/schema/#{collection_name}/tenants/#{tenant_name}", nil, [])
  end

  @doc """
  Create one or more tenants.

  ## Examples

      {:ok, _} = Tenants.create(client, "Article", "TenantA")
      {:ok, _} = Tenants.create(client, "Article", ["TenantA", "TenantB"])
      {:ok, _} = Tenants.create(client, "Article", "TenantA", activity_status: :cold)

  ## Returns
    * `{:ok, [map()]}` - Created tenants
    * `{:error, Error.t()}` - Error if creation fails
  """
  @spec create(Client.t(), collection_name(), tenant_names(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def create(client, collection_name, tenant_names, opts \\ [])

  def create(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
    create(client, collection_name, [tenant_name], opts)
  end

  def create(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
    activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()

    tenants =
      Enum.map(tenant_names, fn name ->
        %{"name" => name, "activityStatus" => activity_status}
      end)

    Client.request(client, :post, "/v1/schema/#{collection_name}/tenants", tenants, [])
  end

  @doc """
  Update tenant(s) activity status.

  ## Examples

      {:ok, _} = Tenants.update(client, "Article", "TenantA", activity_status: :cold)
      {:ok, _} = Tenants.update(client, "Article", ["TenantA", "TenantB"], activity_status: :hot)

  ## Returns
    * `{:ok, [map()]}` - Updated tenants
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec update(Client.t(), collection_name(), tenant_names(), opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def update(client, collection_name, tenant_name, opts) when is_binary(tenant_name) do
    update(client, collection_name, [tenant_name], opts)
  end

  def update(client, collection_name, tenant_names, opts) when is_list(tenant_names) do
    activity_status = Keyword.get(opts, :activity_status, :hot) |> activity_to_string()

    tenants =
      Enum.map(tenant_names, fn name ->
        %{"name" => name, "activityStatus" => activity_status}
      end)

    Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, [])
  end

  @doc """
  Delete one or more tenants.

  ## Examples

      {:ok, _} = Tenants.delete(client, "Article", "TenantA")
      {:ok, _} = Tenants.delete(client, "Article", ["TenantA", "TenantB"])

  ## Returns
    * `{:ok, map()}` - Empty map on success
    * `{:error, Error.t()}` - Error if deletion fails
  """
  @spec delete(Client.t(), collection_name(), tenant_names()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(client, collection_name, tenant_name) when is_binary(tenant_name) do
    delete(client, collection_name, [tenant_name])
  end

  def delete(client, collection_name, tenant_names) when is_list(tenant_names) do
    Client.request(client, :delete, "/v1/schema/#{collection_name}/tenants", tenant_names, [])
  end

  @doc """
  Check if tenant exists.

  ## Examples

      {:ok, true} = Tenants.exists?(client, "Article", "TenantA")
      {:ok, false} = Tenants.exists?(client, "Article", "NonExistent")

  ## Returns
    * `{:ok, boolean()}` - True if exists, false otherwise
  """
  @spec exists?(Client.t(), collection_name(), tenant_name()) :: {:ok, boolean()}
  def exists?(client, collection_name, tenant_name) do
    case get(client, collection_name, tenant_name) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  @doc """
  Activate tenant (set to HOT status).

  ## Examples

      {:ok, _} = Tenants.activate(client, "Article", "TenantA")
      {:ok, _} = Tenants.activate(client, "Article", ["TenantA", "TenantB"])

  ## Returns
    * `{:ok, [map()]}` - Updated tenants
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec activate(Client.t(), collection_name(), tenant_names()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def activate(client, collection_name, tenant_names) do
    update(client, collection_name, tenant_names, activity_status: :hot)
  end

  @doc """
  Deactivate tenant (set to COLD status).

  ## Examples

      {:ok, _} = Tenants.deactivate(client, "Article", "TenantA")

  ## Returns
    * `{:ok, [map()]}` - Updated tenants
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec deactivate(Client.t(), collection_name(), tenant_names()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def deactivate(client, collection_name, tenant_names) do
    update(client, collection_name, tenant_names, activity_status: :cold)
  end

  @doc """
  Count total tenants for a collection.

  ## Examples

      {:ok, 5} = Tenants.count(client, "Article")

  ## Returns
    * `{:ok, integer()}` - Number of tenants
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec count(Client.t(), collection_name()) :: {:ok, integer()} | {:error, Error.t()}
  def count(client, collection_name) do
    case list(client, collection_name) do
      {:ok, tenants} -> {:ok, length(tenants)}
      error -> error
    end
  end

  @doc """
  List only active (HOT) tenants.

  ## Examples

      {:ok, active_tenants} = Tenants.list_active(client, "Article")

  ## Returns
    * `{:ok, [map()]}` - List of active tenants
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list_active(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_active(client, collection_name) do
    case list(client, collection_name) do
      {:ok, tenants} ->
        active = Enum.filter(tenants, &(&1["activityStatus"] == "HOT"))
        {:ok, active}

      error ->
        error
    end
  end

  @doc """
  List only inactive (COLD/FROZEN) tenants.

  ## Examples

      {:ok, inactive_tenants} = Tenants.list_inactive(client, "Article")

  ## Returns
    * `{:ok, [map()]}` - List of inactive tenants
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list_inactive(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_inactive(client, collection_name) do
    case list(client, collection_name) do
      {:ok, tenants} ->
        inactive = Enum.filter(tenants, &(&1["activityStatus"] in ["COLD", "FROZEN"]))
        {:ok, inactive}

      error ->
        error
    end
  end

  ## Private Helpers

  defp activity_to_string(:hot), do: "HOT"
  defp activity_to_string(:cold), do: "COLD"
  defp activity_to_string(:frozen), do: "FROZEN"
  defp activity_to_string(status) when is_binary(status), do: String.upcase(status)
end
