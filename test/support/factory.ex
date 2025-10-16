defmodule WeaviateEx.Test.Factory do
  @moduledoc """
  Factory for generating test data.
  """

  def build(type, attrs \\ [])

  def build(:collection, attrs) do
    %{
      "class" => Keyword.get(attrs, :name, "TestCollection_#{unique_id()}"),
      "vectorizer" => Keyword.get(attrs, :vectorizer, "text2vec-openai"),
      "properties" =>
        Keyword.get(attrs, :properties, [
          build(:property, name: "title", data_type: ["text"])
        ])
    }
  end

  def build(:property, attrs) do
    %{
      "name" => Keyword.get(attrs, :name, "field_#{unique_id()}"),
      "dataType" => Keyword.get(attrs, :data_type, ["text"]),
      "tokenization" => Keyword.get(attrs, :tokenization, "word")
    }
  end

  def build(:object, attrs) do
    %{
      "class" => Keyword.get(attrs, :class, "TestClass"),
      "properties" =>
        Keyword.get(attrs, :properties, %{
          "title" => "Test Title"
        }),
      "id" => Keyword.get(attrs, :id, UUID.uuid4())
    }
  end

  def build_list(type, count, attrs \\ []) do
    Enum.map(1..count, fn _ -> build(type, attrs) end)
  end

  defp unique_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
