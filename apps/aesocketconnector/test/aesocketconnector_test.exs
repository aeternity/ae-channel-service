defmodule AeSocketConnectorTest do
  use ExUnit.Case
  doctest AeSocketConnector

  test "greets the world" do
    assert AeSocketConnector.hello() == :world
  end
end
