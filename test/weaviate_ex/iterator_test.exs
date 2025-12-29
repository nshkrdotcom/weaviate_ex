defmodule WeaviateEx.IteratorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Iterator

  describe "new/3" do
    test "creates iterator with defaults" do
      iterator = Iterator.new(:client, "Article")

      assert iterator.client == :client
      assert iterator.collection == "Article"
      assert iterator.batch_size == 100
      assert iterator.return_properties == []
      assert iterator.include_vector == false
      assert iterator.cursor == nil
    end

    test "accepts custom batch_size" do
      iterator = Iterator.new(:client, "Article", batch_size: 50)

      assert iterator.batch_size == 50
    end

    test "accepts return_properties" do
      iterator = Iterator.new(:client, "Article", return_properties: ["title", "content"])

      assert iterator.return_properties == ["title", "content"]
    end

    test "accepts include_vector" do
      iterator = Iterator.new(:client, "Article", include_vector: true)

      assert iterator.include_vector == true
    end

    test "accepts after cursor" do
      iterator = Iterator.new(:client, "Article", after: "some-uuid")

      assert iterator.cursor == "some-uuid"
    end

    test "accepts filter" do
      filter = %{path: ["status"], operator: "Equal", valueText: "published"}
      iterator = Iterator.new(:client, "Article", filter: filter)

      assert iterator.filter == filter
    end
  end

  describe "build_query/1" do
    test "builds basic query" do
      iterator = Iterator.new(:client, "Article", return_properties: ["title"])
      query = Iterator.build_query(iterator)

      assert query =~ "Article"
      assert query =~ "title"
      assert query =~ "_additional { id }"
    end

    test "includes vector when requested" do
      iterator = Iterator.new(:client, "Article", include_vector: true)
      query = Iterator.build_query(iterator)

      assert query =~ "vector"
    end

    test "includes after cursor" do
      iterator = Iterator.new(:client, "Article", after: "some-uuid")
      query = Iterator.build_query(iterator)

      assert query =~ "after:"
      assert query =~ "some-uuid"
    end

    test "includes limit" do
      iterator = Iterator.new(:client, "Article", batch_size: 50)
      query = Iterator.build_query(iterator)

      assert query =~ "limit: 50"
    end
  end

  describe "with_cursor/2" do
    test "updates cursor" do
      iterator = Iterator.new(:client, "Article")
      iterator = Iterator.with_cursor(iterator, "new-cursor")

      assert iterator.cursor == "new-cursor"
    end
  end
end
