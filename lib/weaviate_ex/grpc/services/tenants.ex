defmodule WeaviateEx.GRPC.Services.Tenants do
  @moduledoc """
  gRPC Tenants service for multi-tenancy operations.

  This module provides high-level functions for managing tenants
  in multi-tenant Weaviate collections using gRPC.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      {:ok, tenants} = Tenants.list(channel, "Article")
      {:ok, tenant} = Tenants.get(channel, "Article", "tenant_a")
  """

  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel

  alias Weaviate.V1.{
    TenantsGetReply,
    TenantsGetRequest
  }

  alias Weaviate.V1.Weaviate.Stub, as: WeaviateStub

  @type tenant_opts :: [
          timeout: non_neg_integer(),
          api_key: String.t() | nil
        ]

  @doc """
  List all tenants for a collection.

  ## Examples

      {:ok, reply} = Tenants.list(channel, "Article")
      tenants = reply.tenants
  """
  @spec list(GRPC.Channel.t(), String.t(), tenant_opts()) ::
          {:ok, TenantsGetReply.t()} | {:error, Error.t()}
  def list(channel, collection, opts \\ []) do
    request = %TenantsGetRequest{
      collection: collection
    }

    execute_tenants_get(channel, request, opts)
  end

  @doc """
  Get specific tenants by name.

  ## Examples

      {:ok, reply} = Tenants.get(channel, "Article", ["tenant_a", "tenant_b"])
      {:ok, reply} = Tenants.get(channel, "Article", "tenant_a")
  """
  @spec get(GRPC.Channel.t(), String.t(), String.t() | [String.t()], tenant_opts()) ::
          {:ok, TenantsGetReply.t()} | {:error, Error.t()}
  def get(channel, collection, tenant_names, opts \\ []) do
    names = if is_binary(tenant_names), do: [tenant_names], else: tenant_names

    # Build tenant names for the request
    tenant_names_msg = %Weaviate.V1.TenantNames{values: names}

    request = %TenantsGetRequest{
      collection: collection,
      params: {:names, tenant_names_msg}
    }

    execute_tenants_get(channel, request, opts)
  end

  @doc """
  Check if a tenant exists.

  ## Examples

      {:ok, exists} = Tenants.exists?(channel, "Article", "tenant_a")
  """
  @spec exists?(GRPC.Channel.t(), String.t(), String.t(), tenant_opts()) ::
          {:ok, boolean()} | {:error, Error.t()}
  def exists?(channel, collection, tenant_name, opts \\ []) do
    case get(channel, collection, tenant_name, opts) do
      {:ok, reply} ->
        exists = Enum.any?(reply.tenants, fn t -> t.name == tenant_name end)
        {:ok, exists}

      {:error, %Error{type: :not_found}} ->
        {:ok, false}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Parse tenant activity status.

  ## Examples

      status = Tenants.parse_status(:TENANT_ACTIVITY_STATUS_HOT)
      # => :hot
  """
  @spec parse_status(atom() | integer()) :: atom()
  def parse_status(:TENANT_ACTIVITY_STATUS_HOT), do: :hot
  def parse_status(:TENANT_ACTIVITY_STATUS_COLD), do: :cold
  def parse_status(:TENANT_ACTIVITY_STATUS_WARM), do: :warm
  def parse_status(:TENANT_ACTIVITY_STATUS_FROZEN), do: :frozen
  def parse_status(:TENANT_ACTIVITY_STATUS_UNFREEZING), do: :unfreezing
  def parse_status(:TENANT_ACTIVITY_STATUS_FREEZING), do: :freezing
  def parse_status(:TENANT_ACTIVITY_STATUS_OFFLOADED), do: :offloaded
  def parse_status(:TENANT_ACTIVITY_STATUS_OFFLOADING), do: :offloading
  def parse_status(:TENANT_ACTIVITY_STATUS_ONLOADING), do: :onloading
  def parse_status(_), do: :unknown

  # Private functions

  defp execute_tenants_get(channel, request, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    metadata = Channel.build_metadata(opts)

    case WeaviateStub.tenants_get(channel, request, timeout: timeout, metadata: metadata) do
      {:ok, reply} ->
        {:ok, reply}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  end
end
