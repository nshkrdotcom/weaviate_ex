# Start ExUnit with async test support
ExUnit.start()

# Note: Support files are automatically compiled via elixirc_paths in mix.exs
# No need to require them here as it causes module redefinition warnings

# Configure Mox
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Set global mode for async tests
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Disable strict health checks during tests
Application.put_env(:weaviate_ex, :strict, false)

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :property, :performance])

defmodule WeaviateEx.TestHelpers do
  @moduledoc """
  Shared test helpers and utilities.
  """

  @doc """
  Checks if we should run tests against a live Weaviate instance.

  Set WEAVIATE_INTEGRATION=true to enable integration tests.
  """
  def integration_mode? do
    System.get_env("WEAVIATE_INTEGRATION") == "true"
  end

  @doc """
  Sets up the appropriate Protocol implementation based on test mode.

  - In mock mode: Uses WeaviateEx.Protocol.Mock
  - In integration mode: Uses WeaviateEx.Protocol.HTTP.Client (real HTTP)
  """
  def setup_protocol(_context) do
    if integration_mode?() do
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
      :ok
    else
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)
      :ok
    end
  end
end
