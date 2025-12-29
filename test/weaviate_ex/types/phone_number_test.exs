defmodule WeaviateEx.Types.PhoneNumberTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.PhoneNumber

  describe "new/2" do
    test "creates phone number without default country" do
      phone = PhoneNumber.new("+1 650-253-0000")
      assert phone.number == "+1 650-253-0000"
      assert phone.default_country == nil
    end

    test "creates phone number with default country" do
      phone = PhoneNumber.new("650-253-0000", default_country: "US")
      assert phone.number == "650-253-0000"
      assert phone.default_country == "US"
    end
  end

  describe "to_map/1" do
    test "converts to Weaviate API format without default country" do
      phone = PhoneNumber.new("+1 650-253-0000")

      assert PhoneNumber.to_map(phone) == %{
               "input" => "+1 650-253-0000"
             }
    end

    test "converts to Weaviate API format with default country" do
      phone = PhoneNumber.new("650-253-0000", default_country: "US")

      assert PhoneNumber.to_map(phone) == %{
               "input" => "650-253-0000",
               "defaultCountry" => "US"
             }
    end
  end

  describe "Output.from_map/1" do
    test "parses full phone number response" do
      map = %{
        "input" => "+1 650-253-0000",
        "countryCode" => 1,
        "defaultCountry" => "US",
        "internationalFormatted" => "+1 650-253-0000",
        "national" => 6_502_530_000,
        "nationalFormatted" => "(650) 253-0000",
        "valid" => true
      }

      output = PhoneNumber.Output.from_map(map)
      assert output.input == "+1 650-253-0000"
      assert output.country_code == 1
      assert output.default_country == "US"
      assert output.international_formatted == "+1 650-253-0000"
      assert output.national == 6_502_530_000
      assert output.national_formatted == "(650) 253-0000"
      assert output.valid == true
    end

    test "parses partial phone number response" do
      map = %{
        "input" => "invalid",
        "valid" => false
      }

      output = PhoneNumber.Output.from_map(map)
      assert output.input == "invalid"
      assert output.valid == false
      assert output.country_code == nil
    end
  end

  describe "from_map/1" do
    test "delegates to Output.from_map" do
      map = %{"input" => "+1 650-253-0000", "valid" => true}
      output = PhoneNumber.from_map(map)
      assert output.input == "+1 650-253-0000"
    end
  end
end
