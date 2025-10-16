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

  defp status_to_type(code) do
    case code do
      400 -> :bad_request
      401 -> :authentication_failed
      403 -> :forbidden
      404 -> :not_found
      409 -> :conflict
      422 -> :validation_error
      500 -> :server_error
      503 -> :service_unavailable
      _ -> :unknown_error
    end
  end

  defp extract_message(body) when is_map(body) do
    body["message"] || body["error"] || "Request failed"
  end

  defp extract_message(_), do: "Request failed"
end
