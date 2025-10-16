defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @impl true
  def request(%Client{} = _client, _method, _path, _body, _opts) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.Protocol.HTTP.Client.request/5

    This function needs to:
    1. Build HTTP request with Finch
    2. Add authentication headers
    3. Execute request
    4. Parse response
    5. Handle errors

    See test: test/weaviate_ex/protocol/http/client_test.exs
    """
  end
end
