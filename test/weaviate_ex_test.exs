defmodule WeaviateExTest do
  use ExUnit.Case
  doctest WeaviateEx

  test "greets the world" do
    assert WeaviateEx.hello() == :world
  end
end
