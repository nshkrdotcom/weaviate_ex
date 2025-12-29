defmodule WeaviateEx.API.Groups do
  @moduledoc """
  OIDC Group management operations.

  This module provides API operations for managing OIDC group role assignments.
  Groups are created and managed by the OIDC provider - Weaviate only tracks
  which roles are assigned to known groups.

  ## Examples

      alias WeaviateEx.API.Groups

      # Get known group names
      {:ok, groups} = Groups.list_known(client)

      # Get roles assigned to group
      {:ok, roles} = Groups.get_assigned_roles(client, "engineering-team")

      # Assign roles to group
      :ok = Groups.assign_roles(client, "engineering-team", ["developer"])

      # Revoke roles from group
      :ok = Groups.revoke_roles(client, "engineering-team", ["admin"])
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type opts :: keyword()

  @doc """
  List known OIDC group names.

  Returns names of groups that Weaviate knows about (groups that have
  had roles assigned or whose members have authenticated).

  ## Examples

      {:ok, groups} = Groups.list_known(client)
  """
  @spec list_known(Client.t(), opts()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def list_known(client, opts \\ []) do
    case Client.request(client, :get, "/v1/authz/groups", nil, opts) do
      {:ok, groups} when is_list(groups) -> {:ok, groups}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get roles assigned to a group.

  ## Examples

      {:ok, roles} = Groups.get_assigned_roles(client, "engineering")
  """
  @spec get_assigned_roles(Client.t(), String.t(), opts()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def get_assigned_roles(client, group_id, opts \\ []) do
    path = "/v1/authz/groups/#{URI.encode_www_form(group_id)}/roles"

    case Client.request(client, :get, path, nil, opts) do
      {:ok, roles} when is_list(roles) -> {:ok, roles}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Assign roles to a group.

  ## Examples

      :ok = Groups.assign_roles(client, "engineering", ["developer", "viewer"])
  """
  @spec assign_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def assign_roles(client, group_id, role_names, opts \\ []) do
    path = "/v1/authz/groups/#{URI.encode_www_form(group_id)}/assign-roles"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Revoke roles from a group.

  ## Examples

      :ok = Groups.revoke_roles(client, "engineering", ["admin"])
  """
  @spec revoke_roles(Client.t(), String.t(), [String.t()], opts()) :: :ok | {:error, Error.t()}
  def revoke_roles(client, group_id, role_names, opts \\ []) do
    path = "/v1/authz/groups/#{URI.encode_www_form(group_id)}/revoke-roles"
    body = %{"roles" => role_names}

    case Client.request(client, :post, path, body, opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
