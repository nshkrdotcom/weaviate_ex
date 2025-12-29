defmodule WeaviateEx.Types.UUID do
  @moduledoc """
  UUID utilities for Weaviate objects.

  Provides UUID generation, validation, and deterministic UUID creation.

  ## Examples

      # Generate new UUID
      uuid = UUID.generate()

      # Validate UUID
      {:ok, uuid} = UUID.validate("550e8400-e29b-41d4-a716-446655440000")

      # Generate deterministic UUID from string
      uuid = UUID.from_string("Article", "my-unique-id")
  """

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  @doc """
  Generate a new random UUID v4.

  ## Examples

      iex> uuid = UUID.generate()
      iex> UUID.valid?(uuid)
      true
  """
  @spec generate() :: String.t()
  def generate do
    # Generate 16 random bytes
    bytes = :crypto.strong_rand_bytes(16)

    # Set version to 4 (random) and variant to RFC 4122
    <<a::48, _version::4, b::12, _variant::2, c::62>> = bytes
    uuid_bytes = <<a::48, 4::4, b::12, 2::2, c::62>>

    format_uuid(uuid_bytes)
  end

  @doc """
  Validate a UUID string.

  Returns the UUID normalized to lowercase if valid.

  ## Examples

      iex> UUID.validate("550e8400-e29b-41d4-a716-446655440000")
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}

      iex> UUID.validate("550E8400-E29B-41D4-A716-446655440000")
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}

      iex> UUID.validate("invalid")
      {:error, "Invalid UUID format: invalid"}
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate(uuid) when is_binary(uuid) do
    if Regex.match?(@uuid_regex, uuid) do
      {:ok, String.downcase(uuid)}
    else
      {:error, "Invalid UUID format: #{uuid}"}
    end
  end

  @doc """
  Check if string is valid UUID.

  ## Examples

      iex> UUID.valid?("550e8400-e29b-41d4-a716-446655440000")
      true

      iex> UUID.valid?("invalid")
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(uuid) when is_binary(uuid) do
    Regex.match?(@uuid_regex, uuid)
  end

  @doc """
  Generate a deterministic UUID v5 from namespace and name.

  Useful for creating reproducible UUIDs from string identifiers.

  ## Examples

      iex> UUID.from_string("Article", "my-unique-id")
      "..." # Same result every time for same inputs

      iex> UUID.from_string("Article", "id-1") == UUID.from_string("Article", "id-2")
      false
  """
  @spec from_string(String.t(), String.t()) :: String.t()
  def from_string(namespace, name) when is_binary(namespace) and is_binary(name) do
    # Create a hash from namespace and name (similar to UUID v5)
    hash = :crypto.hash(:sha, namespace <> name)

    # Take first 16 bytes
    <<uuid_bytes::binary-size(16), _rest::binary>> = hash

    # Set version to 5 (SHA-1) and variant to RFC 4122
    <<a::48, _version::4, b::12, _variant::2, c::62>> = uuid_bytes
    modified_bytes = <<a::48, 5::4, b::12, 2::2, c::62>>

    format_uuid(modified_bytes)
  end

  # Format 16 bytes as UUID string
  defp format_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    hex = fn int, len ->
      int
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(len, "0")
    end

    "#{hex.(a, 8)}-#{hex.(b, 4)}-#{hex.(c, 4)}-#{hex.(d, 4)}-#{hex.(e, 12)}"
  end
end
