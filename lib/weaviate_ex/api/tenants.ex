defmodule WeaviateEx.API.Tenants do
  @moduledoc """
  Multi-tenancy operations with gRPC support.

  Provides complete tenant management:
  - CRUD operations (list, get, create, update, delete)
  - Activity status management (HOT, COLD, FROZEN)
  - Tenant isolation and filtering
  - Batch operations

  Uses gRPC for list/get operations when available for optimal performance.
  Create, update, and delete operations use HTTP as they're not available via gRPC.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Services.Tenants, as: GRPCTenants

  @type collection_name :: String.t()
  @type tenant_name :: String.t()
  @type tenant_names :: tenant_name() | [tenant_name()]
  @type opts :: keyword()
  @type activity_status :: :active | :inactive | :hot | :cold | :frozen | :offloaded

  # Batch size for tenant updates (matches Python client behavior)
  @batch_size 100

  @doc """
  List all tenants for a collection.

  Uses gRPC when available for optimal performance, falls back to HTTP otherwise.

  ## Examples

      {:ok, tenants} = Tenants.list(client, "Article")

  ## Returns
    * `{:ok, [map()]}` - List of tenants
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list(Client.t(), collection_name()) :: {:ok, [map()]} | {:error, Error.t()}
  def list(client, collection_name) do
    if grpc_available?(client) do
      list_grpc(client, collection_name)
    else
      list_http(client, collection_name)
    end
  end

  defp grpc_available?(client) do
    channel = Client.grpc_channel(client)
    not is_nil(channel)
  end

  defp list_grpc(client, collection_name) do
    case Client.grpc_channel(client) do
      nil ->
        {:error, Error.exception(type: :connection_error, message: "gRPC channel not available")}

      channel ->
        grpc_opts = [
          api_key: client.config.api_key
        ]

        case GRPCTenants.list(channel, collection_name, grpc_opts) do
          {:ok, reply} ->
            tenants = Enum.map(reply.tenants, &convert_grpc_tenant/1)
            {:ok, tenants}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp list_http(client, collection_name) do
    Client.request(client, :get, "/v1/schema/#{collection_name}/tenants", nil, [])
  end

  defp convert_grpc_tenant(tenant) do
    status = GRPCTenants.parse_status(tenant.activity_status)

    %{
      "name" => tenant.name,
      "activityStatus" => status_to_string(status)
    }
  end

  defp status_to_string(:hot), do: "HOT"
  defp status_to_string(:cold), do: "COLD"
  defp status_to_string(:warm), do: "WARM"
  defp status_to_string(:frozen), do: "FROZEN"
  defp status_to_string(:unfreezing), do: "UNFREEZING"
  defp status_to_string(:freezing), do: "FREEZING"
  defp status_to_string(:offloaded), do: "OFFLOADED"
  defp status_to_string(:offloading), do: "OFFLOADING"
  defp status_to_string(:onloading), do: "ONLOADING"
  defp status_to_string(_), do: "UNKNOWN"

  @doc """
  Get specific tenant information.

  Uses gRPC when available for optimal performance, falls back to HTTP otherwise.

  ## Examples

      {:ok, tenant} = Tenants.get(client, "Article", "TenantA")

  ## Returns
    * `{:ok, map()}` - Tenant information
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get(Client.t(), collection_name(), tenant_name()) ::
          {:ok, map()} | {:error, Error.t()}
  def get(client, collection_name, tenant_name) do
    if grpc_available?(client) do
      get_grpc(client, collection_name, tenant_name)
    else
      get_http(client, collection_name, tenant_name)
    end
  end

  defp get_grpc(client, collection_name, tenant_name) do
    case Client.grpc_channel(client) do
      nil ->
        {:error, Error.exception(type: :connection_error, message: "gRPC channel not available")}

      channel ->
        grpc_opts = [api_key: client.config.api_key]
        fetch_tenant_via_grpc(channel, collection_name, tenant_name, grpc_opts)
    end
  end

  defp fetch_tenant_via_grpc(channel, collection_name, tenant_name, grpc_opts) do
    case GRPCTenants.get(channel, collection_name, tenant_name, grpc_opts) do
      {:ok, reply} -> extract_tenant_from_reply(reply)
      {:error, error} -> {:error, error}
    end
  end

  defp extract_tenant_from_reply(%{tenants: [tenant | _]}), do: {:ok, convert_grpc_tenant(tenant)}

  defp extract_tenant_from_reply(%{tenants: []}),
    do: {:error, Error.exception(type: :not_found, message: "Tenant not found")}

  defp get_http(client, collection_name, tenant_name) do
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
  Freeze tenant (set to FROZEN status).

  Frozen tenants have their data persisted but are not loaded into memory.
  This is more aggressive than COLD status.

  ## Examples

      {:ok, _} = Tenants.freeze(client, "Article", "TenantA")
      {:ok, _} = Tenants.freeze(client, "Article", ["TenantA", "TenantB"])

  ## Returns
    * `{:ok, [map()]}` - Updated tenants
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec freeze(Client.t(), collection_name(), tenant_names()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def freeze(client, collection_name, tenant_names) do
    update(client, collection_name, tenant_names, activity_status: :frozen)
  end

  @doc """
  Offload tenant (set to OFFLOADED status).

  Offloaded tenants are moved to cold storage. This is the most aggressive
  deactivation option and may take longer to reactivate.

  ## Examples

      {:ok, _} = Tenants.offload(client, "Article", "TenantA")
      {:ok, _} = Tenants.offload(client, "Article", ["TenantA", "TenantB"])

  ## Returns
    * `{:ok, [map()]}` - Updated tenants
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec offload(Client.t(), collection_name(), tenant_names()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def offload(client, collection_name, tenant_names) do
    update(client, collection_name, tenant_names, activity_status: :offloaded)
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

  @doc """
  Updates tenants in batches of #{@batch_size} (matching Python client behavior).

  This is useful for updating large numbers of tenants efficiently without
  overwhelming the server with a single large request.

  ## Examples

      tenants = [
        %{name: "tenant1", activity_status: :hot},
        %{name: "tenant2", activity_status: :cold}
      ]
      {:ok, results} = Tenants.batch_update(client, "Article", tenants)

  ## Returns
    * `{:ok, [map()]}` - All updated tenants combined
    * `{:error, Error.t()}` - Error from first failed batch
  """
  @spec batch_update(Client.t(), collection_name(), [map()]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def batch_update(client, collection_name, tenants) when is_list(tenants) do
    tenants
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case update_batch(client, collection_name, batch) do
        {:ok, results} -> {:cont, {:ok, acc ++ results}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp update_batch(client, collection_name, batch) do
    tenants =
      Enum.map(batch, fn
        %{name: name, activity_status: status} ->
          %{"name" => name, "activityStatus" => activity_to_string(status)}

        %{"name" => name, "activity_status" => status} ->
          %{"name" => name, "activityStatus" => activity_to_string(status)}

        %{"name" => name, "activityStatus" => status} ->
          %{"name" => name, "activityStatus" => status}

        %{name: name} ->
          %{"name" => name, "activityStatus" => "HOT"}
      end)

    Client.request(client, :put, "/v1/schema/#{collection_name}/tenants", tenants, [])
  end

  @doc """
  Returns the batch size used for batch operations.

  ## Examples

      100 = Tenants.batch_size()
  """
  @spec batch_size() :: pos_integer()
  def batch_size, do: @batch_size

  ## Private Helpers

  defp activity_to_string(:active), do: "ACTIVE"
  defp activity_to_string(:inactive), do: "INACTIVE"
  defp activity_to_string(:hot), do: "HOT"
  defp activity_to_string(:cold), do: "COLD"
  defp activity_to_string(:frozen), do: "FROZEN"
  defp activity_to_string(:offloaded), do: "OFFLOADED"
  defp activity_to_string(status) when is_binary(status), do: String.upcase(status)
end
