defmodule WeaviateEx.Client do
  @moduledoc """
  WeaviateEx client.
  """

  alias WeaviateEx.Client.Config
  alias WeaviateEx.Protocol

  @type t :: %__MODULE__{
          config: Config.t(),
          protocol_impl: module()
        }

  defstruct [:config, :protocol_impl]

  @doc """
  Create a new client.

  ## Examples

      {:ok, client} = WeaviateEx.Client.new(
        base_url: "http://localhost:8080",
        api_key: "secret-key"
      )
  """
  @spec new(keyword()) :: {:ok, t()}
  def new(opts \\ []) do
    config = Config.new(opts)
    # Check Application config first, then opts, then default to HTTP client
    protocol_impl =
      Keyword.get(opts, :protocol_impl) ||
        Application.get_env(:weaviate_ex, :protocol_impl) ||
        WeaviateEx.Protocol.HTTP.Client

    client = %__MODULE__{
      config: config,
      protocol_impl: protocol_impl
    }

    {:ok, client}
  end

  @doc "Make a request using the configured protocol"
  @spec request(t(), Protocol.method(), Protocol.path(), Protocol.body(), Protocol.opts()) ::
          Protocol.response()
  def request(%__MODULE__{protocol_impl: impl} = client, method, path, body, opts) do
    impl.request(client, method, path, body, opts)
  end
end
