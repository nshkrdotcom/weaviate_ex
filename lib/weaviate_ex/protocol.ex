defmodule WeaviateEx.Protocol do
  @moduledoc """
  Protocol behavior for HTTP and gRPC implementations.
  """

  @type method :: :get | :post | :put | :patch | :delete | :head
  @type path :: String.t()
  @type body :: map() | list() | nil
  @type opts :: keyword()
  @type response :: {:ok, map() | list()} | {:error, WeaviateEx.Error.t()}

  @callback request(client :: term(), method(), path(), body(), opts()) :: response()
end
