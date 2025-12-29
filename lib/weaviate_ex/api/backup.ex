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

  alias WeaviateEx.Backup.{Config, Status, Storage}
  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @default_poll_interval 1000
  @default_timeout 300_000

  @doc """
  Create a new backup.

  ## Options

  - `:include_collections` - List of collections to include (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for backup to complete (default: false)
  - `:config` - Backup configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)

  ## Examples

      {:ok, status} = Backup.create(client, "daily-backup", :filesystem)

      {:ok, status} = Backup.create(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true,
        config: Config.create(compression: :best_speed)
      )
  """
  @spec create(Client.t(), String.t(), Storage.t(), keyword()) ::
          {:ok, Status.CreateResponse.t()} | {:error, Error.t()}
  def create(client, backup_id, backend, opts \\ []) do
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

  ## Options

  - `:include_collections` - List of collections to restore (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for restore to complete (default: false)
  - `:config` - Restore configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)

  ## Examples

      {:ok, status} = Backup.restore(client, "daily-backup", :filesystem)

      {:ok, status} = Backup.restore(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true
      )
  """
  @spec restore(Client.t(), String.t(), Storage.t(), keyword()) ::
          {:ok, Status.RestoreResponse.t()} | {:error, Error.t()}
  def restore(client, backup_id, backend, opts \\ []) do
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

  ## Examples

      {:ok, backups} = Backup.list(client, :filesystem)
      Enum.each(backups, fn backup ->
        IO.puts("\#{backup.id}: \#{backup.status}")
      end)
  """
  @spec list(Client.t(), Storage.t()) ::
          {:ok, [Status.BackupInfo.t()]} | {:error, Error.t()}
  def list(client, backend) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}"

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

  ## Examples

      :ok = Backup.cancel(client, "my-backup", :filesystem)
  """
  @spec cancel(Client.t(), String.t(), Storage.t()) ::
          :ok | {:error, Error.t()}
  def cancel(client, backup_id, backend) do
    path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}"

    case Client.request(client, :delete, path, nil, []) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
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
  """
  @spec build_restore_body(keyword()) :: map()
  def build_restore_body(opts) do
    body = %{}

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

      %Config.Restore{} = config ->
        api_config = Config.Restore.to_api(config)

        if map_size(api_config) > 0 do
          Map.put(body, "config", api_config)
        else
          body
        end
    end
  end
end
