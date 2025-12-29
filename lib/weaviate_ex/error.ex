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
end
