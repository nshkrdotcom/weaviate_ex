defmodule WeaviateEx.Types.GeoCoordinate do
  @moduledoc """
  Represents a geographic coordinate (latitude/longitude).

  ## Constraints

  - Latitude: -90 to 90 degrees
  - Longitude: -180 to 180 degrees

  ## Examples

      {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
      GeoCoordinate.to_map(coord)
      # => %{"latitude" => 52.3676, "longitude" => 4.9041}

      coord = GeoCoordinate.new!(40.7128, -74.0060)
  """

  @type t :: %__MODULE__{
          latitude: float(),
          longitude: float()
        }

  defstruct [:latitude, :longitude]

  @doc """
  Create a new GeoCoordinate.

  ## Parameters

    - `latitude` - Latitude value (-90 to 90)
    - `longitude` - Longitude value (-180 to 180)

  ## Examples

      iex> GeoCoordinate.new(52.3676, 4.9041)
      {:ok, %GeoCoordinate{latitude: 52.3676, longitude: 4.9041}}

      iex> GeoCoordinate.new(91.0, 0.0)
      {:error, "Latitude must be between -90 and 90, got: 91.0"}
  """
  @spec new(number(), number()) :: {:ok, t()} | {:error, String.t()}
  def new(latitude, longitude)
      when is_number(latitude) and is_number(longitude) and
             latitude >= -90 and latitude <= 90 and
             longitude >= -180 and longitude <= 180 do
    {:ok, %__MODULE__{latitude: latitude, longitude: longitude}}
  end

  def new(latitude, longitude) when is_number(latitude) and is_number(longitude) do
    cond do
      latitude < -90 or latitude > 90 ->
        {:error, "Latitude must be between -90 and 90, got: #{latitude}"}

      longitude < -180 or longitude > 180 ->
        {:error, "Longitude must be between -180 and 180, got: #{longitude}"}
    end
  end

  def new(_latitude, _longitude) do
    {:error, "Latitude and longitude must be numbers"}
  end

  @doc """
  Create a new GeoCoordinate, raising on invalid input.

  ## Parameters

    - `latitude` - Latitude value (-90 to 90)
    - `longitude` - Longitude value (-180 to 180)

  ## Examples

      iex> GeoCoordinate.new!(52.3676, 4.9041)
      %GeoCoordinate{latitude: 52.3676, longitude: 4.9041}

      iex> GeoCoordinate.new!(91.0, 0.0)
      ** (ArgumentError) Latitude must be between -90 and 90, got: 91.0
  """
  @spec new!(number(), number()) :: t()
  def new!(latitude, longitude) do
    case new(latitude, longitude) do
      {:ok, coord} -> coord
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @doc """
  Convert to map for Weaviate API.

  ## Examples

      iex> {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
      iex> GeoCoordinate.to_map(coord)
      %{"latitude" => 52.3676, "longitude" => 4.9041}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{latitude: lat, longitude: lon}) do
    %{"latitude" => lat, "longitude" => lon}
  end

  @doc """
  Parse from Weaviate API response.

  ## Examples

      iex> GeoCoordinate.from_map(%{"latitude" => 52.3676, "longitude" => 4.9041})
      {:ok, %GeoCoordinate{latitude: 52.3676, longitude: 4.9041}}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(%{"latitude" => lat, "longitude" => lon}) do
    new(lat, lon)
  end

  def from_map(_), do: {:error, "Invalid geo coordinate format"}
end
