defmodule WeaviateEx do
  @moduledoc """
  A modern Elixir client for Weaviate vector database.

  WeaviateEx provides a clean, idiomatic Elixir interface to interact with Weaviate,
  including support for:

  - Collections management (create, read, update, delete)
  - Object operations (CRUD with vectors)
  - Batch operations for efficient bulk imports
  - GraphQL queries for complex searches
  - Vector similarity search
  - Health checks and monitoring

  ## Configuration

  Configure WeaviateEx in your `config/config.exs`:

      config :weaviate_ex,
        url: "http://localhost:8080",
        api_key: nil  # Optional, for authenticated instances

  Or use environment variables:

      export WEAVIATE_URL=http://localhost:8080
      export WEAVIATE_API_KEY=your-api-key  # Optional

  ## Examples

      # Health check
      {:ok, meta} = WeaviateEx.health_check()

      # Create a collection
      {:ok, collection} = WeaviateEx.Collections.create("Article", %{
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]}
        ]
      })

      # Insert an object
      {:ok, object} = WeaviateEx.Objects.create("Article", %{
        properties: %{
          title: "Hello Weaviate",
          content: "This is a test article"
        }
      })

      # Query objects
      {:ok, results} = WeaviateEx.Objects.list("Article", limit: 10)
  """

  require Logger
  alias WeaviateEx.Embedded

  @type api_response :: {:ok, map() | list()} | {:error, term()}
  @type uuid :: String.t()

  ## Configuration

  @doc """
  Returns the configured Weaviate base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    System.get_env("WEAVIATE_URL") ||
      Application.get_env(:weaviate_ex, :url) ||
      "http://localhost:8080"
  end

  @doc """
  Returns the API key for authentication, if configured.
  """
  @spec api_key() :: String.t() | nil
  def api_key do
    System.get_env("WEAVIATE_API_KEY") ||
      Application.get_env(:weaviate_ex, :api_key)
  end

  ## Health & Meta API

  @doc """
  Performs a health check against the Weaviate instance.

  Returns metadata about the Weaviate instance including version,
  modules, and configuration.

  ## Examples

      iex> WeaviateEx.health_check()
      {:ok, %{"version" => "1.28.1", "modules" => %{}}}
  """
  @spec health_check() :: api_response()
  def health_check do
    request(:get, "/v1/meta", nil)
  end

  @doc """
  Checks if Weaviate is ready to serve requests.

  ## Examples

      iex> WeaviateEx.ready?()
      {:ok, true}
  """
  @spec ready?() :: {:ok, boolean()} | {:error, term()}
  def ready? do
    case request(:get, "/v1/.well-known/ready", nil) do
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  @doc """
  Checks if Weaviate is alive (liveness probe).

  ## Examples

      iex> WeaviateEx.alive?()
      {:ok, true}
  """
  @spec alive?() :: {:ok, boolean()} | {:error, term()}
  def alive? do
    case request(:get, "/v1/.well-known/live", nil) do
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  ## Embedded Weaviate

  @doc """
  Starts an embedded Weaviate instance using the official binary.

  This function delegates to `WeaviateEx.Embedded.start/1` and returns an
  opaque handle that should be passed to `stop_embedded/1` when you're done.

  ## Examples

      {:ok, emb} = WeaviateEx.start_embedded(version: "1.30.5", port: 8090)
      WeaviateEx.health_check()
      :ok = WeaviateEx.stop_embedded(emb)
  """
  @spec start_embedded([Embedded.option()]) :: {:ok, Embedded.Instance.t()} | {:error, term()}
  def start_embedded(opts \\ []), do: Embedded.start(opts)

  @doc """
  Stops an embedded Weaviate instance started with `start_embedded/1`.
  """
  @spec stop_embedded(Embedded.Instance.t()) :: :ok
  def stop_embedded(instance), do: Embedded.stop(instance)

  ## HTTP Client

  @doc false
  @spec request(atom(), String.t(), map() | list() | nil, Keyword.t()) :: api_response()
  def request(method, path, body \\ nil, opts \\ []) do
    # Create a client using the configured protocol implementation
    {:ok, client} =
      WeaviateEx.Client.new(
        base_url: base_url(),
        api_key: api_key()
      )

    # Delegate to the client
    WeaviateEx.Client.request(client, method, path, body, opts)
  end

  ## RBAC Convenience Functions

  @doc """
  List all roles.

  Delegates to `WeaviateEx.API.RBAC.list_roles/1`.
  """
  defdelegate list_roles(client), to: WeaviateEx.API.RBAC

  @doc """
  Get a role by name.

  Delegates to `WeaviateEx.API.RBAC.get_role/2`.
  """
  defdelegate get_role(client, name), to: WeaviateEx.API.RBAC

  @doc """
  Create a role with permissions.

  Delegates to `WeaviateEx.API.RBAC.create_role/3`.
  """
  defdelegate create_role(client, name, permissions), to: WeaviateEx.API.RBAC

  @doc """
  Delete a role.

  Delegates to `WeaviateEx.API.RBAC.delete_role/2`.
  """
  defdelegate delete_role(client, name), to: WeaviateEx.API.RBAC

  ## User Management Convenience Functions

  @doc """
  Create a new DB user.

  Delegates to `WeaviateEx.API.Users.create/2`.
  """
  defdelegate create_user(client, user_id), to: WeaviateEx.API.Users, as: :create

  @doc """
  Get a user by ID.

  Delegates to `WeaviateEx.API.Users.get/2`.
  """
  defdelegate get_user(client, user_id), to: WeaviateEx.API.Users, as: :get

  @doc """
  List all users.

  Delegates to `WeaviateEx.API.Users.list_all/1`.
  """
  defdelegate list_users(client), to: WeaviateEx.API.Users, as: :list_all

  @doc """
  Delete a user.

  Delegates to `WeaviateEx.API.Users.delete/2`.
  """
  defdelegate delete_user(client, user_id), to: WeaviateEx.API.Users, as: :delete

  @doc """
  Get the current authenticated user.

  Delegates to `WeaviateEx.API.Users.get_my_user/1`.
  """
  defdelegate get_my_user(client), to: WeaviateEx.API.Users

  ## Group Management Convenience Functions

  @doc """
  List known OIDC groups.

  Delegates to `WeaviateEx.API.Groups.list_known/1`.
  """
  defdelegate list_groups(client), to: WeaviateEx.API.Groups, as: :list_known

  @doc """
  Assign roles to an OIDC group.

  Delegates to `WeaviateEx.API.Groups.assign_roles/3`.
  """
  defdelegate assign_group_roles(client, group, roles),
    to: WeaviateEx.API.Groups,
    as: :assign_roles

  @doc """
  Revoke roles from an OIDC group.

  Delegates to `WeaviateEx.API.Groups.revoke_roles/3`.
  """
  defdelegate revoke_group_roles(client, group, roles),
    to: WeaviateEx.API.Groups,
    as: :revoke_roles

  ## Backup Convenience Functions

  @doc """
  Create a new backup.

  Delegates to `WeaviateEx.API.Backup.create/4`.

  ## Examples

      {:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :filesystem)
      {:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true
      )
  """
  defdelegate create_backup(client, backup_id, backend, opts \\ []),
    to: WeaviateEx.API.Backup,
    as: :create

  @doc """
  Restore a backup.

  Delegates to `WeaviateEx.API.Backup.restore/4`.

  ## Examples

      {:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :filesystem)
      {:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :s3,
        wait_for_completion: true
      )
  """
  defdelegate restore_backup(client, backup_id, backend, opts \\ []),
    to: WeaviateEx.API.Backup,
    as: :restore

  @doc """
  List all backups for a storage backend.

  Delegates to `WeaviateEx.API.Backup.list/2`.

  ## Examples

      {:ok, backups} = WeaviateEx.list_backups(client, :filesystem)
  """
  defdelegate list_backups(client, backend), to: WeaviateEx.API.Backup, as: :list

  @doc """
  Cancel an in-progress backup.

  Delegates to `WeaviateEx.API.Backup.cancel/3`.

  ## Examples

      :ok = WeaviateEx.cancel_backup(client, "daily-backup", :filesystem)
  """
  defdelegate cancel_backup(client, backup_id, backend), to: WeaviateEx.API.Backup, as: :cancel

  @doc """
  Get the status of a backup creation.

  Delegates to `WeaviateEx.API.Backup.get_create_status/3`.

  ## Examples

      {:ok, status} = WeaviateEx.get_backup_status(client, "daily-backup", :filesystem)
  """
  defdelegate get_backup_status(client, backup_id, backend),
    to: WeaviateEx.API.Backup,
    as: :get_create_status

  @doc """
  Get the status of a backup restoration.

  Delegates to `WeaviateEx.API.Backup.get_restore_status/3`.

  ## Examples

      {:ok, status} = WeaviateEx.get_restore_status(client, "daily-backup", :filesystem)
  """
  defdelegate get_restore_status(client, backup_id, backend),
    to: WeaviateEx.API.Backup,
    as: :get_restore_status
end
