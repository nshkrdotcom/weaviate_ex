defmodule WeaviateEx.Client.Config do
  @moduledoc """
  Client configuration.
  """

  @type t :: %__MODULE__{
          base_url: String.t(),
          grpc_host: String.t() | nil,
          grpc_port: integer() | nil,
          api_key: String.t() | nil,
          timeout: integer(),
          protocol: :http | :grpc | :auto
        }

  defstruct [
    :base_url,
    :grpc_host,
    :grpc_port,
    :api_key,
    timeout: 60_000,
    protocol: :http
  ]

  @doc "Create config from keyword list"
  def new(opts \\ []) do
    %__MODULE__{
      base_url: Keyword.get(opts, :base_url, "http://localhost:8080"),
      grpc_host: Keyword.get(opts, :grpc_host),
      grpc_port: Keyword.get(opts, :grpc_port),
      api_key: Keyword.get(opts, :api_key),
      timeout: Keyword.get(opts, :timeout, 60_000),
      protocol: Keyword.get(opts, :protocol, :http)
    }
  end
end
