defmodule SuperColliderTest do
  use ExUnit.Case
  doctest SuperCollider

  test "greets the world" do
    assert SuperCollider.hello() == :world
  end
end
