defmodule WeaviateEx.HTTPClient.Finch do
  @moduledoc """
  Production HTTP client implementation using Finch.
  """

  @behaviour WeaviateEx.HTTPClient

  @impl true
  def request(method, url, headers, body, opts) do
    request = Finch.build(method, url, headers, body)

    case Finch.request(request, WeaviateEx.Finch, opts) do
      {:ok, %Finch.Response{status: status, body: response_body, headers: response_headers}} ->
        {:ok, %{status: status, body: response_body, headers: response_headers}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
