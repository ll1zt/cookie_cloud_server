defmodule CookieCloudServer.Plugs.Cors do
  @moduledoc """
  Minimal CORS support for browser clients.
  """

  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "OPTIONS"} = conn, _opts) do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
    |> halt()
  end

  def call(conn, _opts) do
    put_cors_headers(conn)
  end

  defp put_cors_headers(conn) do
    origins = Application.get_env(:cookie_cloud_server, :cors_origins, "*")

    conn
    |> put_resp_header("access-control-allow-origin", origins)
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> put_resp_header(
      "access-control-allow-headers",
      "authorization, content-type, content-encoding"
    )
    |> put_resp_header("access-control-max-age", "86400")
  end
end
