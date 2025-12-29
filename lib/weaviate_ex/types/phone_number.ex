defmodule WeaviateEx.Types.PhoneNumber do
  @moduledoc """
  Phone number type for Weaviate.

  Input format is simple (number + optional default country).
  Output includes parsed data returned by Weaviate.

  ## Examples

      # Input
      phone = PhoneNumber.new("+1 650-253-0000")
      PhoneNumber.to_map(phone)
      # => %{"input" => "+1 650-253-0000"}

      # With default country
      phone = PhoneNumber.new("650-253-0000", default_country: "US")
      PhoneNumber.to_map(phone)
      # => %{"input" => "650-253-0000", "defaultCountry" => "US"}
  """

  @type t :: %__MODULE__{
          number: String.t(),
          default_country: String.t() | nil
        }

  defstruct [:number, :default_country]

  defmodule Output do
    @moduledoc "Parsed phone number from Weaviate response"

    @type t :: %__MODULE__{
            input: String.t() | nil,
            country_code: integer() | nil,
            default_country: String.t() | nil,
            international_formatted: String.t() | nil,
            national: integer() | nil,
            national_formatted: String.t() | nil,
            valid: boolean() | nil
          }

    defstruct [
      :input,
      :country_code,
      :default_country,
      :international_formatted,
      :national,
      :national_formatted,
      :valid
    ]

    @doc """
    Parse from Weaviate API response.

    ## Examples

        iex> Output.from_map(%{"input" => "+1 650-253-0000", "valid" => true})
        %Output{input: "+1 650-253-0000", valid: true}
    """
    @spec from_map(map()) :: t()
    def from_map(map) when is_map(map) do
      %__MODULE__{
        input: map["input"],
        country_code: map["countryCode"],
        default_country: map["defaultCountry"],
        international_formatted: map["internationalFormatted"],
        national: map["national"],
        national_formatted: map["nationalFormatted"],
        valid: map["valid"]
      }
    end
  end

  @doc """
  Create a new phone number input.

  ## Parameters

    - `number` - The phone number string
    - `opts` - Options:
      - `:default_country` - Default country code (e.g., "US", "DE")

  ## Examples

      iex> PhoneNumber.new("+1 650-253-0000")
      %PhoneNumber{number: "+1 650-253-0000", default_country: nil}

      iex> PhoneNumber.new("650-253-0000", default_country: "US")
      %PhoneNumber{number: "650-253-0000", default_country: "US"}
  """
  @spec new(String.t(), keyword()) :: t()
  def new(number, opts \\ []) when is_binary(number) do
    %__MODULE__{
      number: number,
      default_country: Keyword.get(opts, :default_country)
    }
  end

  @doc """
  Convert to map for Weaviate API.

  ## Examples

      iex> PhoneNumber.new("+1 650-253-0000") |> PhoneNumber.to_map()
      %{"input" => "+1 650-253-0000"}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{number: num, default_country: nil}) do
    %{"input" => num}
  end

  def to_map(%__MODULE__{number: num, default_country: country}) do
    %{"input" => num, "defaultCountry" => country}
  end

  @doc """
  Parse phone number output from Weaviate API response.

  Delegates to `Output.from_map/1`.
  """
  @spec from_map(map()) :: Output.t()
  def from_map(map), do: Output.from_map(map)
end
