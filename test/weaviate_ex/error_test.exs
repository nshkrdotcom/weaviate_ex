defmodule WeaviateEx.ErrorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Error

  describe "from_status_code/2" do
    test "maps 400 to bad_request" do
      error = Error.from_status_code(400, %{"message" => "Bad request"})

      assert error.type == :bad_request
      assert error.status_code == 400
    end

    test "maps 401 to authentication_failed" do
      error = Error.from_status_code(401, %{"message" => "Unauthorized"})

      assert error.type == :authentication_failed
    end

    test "maps 403 to forbidden" do
      error = Error.from_status_code(403, %{"message" => "Forbidden"})

      assert error.type == :forbidden
    end

    test "maps 404 to not_found" do
      error = Error.from_status_code(404, %{"message" => "Not found"})

      assert error.type == :not_found
    end

    test "extracts message from body" do
      error = Error.from_status_code(500, %{"message" => "Server error occurred"})

      assert error.message == "Server error occurred"
    end
  end

  describe "rbac_error/3" do
    test "creates error with rbac category" do
      error = Error.rbac_error(:not_found, "Role not found", %{role: "admin"})

      assert error.type == :not_found
      assert error.message == "Role not found"
      assert error.details[:category] == :rbac
      assert error.details[:role] == "admin"
    end

    test "defaults to empty details" do
      error = Error.rbac_error(:forbidden, "Access denied")

      assert error.details[:category] == :rbac
    end
  end

  describe "role_not_found/1" do
    test "creates proper error struct" do
      error = Error.role_not_found("admin")

      assert error.type == :not_found
      assert error.message == "Role 'admin' not found"
      assert error.details[:role] == "admin"
      assert error.details[:category] == :rbac
    end
  end

  describe "permission_denied/2" do
    test "includes action and resource" do
      error = Error.permission_denied(:delete, "Article")

      assert error.type == :forbidden
      assert error.message == "Permission denied for delete on Article"
      assert error.details[:action] == :delete
      assert error.details[:resource] == "Article"
      assert error.details[:category] == :rbac
    end
  end

  describe "user_not_found/1" do
    test "creates proper error struct" do
      error = Error.user_not_found("john.doe")

      assert error.type == :not_found
      assert error.message == "User 'john.doe' not found"
      assert error.details[:user_id] == "john.doe"
    end
  end

  describe "invalid_permission/1" do
    test "creates proper error struct" do
      error = Error.invalid_permission("Unknown action type")

      assert error.type == :bad_request
      assert error.message == "Invalid permission: Unknown action type"
    end
  end

  describe "grpc_retryable?/1" do
    test "returns true for retryable statuses" do
      assert Error.grpc_retryable?(:unavailable) == true
      assert Error.grpc_retryable?(:resource_exhausted) == true
      assert Error.grpc_retryable?(:aborted) == true
      assert Error.grpc_retryable?(:deadline_exceeded) == true
    end

    test "returns false for non-retryable statuses" do
      assert Error.grpc_retryable?(:invalid_argument) == false
      assert Error.grpc_retryable?(:not_found) == false
      assert Error.grpc_retryable?(:permission_denied) == false
    end
  end

  describe "backup_not_found/2" do
    test "creates correct error" do
      error = Error.backup_not_found("backup-123", :filesystem)

      assert error.type == :not_found
      assert error.message == "Backup 'backup-123' not found in filesystem storage"
      assert error.details[:category] == :backup
      assert error.details[:backup_id] == "backup-123"
      assert error.details[:backend] == :filesystem
    end
  end

  describe "backup_already_exists/2" do
    test "creates correct error" do
      error = Error.backup_already_exists("backup-123", :s3)

      assert error.type == :conflict
      assert error.message == "Backup 'backup-123' already exists in s3 storage"
      assert error.details[:category] == :backup
      assert error.details[:backup_id] == "backup-123"
      assert error.details[:backend] == :s3
    end
  end

  describe "backup_failed/2" do
    test "creates correct error" do
      error = Error.backup_failed("backup-123", "disk full")

      assert error.type == :backup_failed
      assert error.message == "Backup 'backup-123' failed: disk full"
      assert error.details[:category] == :backup
      assert error.details[:backup_id] == "backup-123"
    end
  end

  describe "restore_failed/2" do
    test "creates correct error" do
      error = Error.restore_failed("backup-123", "collection exists")

      assert error.type == :restore_failed
      assert error.message == "Restore of 'backup-123' failed: collection exists"
      assert error.details[:category] == :backup
      assert error.details[:backup_id] == "backup-123"
    end
  end

  describe "backup_timeout/2" do
    test "creates correct error for create operation" do
      error = Error.backup_timeout("backup-123", :create)

      assert error.type == :timeout_error
      assert error.message == "create operation for backup 'backup-123' timed out"
      assert error.details[:category] == :backup
      assert error.details[:backup_id] == "backup-123"
      assert error.details[:operation] == :create
    end

    test "creates correct error for restore operation" do
      error = Error.backup_timeout("backup-123", :restore)

      assert error.type == :timeout_error
      assert error.message == "restore operation for backup 'backup-123' timed out"
      assert error.details[:operation] == :restore
    end
  end

  describe "invalid_backend/1" do
    test "creates correct error" do
      error = Error.invalid_backend(:invalid)

      assert error.type == :bad_request
      assert error.message == "Invalid backup backend: :invalid"
      assert error.details[:category] == :backup
      assert error.details[:backend] == :invalid
    end
  end
end

defmodule WeaviateEx.Error.VersionErrorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Error.VersionError

  describe "exception/1" do
    test "creates VersionError with server and min versions" do
      error = VersionError.exception(server_version: "1.20.0", min_version: "1.27.0")

      assert error.server_version == "1.20.0"
      assert error.min_version == "1.27.0"
      assert error.message =~ "1.20.0"
      assert error.message =~ "1.27.0"
      assert error.message =~ "not supported"
    end

    test "defaults to unknown server version" do
      error = VersionError.exception([])

      assert error.server_version == "unknown"
    end

    test "defaults to 1.27.0 min version" do
      error = VersionError.exception([])

      assert error.min_version == "1.27.0"
    end

    test "message includes skip_init_checks workaround" do
      error = VersionError.exception(server_version: "1.20.0")

      assert error.message =~ "skip_init_checks: true"
    end

    test "is raisable as exception" do
      assert_raise VersionError, ~r/1\.20\.0/, fn ->
        raise VersionError, server_version: "1.20.0"
      end
    end
  end
end

defmodule WeaviateEx.Error.ClosedClientErrorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Error.ClosedClientError

  describe "exception/1" do
    test "creates error without closed_at" do
      error = ClosedClientError.exception([])

      assert error.message =~ "Client was closed"
      assert error.message =~ "Create a new client"
      assert error.closed_at == nil
    end

    test "creates error with closed_at timestamp" do
      now = DateTime.utc_now()
      error = ClosedClientError.exception(closed_at: now)

      assert error.message =~ DateTime.to_string(now)
      assert error.closed_at == now
    end

    test "is raisable as exception" do
      assert_raise ClosedClientError, ~r/Client was closed/, fn ->
        raise ClosedClientError, []
      end
    end
  end
end
