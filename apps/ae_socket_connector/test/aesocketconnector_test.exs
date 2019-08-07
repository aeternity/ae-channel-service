defmodule SocketConnectorTest do
  use ExUnit.Case
  doctest SocketConnector

  test "greets the world" do
    assert SocketConnector.hello() == :world
  end
end
