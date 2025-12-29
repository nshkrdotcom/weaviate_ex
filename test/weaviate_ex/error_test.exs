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
end
