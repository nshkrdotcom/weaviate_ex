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
end
