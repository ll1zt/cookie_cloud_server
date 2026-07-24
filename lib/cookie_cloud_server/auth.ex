defmodule CookieCloudServer.Auth do
  @moduledoc """
  Authentication helpers for admin token verification.
  """

  @doc """
  Extract bearer token or query `token` from conn.
  """
  def provided_token(conn) do
    token_in_header =
      case Plug.Conn.get_req_header(conn, "authorization") do
        ["Bearer " <> t] -> t
        _ -> nil
      end

    token_in_query = conn.query_params["token"]
    token_in_header || token_in_query
  end

  @doc """
  Verify admin token against configured server password.
  Returns false when password is not configured.
  """
  def admin_authorized?(conn) do
    case Application.get_env(:cookie_cloud_server, :sync_password) do
      password when is_binary(password) and password != "" ->
        case provided_token(conn) do
          nil -> false
          token -> secure_compare(token, password)
        end

      _ ->
        false
    end
  end

  def server_password do
    case Application.get_env(:cookie_cloud_server, :sync_password) do
      password when is_binary(password) and password != "" -> password
      _ -> nil
    end
  end

  # Constant-time-ish compare for equal-length binaries; falls back safely otherwise.
  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    if byte_size(a) == byte_size(b) do
      Plug.Crypto.secure_compare(a, b)
    else
      false
    end
  end

  defp secure_compare(_, _), do: false
end
