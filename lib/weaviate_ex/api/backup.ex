defmodule WeaviateEx.API.Backup do
  @moduledoc """
  Backup and restore operations for Weaviate.

  Provides complete backup management:
  - Create backups to filesystem, S3, GCS, or Azure
  - Restore backups from any supported backend
  - Check backup/restore status
  - List and cancel backups
  - Wait for operations to complete

  ## Creating a Backup

      # Simple backup to filesystem
      {:ok, status} = Backup.create(client, "my-backup", :filesystem)

      # Backup specific collections to S3
      {:ok, status} = Backup.create(client, "my-backup", :s3,
        include_collections: ["Article", "Author"],
        wait_for_completion: true
      )

      # Backup with configuration
      {:ok, status} = Backup.create(client, "my-backup", :filesystem,
        config: Config.create(cpu_percentage: 50, compression: :best_compression)
      )

  ## Restoring a Backup

      # Simple restore
      {:ok, status} = Backup.restore(client, "my-backup", :filesystem)

      # Restore with wait
      {:ok, status} = Backup.restore(client, "my-backup", :s3,
        wait_for_completion: true
      )

  ## Checking Status

      {:ok, status} = Backup.get_create_status(client, "my-backup", :filesystem)
      {:ok, status} = Backup.get_restore_status(client, "my-backup", :s3)

  ## Listing and Canceling

      {:ok, backups} = Backup.list(client, :filesystem)
      :ok = Backup.cancel(client, "my-backup", :filesystem)
  """

  alias WeaviateEx.Backup.{Config, Location, Status, Storage}
  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @default_poll_interval 1000
  @default_timeout 300_000

  @doc """
  Create a new backup.

  The backend can be either an atom (`:filesystem`, `:s3`, `:gcs`, `:azure`) or
  a `WeaviateEx.Backup.Location` struct for dynamic configuration.

  ## Options

  - `:include_collections` - List of collections to include (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for backup to complete (default: false)
  - `:config` - Backup configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)

  ## Examples

      {:ok, status} = Backup.create(client, "daily-backup", :filesystem)

      # Using dynamic location
      {:ok, status} = Backup.create(client, "daily-backup",
        Location.s3("my-bucket", "/backups", region: "us-west-2"),
        wait_for_completion: true
      )

      {:ok, status} = Backup.create(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true,
        config: Config.create(compression: :best_speed)
      )
  """
  @spec create(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) ::
          {:ok, Status.CreateResponse.t()} | {:error, Error.t()}
  def create(client, backup_id, backend, opts \\ [])

  def create(client, backup_id, %Location.Filesystem{} = location, opts) do
    do_create_with_location(client, backup_id, :filesystem, location, opts)
  end

  def create(client, backup_id, %Location.S3{} = location, opts) do
    do_create_with_location(client, backup_id, :s3, location, opts)
  end

  def create(client, backup_id, %Location.GCS{} = location, opts) do
    do_create_with_location(client, backup_id, :gcs, location, opts)
  end

  def create(client, backup_id, %Location.Azure{} = location, opts) do
    do_create_with_location(client, backup_id, :azure, location, opts)
  end

  def create(client, backup_id, backend, opts) when is_atom(backend) do
    if Storage.valid?(backend) do
      do_create(client, backup_id, backend, opts)
    else
      {:error, Error.invalid_backend(backend)}
    end
  end

  defp do_create(client, backup_id, backend, opts) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}"
    body = build_create_body(backup_id, opts)

    case Client.request(client, :post, path, body, []) do
      {:ok, response} ->
        handle_create_response(client, backup_id, backend, response, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_create_with_location(client, backup_id, backend_type, location, opts) do
    path = "/v1/backups/#{Storage.to_api_path(backend_type)}"
    body = build_create_body_with_location(backup_id, location, opts)

    case Client.request(client, :post, path, body, []) do
      {:ok, response} ->
        handle_create_response(client, backup_id, backend_type, response, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_create_response(client, backup_id, backend, response, opts) do
    {:ok, result} = Status.create_response_from_api(response)

    if Keyword.get(opts, :wait_for_completion, false) do
      wait_for_completion(client, backup_id, backend, :create, opts)
    else
      {:ok, result}
    end
  end

  @doc """
  Get the status of a backup creation.

  ## Examples

      {:ok, status} = Backup.get_create_status(client, "my-backup", :filesystem)
      if Status.completed?(status.status) do
        IO.puts("Backup complete!")
      end
  """
  @spec get_create_status(Client.t(), String.t(), Storage.t()) ::
          {:ok, Status.CreateResponse.t()} | {:error, Error.t()}
  def get_create_status(client, backup_id, backend) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}"

    case Client.request(client, :get, path, nil, []) do
      {:ok, response} ->
        Status.create_response_from_api(response)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Restore a backup.

  The backend can be either an atom (`:filesystem`, `:s3`, `:gcs`, `:azure`) or
  a `WeaviateEx.Backup.Location` struct for dynamic configuration.

  ## Options

  - `:include_collections` - List of collections to restore (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for restore to complete (default: false)
  - `:config` - Restore configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)
  - `:roles_restore` - RBAC roles restore option: `:all`, `:none`, or list of role names
  - `:users_restore` - RBAC users restore option: `:all`, `:none`, or list of user IDs
  - `:overwrite_alias` - Whether to overwrite existing aliases (default: false)

  ## Examples

      {:ok, status} = Backup.restore(client, "daily-backup", :filesystem)

      # Using dynamic location
      {:ok, status} = Backup.restore(client, "daily-backup",
        Location.s3("my-bucket", "/backups", region: "eu-west-1"))

      {:ok, status} = Backup.restore(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true
      )

      # With RBAC options
      {:ok, status} = Backup.restore(client, "daily-backup", :filesystem,
        roles_restore: :all,
        users_restore: ["admin@example.com"],
        overwrite_alias: true
      )
  """
  @spec restore(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) ::
          {:ok, Status.RestoreResponse.t()} | {:error, Error.t()}
  def restore(client, backup_id, backend, opts \\ [])

  def restore(client, backup_id, %Location.Filesystem{} = location, opts) do
    do_restore_with_location(client, backup_id, :filesystem, location, opts)
  end

  def restore(client, backup_id, %Location.S3{} = location, opts) do
    do_restore_with_location(client, backup_id, :s3, location, opts)
  end

  def restore(client, backup_id, %Location.GCS{} = location, opts) do
    do_restore_with_location(client, backup_id, :gcs, location, opts)
  end

  def restore(client, backup_id, %Location.Azure{} = location, opts) do
    do_restore_with_location(client, backup_id, :azure, location, opts)
  end

  def restore(client, backup_id, backend, opts) when is_atom(backend) do
    if Storage.valid?(backend) do
      do_restore(client, backup_id, backend, opts)
    else
      {:error, Error.invalid_backend(backend)}
    end
  end

  defp do_restore(client, backup_id, backend, opts) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}/restore"
    body = build_restore_body(opts)

    case Client.request(client, :post, path, body, []) do
      {:ok, response} ->
        handle_restore_response(client, backup_id, backend, response, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_restore_with_location(client, backup_id, backend_type, location, opts) do
    path = "/v1/backups/#{Storage.to_api_path(backend_type)}/#{backup_id}/restore"
    body = build_restore_body_with_location(location, opts)

    case Client.request(client, :post, path, body, []) do
      {:ok, response} ->
        handle_restore_response(client, backup_id, backend_type, response, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_restore_response(client, backup_id, backend, response, opts) do
    {:ok, result} = Status.restore_response_from_api(response)

    if Keyword.get(opts, :wait_for_completion, false) do
      wait_for_completion(client, backup_id, backend, :restore, opts)
    else
      {:ok, result}
    end
  end

  @doc """
  Get the status of a backup restoration.

  ## Examples

      {:ok, status} = Backup.get_restore_status(client, "my-backup", :filesystem)
  """
  @spec get_restore_status(Client.t(), String.t(), Storage.t()) ::
          {:ok, Status.RestoreResponse.t()} | {:error, Error.t()}
  def get_restore_status(client, backup_id, backend) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}/restore"

    case Client.request(client, :get, path, nil, []) do
      {:ok, response} ->
        Status.restore_response_from_api(response)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  List all backups for a storage backend.

  ## Options

  - `:sort_by_starting_time_asc` - Sort backups by start time ascending (default: false)

  ## Examples

      {:ok, backups} = Backup.list(client, :filesystem)
      Enum.each(backups, fn backup ->
        IO.puts("\#{backup.id}: \#{backup.status}")
      end)

      # Sort by start time ascending
      {:ok, backups} = Backup.list(client, :s3, sort_by_starting_time_asc: true)
  """
  @spec list(Client.t(), Storage.t(), keyword()) ::
          {:ok, [Status.BackupInfo.t()]} | {:error, Error.t()}
  def list(client, backend, opts \\ []) do
    sort_asc = Keyword.get(opts, :sort_by_starting_time_asc, false)
    query_string = if sort_asc, do: "?sortByStartingTimeAsc=true", else: ""
    path = "/v1/backups/#{Storage.to_api_path(backend)}#{query_string}"

    case Client.request(client, :get, path, nil, []) do
      {:ok, response} when is_list(response) ->
        backups =
          Enum.map(response, fn item ->
            {:ok, info} = Status.backup_info_from_api(item)
            info
          end)

        {:ok, backups}

      {:ok, _response} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Cancel an in-progress backup.

  ## Options

  - `:location` - Dynamic backup location configuration (Location struct)

  ## Examples

      :ok = Backup.cancel(client, "my-backup", :filesystem)

      # Cancel with dynamic location
      :ok = Backup.cancel(client, "my-backup", :s3,
        location: Location.s3("my-bucket", "/backups", region: "us-west-2"))
  """
  @spec cancel(Client.t(), String.t(), Storage.t(), keyword()) ::
          :ok | {:error, Error.t()}
  def cancel(client, backup_id, backend, opts \\ []) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}"

    body = build_cancel_body(opts)

    case Client.request(client, :delete, path, body, []) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp build_cancel_body(opts) do
    case Keyword.get(opts, :location) do
      nil ->
        nil

      %Location.Filesystem{} = loc ->
        %{"config" => Location.to_api(loc)}

      %Location.S3{} = loc ->
        %{"config" => Location.to_api(loc)}

      %Location.GCS{} = loc ->
        %{"config" => Location.to_api(loc)}

      %Location.Azure{} = loc ->
        %{"config" => Location.to_api(loc)}
    end
  end

  @doc """
  Wait for a backup operation to complete.

  Polls the status endpoint until the operation completes or times out.

  ## Options

  - `:poll_interval` - How often to check status (default: 1000ms)
  - `:timeout` - Maximum wait time (default: 300000ms)

  ## Examples

      {:ok, status} = Backup.wait_for_completion(client, "my-backup", :filesystem, :create)
  """
  @spec wait_for_completion(
          Client.t(),
          String.t(),
          Storage.t(),
          :create | :restore,
          keyword()
        ) :: {:ok, Status.CreateResponse.t() | Status.RestoreResponse.t()} | {:error, Error.t()}
  def wait_for_completion(client, backup_id, backend, operation, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline)
  end

  defp do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, Error.backup_timeout(backup_id, operation)}
    else
      check_and_wait(client, backup_id, backend, operation, poll_interval, deadline)
    end
  end

  defp check_and_wait(client, backup_id, backend, operation, poll_interval, deadline) do
    status_result = get_operation_status(client, backup_id, backend, operation)

    case status_result do
      {:ok, status} ->
        handle_status_check(
          client,
          backup_id,
          backend,
          operation,
          poll_interval,
          deadline,
          status
        )

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_operation_status(client, backup_id, backend, :create) do
    get_create_status(client, backup_id, backend)
  end

  defp get_operation_status(client, backup_id, backend, :restore) do
    get_restore_status(client, backup_id, backend)
  end

  defp handle_status_check(_client, _backup_id, _backend, _op, _interval, _deadline, status)
       when status.status in [:success, :failed, :canceled] do
    {:ok, status}
  end

  defp handle_status_check(
         client,
         backup_id,
         backend,
         operation,
         poll_interval,
         deadline,
         _status
       ) do
    Process.sleep(poll_interval)
    do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline)
  end

  @doc """
  Build request body for create operation.

  ## Examples

      body = Backup.build_create_body("backup-123", include_collections: ["Article"])
  """
  @spec build_create_body(String.t(), keyword()) :: map()
  def build_create_body(backup_id, opts) do
    body = %{"id" => backup_id}

    body =
      case Keyword.get(opts, :include_collections) do
        nil -> body
        collections -> Map.put(body, "include", collections)
      end

    body =
      case Keyword.get(opts, :exclude_collections) do
        nil -> body
        collections -> Map.put(body, "exclude", collections)
      end

    case Keyword.get(opts, :config) do
      nil ->
        body

      %Config.Create{} = config ->
        api_config = Config.Create.to_api(config)

        if map_size(api_config) > 0 do
          Map.put(body, "config", api_config)
        else
          body
        end
    end
  end

  @doc """
  Build request body for restore operation.

  ## Examples

      body = Backup.build_restore_body(include_collections: ["Article"])
      body = Backup.build_restore_body(roles_restore: :all, users_restore: :none)
  """
  @spec build_restore_body(keyword()) :: map()
  def build_restore_body(opts) do
    %{}
    |> add_collection_opts(opts)
    |> add_rbac_opts(opts)
    |> add_restore_config(opts)
  end

  @doc false
  def build_create_body_with_location(backup_id, location, opts) do
    body = build_create_body(backup_id, opts)
    location_config = Location.to_api(location)

    existing_config = Map.get(body, "config", %{})
    merged_config = Map.merge(location_config, existing_config)

    Map.put(body, "config", merged_config)
  end

  @doc false
  def build_restore_body_with_location(location, opts) do
    body = build_restore_body(opts)
    location_config = Location.to_api(location)

    existing_config = Map.get(body, "config", %{})
    merged_config = Map.merge(location_config, existing_config)

    Map.put(body, "config", merged_config)
  end

  # Helper functions for building request bodies

  defp add_collection_opts(body, opts) do
    body
    |> maybe_put_opt("include", Keyword.get(opts, :include_collections))
    |> maybe_put_opt("exclude", Keyword.get(opts, :exclude_collections))
  end

  defp add_rbac_opts(body, opts) do
    body
    |> maybe_put_rbac_opt("rolesRestore", Keyword.get(opts, :roles_restore))
    |> maybe_put_rbac_opt("usersRestore", Keyword.get(opts, :users_restore))
    |> maybe_put_opt("overwriteAlias", Keyword.get(opts, :overwrite_alias))
  end

  defp add_restore_config(body, opts) do
    case Keyword.get(opts, :config) do
      nil ->
        body

      %Config.Restore{} = config ->
        api_config = Config.Restore.to_api(config)

        if map_size(api_config) > 0 do
          Map.put(body, "config", api_config)
        else
          body
        end
    end
  end

  defp maybe_put_opt(body, _key, nil), do: body
  defp maybe_put_opt(body, key, value), do: Map.put(body, key, value)

  defp maybe_put_rbac_opt(body, _key, nil), do: body
  defp maybe_put_rbac_opt(body, key, :all), do: Map.put(body, key, "all")
  defp maybe_put_rbac_opt(body, key, :none), do: Map.put(body, key, "none")
  defp maybe_put_rbac_opt(body, key, list) when is_list(list), do: Map.put(body, key, list)
end
