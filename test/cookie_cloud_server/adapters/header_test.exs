defmodule CookieCloudServer.Adapters.HeaderTest do
  use ExUnit.Case, async: true

  alias CookieCloudServer.Adapters.Header

  test "dump_string joins name=value pairs" do
    cookies = [
      %{"name" => "SESSDATA", "value" => "abc"},
      %{"name" => "bili_jct", "value" => "xyz"}
    ]

    assert Header.dump_string(cookies) == "SESSDATA=abc; bili_jct=xyz"
  end

  test "later same-name cookie overwrites earlier" do
    cookies = [
      %{"name" => "a", "value" => "1"},
      %{"name" => "a", "value" => "2"}
    ]

    assert Header.dump_string(cookies) == "a=2"
  end

  test "skips empty names" do
    cookies = [%{"name" => "", "value" => "x"}, %{"name" => "ok", "value" => "1"}]
    assert Header.dump_string(cookies) == "ok=1"
  end

  test "dump_env_line prefixes env name" do
    cookies = [%{"name" => "SESSDATA", "value" => "abc"}]
    assert Header.dump_env_line(cookies, "BILIBILI_COOKIE_1") == "BILIBILI_COOKIE_1=SESSDATA=abc"
  end
end
