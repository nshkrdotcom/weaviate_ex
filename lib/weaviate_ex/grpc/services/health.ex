defmodule WeaviateEx.GRPC.Services.Health do
  @moduledoc """
  gRPC Health service for health checks.

  This module provides functions for checking the health status
  of the Weaviate gRPC server.

  ## Usage

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      {:ok, :serving} = Health.check(channel)
      # or
      {:error, :not_serving} = Health.check(channel)
  """

  alias WeaviateEx.Error

  alias Weaviate.V1.{
    WeaviateHealthCheckRequest,
    WeaviateHealthCheckResponse
  }

  alias Weaviate.V1.WeaviateHealth.Stub, as: WeaviateHealthStub

  @type health_opts :: [
          timeout: non_neg_integer(),
          service: String.t()
        ]

  @doc """
  Check the health status of the Weaviate gRPC server.

  Returns `:serving` if the server is healthy, otherwise an error.

  ## Options

    * `:timeout` - Request timeout in milliseconds (default: 5000)
    * `:service` - Service name to check (default: "")

  ## Examples

      {:ok, :serving} = Health.check(channel)
      {:error, %Error{type: :service_unavailable}} = Health.check(channel)
  """
  @spec check(GRPC.Channel.t(), health_opts()) ::
          {:ok, :serving} | {:error, Error.t()}
  def check(channel, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    service = Keyword.get(opts, :service, "")

    request = %WeaviateHealthCheckRequest{
      service: service
    }

    # Use unary_unary for health check
    # The health service uses a standard gRPC health check endpoint
    case execute_health_check(channel, request, timeout) do
      {:ok, %WeaviateHealthCheckResponse{status: :SERVING}} ->
        {:ok, :serving}

      {:ok, %WeaviateHealthCheckResponse{status: :NOT_SERVING}} ->
        {:error,
         Error.exception(
           type: :service_unavailable,
           message: "Weaviate gRPC service is not serving"
         )}

      {:ok, %WeaviateHealthCheckResponse{status: :UNKNOWN}} ->
        {:error,
         Error.exception(
           type: :unknown_error,
           message: "Weaviate gRPC service status is unknown"
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if the server is healthy (returns boolean).

  ## Examples

      true = Health.healthy?(channel)
      false = Health.healthy?(channel)
  """
  @spec healthy?(GRPC.Channel.t(), health_opts()) :: boolean()
  def healthy?(channel, opts \\ []) do
    case check(channel, opts) do
      {:ok, :serving} -> true
      _ -> false
    end
  end

  @doc """
  Wait for the server to become healthy.

  Polls the health endpoint until the server is serving or timeout is reached.

  ## Options

    * `:timeout` - Total timeout in milliseconds (default: 30000)
    * `:interval` - Polling interval in milliseconds (default: 1000)

  ## Examples

      :ok = Health.wait_for_ready(channel, timeout: 60_000)
      {:error, :timeout} = Health.wait_for_ready(channel, timeout: 5_000)
  """
  @spec wait_for_ready(GRPC.Channel.t(), keyword()) :: :ok | {:error, :timeout | Error.t()}
  def wait_for_ready(channel, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    interval = Keyword.get(opts, :interval, 1_000)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_ready(channel, deadline, interval, opts)
  end

  # Private functions

  defp execute_health_check(channel, request, timeout) do
    # Use the generated WeaviateHealth stub for proper gRPC calls
    opts = [timeout: timeout]

    case WeaviateHealthStub.check(channel, request, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, %GRPC.RPCError{} = error} ->
        {:error, Error.from_grpc_error(error)}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
    end
  rescue
    # If the health check service is not available
    e in [FunctionClauseError, UndefinedFunctionError] ->
      {:error,
       Error.exception(
         type: :not_implemented,
         message: "Health check not available: #{inspect(e)}"
       )}
  end

  defp do_wait_for_ready(channel, deadline, interval, opts) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      {:error, :timeout}
    else
      case check(channel, opts) do
        {:ok, :serving} ->
          :ok

        {:error, _} ->
          Process.sleep(interval)
          do_wait_for_ready(channel, deadline, interval, opts)
      end
    end
  end
end
