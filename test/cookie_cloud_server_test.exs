defmodule CookieCloudServerTest do
  use ExUnit.Case
  doctest CookieCloudServer

  test "greets the world" do
    assert CookieCloudServer.hello() == :world
  end
end
