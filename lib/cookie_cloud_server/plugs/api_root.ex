defmodule CookieCloudServer.Plugs.ApiRoot do
  @moduledoc """
  Strip configured API_ROOT prefix from request path (CookieCloud compatible).
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    root = api_root()

    if root == "" do
      conn
    else
      path = conn.request_path || "/"

      cond do
        path == root or path == root <> "/" ->
          rewrite(conn, "/")

        String.starts_with?(path, root <> "/") ->
          rewrite(conn, String.replace_prefix(path, root, ""))

        true ->
          conn
      end
    end
  end

  defp rewrite(conn, path) do
    path_info = Plug.Router.Utils.split(path)

    %{
      conn
      | request_path: path,
        path_info: path_info,
        script_name: conn.script_name
    }
  end

  defp api_root do
    Application.get_env(:cookie_cloud_server, :api_root, "")
    |> to_string()
    |> String.trim()
    |> String.trim_trailing("/")
  end
end
