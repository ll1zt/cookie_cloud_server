defmodule CookieCloudServer.Plugs.RateLimit do
  @moduledoc """
  Simple per-IP fixed-window rate limiter using ETS.
  """

  @behaviour Plug
  import Plug.Conn

  @table :cookie_cloud_rate_limit

  @impl true
  def init(opts), do: opts

  @doc "Create ETS table (called from Application)."
  def setup! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

      _ ->
        @table
    end
  end

  @impl true
  def call(conn, _opts) do
    max = Application.get_env(:cookie_cloud_server, :rate_limit_max, 100)
    window_ms = Application.get_env(:cookie_cloud_server, :rate_limit_window_ms, 15 * 60 * 1000)

    if max <= 0 do
      conn
    else
      ip = client_ip(conn)
      now = System.system_time(:millisecond)
      window = div(now, window_ms)
      key = {ip, window}

      count =
        case :ets.update_counter(@table, key, {2, 1}, {key, 0}) do
          n when is_integer(n) -> n
        end

      # Opportunistic cleanup of old windows for this IP is skipped for simplicity.
      if count > max do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Too Many Requests"}))
        |> halt()
      else
        conn
      end
    end
  rescue
    ArgumentError ->
      # Table missing (e.g. early test) — fail open
      conn
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
