defmodule ElircTest do
  use ExUnit.Case
  doctest Elirc

  test "greets the world" do
    assert Elirc.hello() == :world
  end
end
