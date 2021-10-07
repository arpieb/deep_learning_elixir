defmodule ExsTestTest do
  use ExUnit.Case
  doctest ExsTest

  test "greets the world" do
    assert ExsTest.hello() == :world
  end
end
