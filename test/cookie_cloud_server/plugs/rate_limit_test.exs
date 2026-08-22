defmodule CookieCloudServer.Plugs.RateLimitTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias CookieCloudServer.Plugs.RateLimit.Sweeper

  @table :cookie_cloud_rate_limit

  setup do
    :ets.delete_all_objects(@table)

    on_exit(fn ->
      :ets.delete_all_objects(@table)
      Application.put_env(:cookie_cloud_server, :rate_limit_max, 0)
      Application.put_env(:cookie_cloud_server, :rate_limit_window_ms, 900_000)
    end)

    :ok
  end

  test "sweep_expired deletes finished windows and keeps the current one" do
    Application.put_env(:cookie_cloud_server, :rate_limit_window_ms, 1_000)

    current_window = div(System.system_time(:millisecond), 1_000)
    :ets.insert(@table, {{"1.2.3.4", current_window - 1}, 5})
    :ets.insert(@table, {{"5.6.7.8", current_window - 2}, 3})
    :ets.insert(@table, {{"9.9.9.9", current_window}, 1})

    assert Sweeper.sweep_expired() == 2

    assert :ets.lookup(@table, {"1.2.3.4", current_window - 1}) == []
    assert :ets.lookup(@table, {"5.6.7.8", current_window - 2}) == []
    assert :ets.lookup(@table, {"9.9.9.9", current_window}) != []
  end
end
