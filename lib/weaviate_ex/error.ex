defmodule WeaviateEx.Error do
  @moduledoc """
  Error struct for WeaviateEx operations.
  """

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          details: map(),
          status_code: integer() | nil
        }

  defexception [:type, :message, :details, :status_code]

  def exception(opts) do
    type = Keyword.get(opts, :type, :unknown_error)
    message = Keyword.get(opts, :message, "An error occurred")
    details = Keyword.get(opts, :details, %{})
    status_code = Keyword.get(opts, :status_code)

    %__MODULE__{
      type: type,
      message: message,
      details: details,
      status_code: status_code
    }
  end

  @doc "Create error from HTTP status code"
  def from_status_code(code, body) when is_integer(code) do
    type = status_to_type(code)
    message = extract_message(body)

    %__MODULE__{
      type: type,
      message: message,
      details: body,
      status_code: code
    }
  end

  defp status_to_type(400), do: :bad_request
  defp status_to_type(401), do: :authentication_failed
  defp status_to_type(403), do: :forbidden
  defp status_to_type(404), do: :not_found
  defp status_to_type(409), do: :conflict
  defp status_to_type(422), do: :validation_error
  defp status_to_type(500), do: :server_error
  defp status_to_type(503), do: :service_unavailable
  defp status_to_type(_), do: :unknown_error

  defp extract_message(body) when is_map(body) do
    body["message"] || body["error"] || "Request failed"
  end

  defp extract_message(_), do: "Request failed"

  @doc """
  Create error from gRPC status code.

  Maps gRPC status codes to WeaviateEx error types.

  ## Examples

      error = Error.from_grpc_status(:not_found, "Object not found")
      error.type #=> :not_found

      error = Error.from_grpc_status(:unavailable, "Service unavailable")
      error.type #=> :service_unavailable
  """
  @spec from_grpc_status(atom(), String.t(), map()) :: t()
  def from_grpc_status(status_code, message, details \\ %{}) do
    type = grpc_status_to_type(status_code)

    %__MODULE__{
      type: type,
      message: message,
      details: Map.put(details, :grpc_status, status_code),
      status_code: nil
    }
  end

  @doc """
  Create error from GRPC.RPCError struct.

  ## Examples

      error = Error.from_grpc_error(%GRPC.RPCError{status: 5, message: "Not found"})
      error.type #=> :not_found
  """
  @spec from_grpc_error(GRPC.RPCError.t()) :: t()
  def from_grpc_error(%GRPC.RPCError{status: status, message: message}) do
    status_atom = grpc_code_to_atom(status)
    from_grpc_status(status_atom, message)
  end

  # gRPC status code to atom mapping
  # See: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
  defp grpc_code_to_atom(0), do: :ok
  defp grpc_code_to_atom(1), do: :cancelled
  defp grpc_code_to_atom(2), do: :unknown
  defp grpc_code_to_atom(3), do: :invalid_argument
  defp grpc_code_to_atom(4), do: :deadline_exceeded
  defp grpc_code_to_atom(5), do: :not_found
  defp grpc_code_to_atom(6), do: :already_exists
  defp grpc_code_to_atom(7), do: :permission_denied
  defp grpc_code_to_atom(8), do: :resource_exhausted
  defp grpc_code_to_atom(9), do: :failed_precondition
  defp grpc_code_to_atom(10), do: :aborted
  defp grpc_code_to_atom(11), do: :out_of_range
  defp grpc_code_to_atom(12), do: :unimplemented
  defp grpc_code_to_atom(13), do: :internal
  defp grpc_code_to_atom(14), do: :unavailable
  defp grpc_code_to_atom(15), do: :data_loss
  defp grpc_code_to_atom(16), do: :unauthenticated
  defp grpc_code_to_atom(_), do: :unknown

  # Map gRPC status atoms to WeaviateEx error types
  defp grpc_status_to_type(:ok), do: :ok
  defp grpc_status_to_type(:cancelled), do: :cancelled
  defp grpc_status_to_type(:unknown), do: :unknown_error
  defp grpc_status_to_type(:invalid_argument), do: :bad_request
  defp grpc_status_to_type(:deadline_exceeded), do: :timeout_error
  defp grpc_status_to_type(:not_found), do: :not_found
  defp grpc_status_to_type(:already_exists), do: :conflict
  defp grpc_status_to_type(:permission_denied), do: :forbidden
  defp grpc_status_to_type(:resource_exhausted), do: :rate_limited
  defp grpc_status_to_type(:failed_precondition), do: :validation_error
  defp grpc_status_to_type(:aborted), do: :aborted
  defp grpc_status_to_type(:out_of_range), do: :bad_request
  defp grpc_status_to_type(:unimplemented), do: :not_implemented
  defp grpc_status_to_type(:internal), do: :server_error
  defp grpc_status_to_type(:unavailable), do: :service_unavailable
  defp grpc_status_to_type(:data_loss), do: :data_loss
  defp grpc_status_to_type(:unauthenticated), do: :authentication_failed
  defp grpc_status_to_type(_), do: :unknown_error

  @doc """
  Checks if a gRPC status code is retryable.

  ## Examples

      true = Error.grpc_retryable?(:unavailable)
      true = Error.grpc_retryable?(:resource_exhausted)
      false = Error.grpc_retryable?(:invalid_argument)
  """
  @spec grpc_retryable?(atom()) :: boolean()
  def grpc_retryable?(:unavailable), do: true
  def grpc_retryable?(:resource_exhausted), do: true
  def grpc_retryable?(:aborted), do: true
  def grpc_retryable?(:deadline_exceeded), do: true
  def grpc_retryable?(_), do: false

  ## RBAC-Specific Errors

  @doc """
  Create an RBAC-specific error with category metadata.

  ## Examples

      error = Error.rbac_error(:not_found, "Role not found", %{role: "admin"})
  """
  @spec rbac_error(atom(), String.t(), map()) :: t()
  def rbac_error(type, message, details \\ %{}) do
    %__MODULE__{
      type: type,
      message: message,
      details: Map.put(details, :category, :rbac),
      status_code: nil
    }
  end

  @doc """
  Create a role not found error.

  ## Examples

      error = Error.role_not_found("admin")
  """
  @spec role_not_found(String.t()) :: t()
  def role_not_found(role_name) do
    rbac_error(:not_found, "Role '#{role_name}' not found", %{role: role_name})
  end

  @doc """
  Create a permission denied error.

  ## Examples

      error = Error.permission_denied(:delete, "Article")
  """
  @spec permission_denied(atom(), String.t()) :: t()
  def permission_denied(action, resource) do
    rbac_error(:forbidden, "Permission denied for #{action} on #{resource}", %{
      action: action,
      resource: resource
    })
  end

  @doc """
  Create a user not found error.

  ## Examples

      error = Error.user_not_found("john.doe")
  """
  @spec user_not_found(String.t()) :: t()
  def user_not_found(user_id) do
    rbac_error(:not_found, "User '#{user_id}' not found", %{user_id: user_id})
  end

  @doc """
  Create an invalid permission error.

  ## Examples

      error = Error.invalid_permission("Invalid action for collection type")
  """
  @spec invalid_permission(String.t()) :: t()
  def invalid_permission(reason) do
    rbac_error(:bad_request, "Invalid permission: #{reason}", %{})
  end

  ## Backup-Specific Errors

  @doc """
  Create a backup not found error.

  ## Examples

      error = Error.backup_not_found("backup-123", :filesystem)
  """
  @spec backup_not_found(String.t(), atom()) :: t()
  def backup_not_found(backup_id, backend) do
    %__MODULE__{
      type: :not_found,
      message: "Backup '#{backup_id}' not found in #{backend} storage",
      details: %{category: :backup, backup_id: backup_id, backend: backend},
      status_code: nil
    }
  end

  @doc """
  Create a backup already exists error.

  ## Examples

      error = Error.backup_already_exists("backup-123", :s3)
  """
  @spec backup_already_exists(String.t(), atom()) :: t()
  def backup_already_exists(backup_id, backend) do
    %__MODULE__{
      type: :conflict,
      message: "Backup '#{backup_id}' already exists in #{backend} storage",
      details: %{category: :backup, backup_id: backup_id, backend: backend},
      status_code: nil
    }
  end

  @doc """
  Create a backup failed error.

  ## Examples

      error = Error.backup_failed("backup-123", "disk full")
  """
  @spec backup_failed(String.t(), String.t()) :: t()
  def backup_failed(backup_id, reason) do
    %__MODULE__{
      type: :backup_failed,
      message: "Backup '#{backup_id}' failed: #{reason}",
      details: %{category: :backup, backup_id: backup_id},
      status_code: nil
    }
  end

  @doc """
  Create a restore failed error.

  ## Examples

      error = Error.restore_failed("backup-123", "collection already exists")
  """
  @spec restore_failed(String.t(), String.t()) :: t()
  def restore_failed(backup_id, reason) do
    %__MODULE__{
      type: :restore_failed,
      message: "Restore of '#{backup_id}' failed: #{reason}",
      details: %{category: :backup, backup_id: backup_id},
      status_code: nil
    }
  end

  @doc """
  Create a backup timeout error.

  ## Examples

      error = Error.backup_timeout("backup-123", :create)
  """
  @spec backup_timeout(String.t(), atom()) :: t()
  def backup_timeout(backup_id, operation) do
    %__MODULE__{
      type: :timeout_error,
      message: "#{operation} operation for backup '#{backup_id}' timed out",
      details: %{category: :backup, backup_id: backup_id, operation: operation},
      status_code: nil
    }
  end

  @doc """
  Create an invalid backup backend error.

  ## Examples

      error = Error.invalid_backend(:invalid)
  """
  @spec invalid_backend(atom()) :: t()
  def invalid_backend(backend) do
    %__MODULE__{
      type: :bad_request,
      message: "Invalid backup backend: #{inspect(backend)}",
      details: %{category: :backup, backend: backend},
      status_code: nil
    }
  end

  ## Cluster-Specific Errors

  @doc """
  Create a node not found error.

  ## Examples

      error = Error.node_not_found("node-1")
  """
  @spec node_not_found(String.t()) :: t()
  def node_not_found(node_name) do
    %__MODULE__{
      type: :not_found,
      message: "Node '#{node_name}' not found in cluster",
      details: %{category: :cluster, node: node_name},
      status_code: nil
    }
  end

  @doc """
  Create a shard not found error.

  ## Examples

      error = Error.shard_not_found("Article", "shard-1")
  """
  @spec shard_not_found(String.t(), String.t()) :: t()
  def shard_not_found(collection, shard_name) do
    %__MODULE__{
      type: :not_found,
      message: "Shard '#{shard_name}' not found in collection '#{collection}'",
      details: %{category: :cluster, collection: collection, shard: shard_name},
      status_code: nil
    }
  end

  @doc """
  Create a replication failed error.

  ## Examples

      error = Error.replication_failed("op-123", "target node unavailable")
  """
  @spec replication_failed(String.t(), String.t()) :: t()
  def replication_failed(operation_id, reason) do
    %__MODULE__{
      type: :replication_failed,
      message: "Replication operation '#{operation_id}' failed: #{reason}",
      details: %{category: :cluster, operation_id: operation_id},
      status_code: nil
    }
  end

  @doc """
  Create a replication timeout error.

  ## Examples

      error = Error.replication_timeout("op-123")
  """
  @spec replication_timeout(String.t()) :: t()
  def replication_timeout(operation_id) do
    %__MODULE__{
      type: :timeout_error,
      message: "Replication operation '#{operation_id}' timed out",
      details: %{category: :cluster, operation_id: operation_id},
      status_code: nil
    }
  end

  @doc """
  Create a cluster not ready error.

  ## Examples

      error = Error.cluster_not_ready()
  """
  @spec cluster_not_ready() :: t()
  def cluster_not_ready do
    %__MODULE__{
      type: :service_unavailable,
      message: "Cluster is not ready to accept requests",
      details: %{category: :cluster},
      status_code: nil
    }
  end

  @doc """
  Create a vector indexing timeout error.

  ## Examples

      error = Error.vector_indexing_timeout("Article")
  """
  @spec vector_indexing_timeout(String.t()) :: t()
  def vector_indexing_timeout(collection) do
    %__MODULE__{
      type: :timeout_error,
      message: "Vector indexing for collection '#{collection}' timed out",
      details: %{category: :batch, collection: collection},
      status_code: nil
    }
  end
end

defmodule WeaviateEx.Error.ClosedClientError do
  @moduledoc """
  Raised when operations are attempted on a closed client.

  This error indicates that the client has been explicitly closed
  and can no longer be used for operations.

  ## Example

      client = Client.new(base_url: "http://localhost:8080")
      Client.close(client)

      # This will raise ClosedClientError
      Client.request(client, :get, "/v1/meta", nil, [])
  """

  defexception [:message, :closed_at]

  @type t :: %__MODULE__{
          message: String.t(),
          closed_at: DateTime.t() | nil
        }

  @impl true
  def exception(opts) do
    closed_at = Keyword.get(opts, :closed_at)

    msg =
      if closed_at do
        "Client was closed at #{DateTime.to_string(closed_at)}. Create a new client to continue."
      else
        "Client was closed. Create a new client to continue."
      end

    %__MODULE__{message: msg, closed_at: closed_at}
  end
end

defmodule WeaviateEx.Error.VersionError do
  @moduledoc """
  Raised when connecting to an unsupported Weaviate server version.

  WeaviateEx requires Weaviate server version 1.27.0 or higher.
  This error provides detailed information about the version mismatch
  and how to resolve it.

  ## Example

      # Connecting to an old Weaviate server will raise:
      raise WeaviateEx.Error.VersionError,
        server_version: "1.20.0",
        min_version: "1.27.0"

  ## Bypassing Version Checks

  If you need to connect to an older server (not recommended), you can
  bypass version checks:

      {:ok, client} = WeaviateEx.Client.connect(
        base_url: "http://localhost:8080",
        skip_init_checks: true
      )
  """

  @min_version "1.27.0"

  defexception [:server_version, :min_version, :message]

  @type t :: %__MODULE__{
          server_version: String.t(),
          min_version: String.t(),
          message: String.t()
        }

  @impl true
  def exception(opts) do
    server_version = Keyword.get(opts, :server_version, "unknown")
    min_version = Keyword.get(opts, :min_version, @min_version)

    message = """
    Weaviate server version #{server_version} is not supported.
    Minimum required version: #{min_version}

    Please upgrade your Weaviate server or use skip_init_checks: true
    if you want to proceed anyway (not recommended).

    Example:
        {:ok, client} = WeaviateEx.Client.connect(
          base_url: "http://localhost:8080",
          skip_init_checks: true
        )
    """

    %__MODULE__{
      server_version: server_version,
      min_version: min_version,
      message: message
    }
  end
end
