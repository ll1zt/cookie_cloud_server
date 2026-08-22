defmodule CookieCloudServer.Plugs.RateLimit do
  @moduledoc """
  Simple per-IP fixed-window rate limiter using ETS.

  Counters are keyed by `{ip, window}`; expired windows are deleted
  periodically by `CookieCloudServer.Plugs.RateLimit.Sweeper`.

  The named table is created by the sweeper, which must be started before the
  HTTP listener (see `CookieCloudServer.Application`) so it exists once
  requests are accepted.
  """

  @behaviour Plug

  import Plug.Conn

  @table :cookie_cloud_rate_limit

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    max = Application.get_env(:cookie_cloud_server, :rate_limit_max, 100)

    if max <= 0 do
      conn
    else
      check_rate(conn, max)
    end
  end

  defp check_rate(conn, max) do
    window_ms =
      Application.get_env(:cookie_cloud_server, :rate_limit_window_ms, 15 * 60 * 1000)

    ip = client_ip(conn)
    window = div(System.system_time(:millisecond), window_ms)
    key = {ip, window}

    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count > max do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(429, Jason.encode!(%{error: "Too Many Requests"}))
      |> halt()
    else
      conn
    end
  end

  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",", parts: 2) |> hd() |> String.trim()

      _ ->
        case conn.remote_ip do
          {a, b, c, d} -> Enum.join([a, b, c, d], ".")
          tuple when is_tuple(tuple) -> tuple |> Tuple.to_list() |> Enum.join(":")
          _ -> "unknown"
        end
    end
  end
end
