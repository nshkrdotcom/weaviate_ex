defmodule WeaviateEx.Version do
  @moduledoc """
  Weaviate server version detection and validation.

  Ensures client compatibility with the connected Weaviate instance.
  The minimum supported version is 1.27.0.

  ## Examples

      # Parse a version string
      {:ok, {1, 28, 0}} = Version.parse("1.28.0")

      # Check if a version meets the minimum requirement
      true = Version.meets_minimum?({1, 28, 0}, {1, 27, 0})

      # Validate server version
      :ok = Version.validate_server({1, 28, 0})
  """

  @minimum_version {1, 27, 0}
  @minimum_version_string "1.27.0"

  @type version :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @doc """
  Parse a version string into a tuple.

  Handles versions with or without 'v' prefix, and ignores prerelease/build metadata.

  ## Examples

      iex> Version.parse("1.28.0")
      {:ok, {1, 28, 0}}

      iex> Version.parse("v1.28.0-rc1")
      {:ok, {1, 28, 0}}

      iex> Version.parse("invalid")
      {:error, :invalid_version}
  """
  @spec parse(String.t()) :: {:ok, version()} | {:error, :invalid_version}
  def parse(version_string) when is_binary(version_string) do
    # Remove 'v' prefix if present
    cleaned = String.trim_leading(version_string, "v")

    # Extract major.minor.patch, ignoring prerelease
    case Regex.run(~r/^(\d+)\.(\d+)\.(\d+)/, cleaned) do
      [_, major, minor, patch] ->
        {:ok, {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}}

      _ ->
        {:error, :invalid_version}
    end
  end

  @doc """
  Check if a version meets the minimum requirement.

  ## Examples

      iex> Version.meets_minimum?({1, 28, 0}, {1, 27, 0})
      true

      iex> Version.meets_minimum?({1, 26, 0}, {1, 27, 0})
      false
  """
  @spec meets_minimum?(version(), version()) :: boolean()
  def meets_minimum?({maj1, min1, pat1}, {maj2, min2, pat2}) do
    cond do
      maj1 > maj2 -> true
      maj1 < maj2 -> false
      min1 > min2 -> true
      min1 < min2 -> false
      pat1 >= pat2 -> true
      true -> false
    end
  end

  @doc """
  Extract server version from meta endpoint response.

  The meta response is expected to have a "version" key with a version string.

  ## Examples

      iex> Version.get_server_version(%{"version" => "1.28.0"})
      {:ok, {1, 28, 0}}

      iex> Version.get_server_version(%{})
      {:error, :no_version}
  """
  @spec get_server_version(map()) :: {:ok, version()} | {:error, :no_version | :invalid_version}
  def get_server_version(%{"version" => version}) when is_binary(version) do
    parse(version)
  end

  def get_server_version(_), do: {:error, :no_version}

  @doc """
  Validate that a server version is supported.

  Returns `:ok` if the version meets the minimum requirement (#{@minimum_version_string}),
  otherwise returns an error with both the actual and minimum versions.

  ## Examples

      iex> Version.validate_server({1, 28, 0})
      :ok

      iex> Version.validate_server({1, 20, 0})
      {:error, {:unsupported_version, {1, 20, 0}, {1, 27, 0}}}
  """
  @spec validate_server(version()) :: :ok | {:error, {:unsupported_version, version(), version()}}
  def validate_server(version) do
    if meets_minimum?(version, @minimum_version) do
      :ok
    else
      {:error, {:unsupported_version, version, @minimum_version}}
    end
  end

  @doc """
  Get the minimum supported Weaviate version.

  ## Examples

      iex> Version.minimum_version()
      {1, 27, 0}
  """
  @spec minimum_version() :: version()
  def minimum_version, do: @minimum_version

  @doc """
  Get the minimum supported version as a string.

  ## Examples

      iex> Version.minimum_version_string()
      "1.27.0"
  """
  @spec minimum_version_string() :: String.t()
  def minimum_version_string, do: @minimum_version_string

  @doc """
  Format a version tuple to a string.

  ## Examples

      iex> Version.format_version({1, 28, 0})
      "1.28.0"
  """
  @spec format_version(version()) :: String.t()
  def format_version({major, minor, patch}) do
    "#{major}.#{minor}.#{patch}"
  end

  @doc """
  Extract gRPC max message size from meta response.

  Weaviate returns the maximum gRPC message size in the meta endpoint.

  ## Examples

      Version.get_grpc_max_message_size(%{"grpcMaxMessageSize" => 104858000})
      # => {:ok, 104858000}

      Version.get_grpc_max_message_size(%{})
      # => :default
  """
  @spec get_grpc_max_message_size(map()) :: {:ok, pos_integer()} | :default
  def get_grpc_max_message_size(%{"grpcMaxMessageSize" => size}) when is_integer(size) do
    {:ok, size}
  end

  def get_grpc_max_message_size(%{"grpcMaxMessageSize" => size}) when is_binary(size) do
    {:ok, String.to_integer(size)}
  end

  def get_grpc_max_message_size(_), do: :default
end
