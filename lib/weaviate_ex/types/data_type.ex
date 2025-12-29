defmodule WeaviateEx.Types.DataType do
  @moduledoc """
  Weaviate data types for property definitions.

  Provides type-safe conversion between Elixir atoms and Weaviate data type strings.

  ## Supported Types

  - `:text` / `:text_array` - Text values
  - `:int` / `:int_array` - Integer values
  - `:boolean` / `:boolean_array` - Boolean values
  - `:number` / `:number_array` - Floating point values
  - `:date` / `:date_array` - Date/time values (RFC3339)
  - `:uuid` / `:uuid_array` - UUID values
  - `:geo_coordinates` - Geographic coordinates (lat/lon)
  - `:blob` - Base64-encoded binary data
  - `:phone_number` - Phone numbers with parsing
  - `:object` / `:object_array` - Nested objects

  ## Examples

      iex> DataType.to_string(:text)
      "text"

      iex> DataType.from_string("geoCoordinates")
      {:ok, :geo_coordinates}

      iex> DataType.valid?(:text)
      true
  """

  @type t ::
          :text
          | :text_array
          | :int
          | :int_array
          | :boolean
          | :boolean_array
          | :number
          | :number_array
          | :date
          | :date_array
          | :uuid
          | :uuid_array
          | :geo_coordinates
          | :blob
          | :phone_number
          | :object
          | :object_array

  @data_types %{
    text: "text",
    text_array: "text[]",
    int: "int",
    int_array: "int[]",
    boolean: "boolean",
    boolean_array: "boolean[]",
    number: "number",
    number_array: "number[]",
    date: "date",
    date_array: "date[]",
    uuid: "uuid",
    uuid_array: "uuid[]",
    geo_coordinates: "geoCoordinates",
    blob: "blob",
    phone_number: "phoneNumber",
    object: "object",
    object_array: "object[]"
  }

  @array_types [
    :text_array,
    :int_array,
    :boolean_array,
    :number_array,
    :date_array,
    :uuid_array,
    :object_array
  ]

  @doc """
  Convert atom to Weaviate data type string.

  ## Examples

      iex> DataType.to_string(:text)
      "text"

      iex> DataType.to_string(:geo_coordinates)
      "geoCoordinates"
  """
  @spec to_string(t()) :: String.t()
  def to_string(type) when is_atom(type) do
    Map.fetch!(@data_types, type)
  end

  @doc """
  Convert Weaviate data type string to atom.

  ## Examples

      iex> DataType.from_string("text")
      {:ok, :text}

      iex> DataType.from_string("unknown")
      {:error, {:unknown_data_type, "unknown"}}
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, {:unknown_data_type, String.t()}}
  def from_string(str) when is_binary(str) do
    @data_types
    |> Enum.find(fn {_k, v} -> v == str end)
    |> case do
      {key, _} -> {:ok, key}
      nil -> {:error, {:unknown_data_type, str}}
    end
  end

  @doc """
  List all supported data types.

  ## Examples

      iex> :text in DataType.all()
      true
  """
  @spec all() :: [t()]
  def all, do: Map.keys(@data_types)

  @doc """
  Check if a data type atom is valid.

  ## Examples

      iex> DataType.valid?(:text)
      true

      iex> DataType.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(type) when is_atom(type) do
    Map.has_key?(@data_types, type)
  end

  @doc """
  Check if a data type is an array type.

  ## Examples

      iex> DataType.array?(:text_array)
      true

      iex> DataType.array?(:text)
      false
  """
  @spec array?(t()) :: boolean()
  def array?(type) when is_atom(type) do
    type in @array_types
  end
end
