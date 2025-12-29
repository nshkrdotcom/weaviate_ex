defmodule WeaviateEx.Types.DataTypeTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Types.DataType

  describe "to_string/1" do
    test "converts text atom to string" do
      assert DataType.to_string(:text) == "text"
    end

    test "converts text_array atom to string" do
      assert DataType.to_string(:text_array) == "text[]"
    end

    test "converts int atom to string" do
      assert DataType.to_string(:int) == "int"
    end

    test "converts int_array atom to string" do
      assert DataType.to_string(:int_array) == "int[]"
    end

    test "converts boolean atom to string" do
      assert DataType.to_string(:boolean) == "boolean"
    end

    test "converts boolean_array atom to string" do
      assert DataType.to_string(:boolean_array) == "boolean[]"
    end

    test "converts number atom to string" do
      assert DataType.to_string(:number) == "number"
    end

    test "converts number_array atom to string" do
      assert DataType.to_string(:number_array) == "number[]"
    end

    test "converts date atom to string" do
      assert DataType.to_string(:date) == "date"
    end

    test "converts date_array atom to string" do
      assert DataType.to_string(:date_array) == "date[]"
    end

    test "converts uuid atom to string" do
      assert DataType.to_string(:uuid) == "uuid"
    end

    test "converts uuid_array atom to string" do
      assert DataType.to_string(:uuid_array) == "uuid[]"
    end

    test "converts geo_coordinates atom to string" do
      assert DataType.to_string(:geo_coordinates) == "geoCoordinates"
    end

    test "converts blob atom to string" do
      assert DataType.to_string(:blob) == "blob"
    end

    test "converts phone_number atom to string" do
      assert DataType.to_string(:phone_number) == "phoneNumber"
    end

    test "converts object atom to string" do
      assert DataType.to_string(:object) == "object"
    end

    test "converts object_array atom to string" do
      assert DataType.to_string(:object_array) == "object[]"
    end
  end

  describe "from_string/1" do
    test "parses text string to atom" do
      assert DataType.from_string("text") == {:ok, :text}
    end

    test "parses text[] string to atom" do
      assert DataType.from_string("text[]") == {:ok, :text_array}
    end

    test "parses int string to atom" do
      assert DataType.from_string("int") == {:ok, :int}
    end

    test "parses int[] string to atom" do
      assert DataType.from_string("int[]") == {:ok, :int_array}
    end

    test "parses geoCoordinates string to atom" do
      assert DataType.from_string("geoCoordinates") == {:ok, :geo_coordinates}
    end

    test "parses phoneNumber string to atom" do
      assert DataType.from_string("phoneNumber") == {:ok, :phone_number}
    end

    test "parses object string to atom" do
      assert DataType.from_string("object") == {:ok, :object}
    end

    test "returns error for unknown data type" do
      assert {:error, {:unknown_data_type, "unknown"}} = DataType.from_string("unknown")
    end
  end

  describe "all/0" do
    test "returns all supported data types" do
      all_types = DataType.all()

      assert :text in all_types
      assert :int in all_types
      assert :boolean in all_types
      assert :number in all_types
      assert :date in all_types
      assert :uuid in all_types
      assert :geo_coordinates in all_types
      assert :blob in all_types
      assert :phone_number in all_types
      assert :object in all_types
      assert :object_array in all_types
    end
  end

  describe "valid?/1" do
    test "returns true for valid data types" do
      assert DataType.valid?(:text) == true
      assert DataType.valid?(:int) == true
      assert DataType.valid?(:geo_coordinates) == true
    end

    test "returns false for invalid data types" do
      assert DataType.valid?(:invalid) == false
      assert DataType.valid?(:unknown) == false
    end
  end

  describe "array?/1" do
    test "returns true for array types" do
      assert DataType.array?(:text_array) == true
      assert DataType.array?(:int_array) == true
      assert DataType.array?(:object_array) == true
    end

    test "returns false for non-array types" do
      assert DataType.array?(:text) == false
      assert DataType.array?(:int) == false
      assert DataType.array?(:object) == false
    end
  end
end
