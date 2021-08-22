defmodule DleEnvTest do
  use ExUnit.Case
  doctest DleEnv

  test "greets the world" do
    assert DleEnv.hello() == :world
  end
end
