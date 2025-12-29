defmodule WeaviateEx.ErrorGRPCTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Error

  describe "from_grpc_status/3" do
    test "maps :not_found to :not_found" do
      error = Error.from_grpc_status(:not_found, "Object not found")
      assert error.type == :not_found
      assert error.message == "Object not found"
      assert error.details.grpc_status == :not_found
    end

    test "maps :unavailable to :service_unavailable" do
      error = Error.from_grpc_status(:unavailable, "Service unavailable")
      assert error.type == :service_unavailable
    end

    test "maps :invalid_argument to :bad_request" do
      error = Error.from_grpc_status(:invalid_argument, "Invalid input")
      assert error.type == :bad_request
    end

    test "maps :deadline_exceeded to :timeout_error" do
      error = Error.from_grpc_status(:deadline_exceeded, "Timeout")
      assert error.type == :timeout_error
    end

    test "maps :already_exists to :conflict" do
      error = Error.from_grpc_status(:already_exists, "Already exists")
      assert error.type == :conflict
    end

    test "maps :permission_denied to :forbidden" do
      error = Error.from_grpc_status(:permission_denied, "Access denied")
      assert error.type == :forbidden
    end

    test "maps :resource_exhausted to :rate_limited" do
      error = Error.from_grpc_status(:resource_exhausted, "Rate limited")
      assert error.type == :rate_limited
    end

    test "maps :failed_precondition to :validation_error" do
      error = Error.from_grpc_status(:failed_precondition, "Precondition failed")
      assert error.type == :validation_error
    end

    test "maps :unimplemented to :not_implemented" do
      error = Error.from_grpc_status(:unimplemented, "Not implemented")
      assert error.type == :not_implemented
    end

    test "maps :internal to :server_error" do
      error = Error.from_grpc_status(:internal, "Internal error")
      assert error.type == :server_error
    end

    test "maps :unauthenticated to :authentication_failed" do
      error = Error.from_grpc_status(:unauthenticated, "Auth failed")
      assert error.type == :authentication_failed
    end

    test "maps unknown status to :unknown_error" do
      error = Error.from_grpc_status(:unknown_status, "Unknown")
      assert error.type == :unknown_error
    end

    test "includes additional details" do
      details = %{request_id: "123"}
      error = Error.from_grpc_status(:not_found, "Not found", details)
      assert error.details.grpc_status == :not_found
      assert error.details.request_id == "123"
    end
  end

  describe "from_grpc_error/1" do
    test "converts GRPC.RPCError with status 5 to :not_found" do
      rpc_error = %GRPC.RPCError{status: 5, message: "Not found"}
      error = Error.from_grpc_error(rpc_error)
      assert error.type == :not_found
      assert error.message == "Not found"
    end

    test "converts GRPC.RPCError with status 14 to :service_unavailable" do
      rpc_error = %GRPC.RPCError{status: 14, message: "Unavailable"}
      error = Error.from_grpc_error(rpc_error)
      assert error.type == :service_unavailable
    end

    test "converts GRPC.RPCError with status 3 to :bad_request" do
      rpc_error = %GRPC.RPCError{status: 3, message: "Invalid argument"}
      error = Error.from_grpc_error(rpc_error)
      assert error.type == :bad_request
    end
  end

  describe "grpc_retryable?/1" do
    test "returns true for :unavailable" do
      assert Error.grpc_retryable?(:unavailable) == true
    end

    test "returns true for :resource_exhausted" do
      assert Error.grpc_retryable?(:resource_exhausted) == true
    end

    test "returns true for :aborted" do
      assert Error.grpc_retryable?(:aborted) == true
    end

    test "returns true for :deadline_exceeded" do
      assert Error.grpc_retryable?(:deadline_exceeded) == true
    end

    test "returns false for :invalid_argument" do
      assert Error.grpc_retryable?(:invalid_argument) == false
    end

    test "returns false for :not_found" do
      assert Error.grpc_retryable?(:not_found) == false
    end

    test "returns false for :permission_denied" do
      assert Error.grpc_retryable?(:permission_denied) == false
    end

    test "returns false for :unauthenticated" do
      assert Error.grpc_retryable?(:unauthenticated) == false
    end
  end
end
