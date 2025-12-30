defmodule WeaviateEx.API.MultiVector.EncodingTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.MultiVector.Encoding

  describe "muvera/1" do
    test "creates muvera encoding with defaults" do
      encoding = Encoding.muvera()

      assert encoding.type == :muvera
      assert encoding.ksim == 10
      assert encoding.dprojections == 256
      assert encoding.repetitions == 4
    end

    test "accepts custom ksim" do
      encoding = Encoding.muvera(ksim: 15)

      assert encoding.ksim == 15
    end

    test "accepts custom dprojections" do
      encoding = Encoding.muvera(dprojections: 512)

      assert encoding.dprojections == 512
    end

    test "accepts custom repetitions" do
      encoding = Encoding.muvera(repetitions: 8)

      assert encoding.repetitions == 8
    end

    test "accepts all custom options" do
      encoding = Encoding.muvera(ksim: 20, dprojections: 1024, repetitions: 16)

      assert encoding.type == :muvera
      assert encoding.ksim == 20
      assert encoding.dprojections == 1024
      assert encoding.repetitions == 16
    end
  end

  describe "none/0" do
    test "creates none encoding" do
      encoding = Encoding.none()

      assert encoding.type == :none
      assert is_nil(encoding.ksim)
      assert is_nil(encoding.dprojections)
      assert is_nil(encoding.repetitions)
    end
  end

  describe "to_api/1" do
    test "converts muvera to API format" do
      encoding = Encoding.muvera(ksim: 15, dprojections: 512, repetitions: 8)
      result = Encoding.to_api(encoding)

      assert result == %{
               "type" => "muvera",
               "ksim" => 15,
               "dProjections" => 512,
               "repetitions" => 8
             }
    end

    test "converts none to API format" do
      encoding = Encoding.none()
      result = Encoding.to_api(encoding)

      assert result == %{"type" => "none"}
    end
  end

  describe "from_api/1" do
    test "parses muvera from API response" do
      api_data = %{
        "type" => "muvera",
        "ksim" => 10,
        "dProjections" => 256,
        "repetitions" => 4
      }

      encoding = Encoding.from_api(api_data)

      assert encoding.type == :muvera
      assert encoding.ksim == 10
      assert encoding.dprojections == 256
      assert encoding.repetitions == 4
    end

    test "parses none from API response" do
      api_data = %{"type" => "none"}

      encoding = Encoding.from_api(api_data)

      assert encoding.type == :none
    end

    test "returns nil for nil input" do
      assert is_nil(Encoding.from_api(nil))
    end
  end
end
