defmodule CookieCloudServer.Repo do
  use Ecto.Repo,
    otp_app: :cookie_cloud_server,
    adapter: Ecto.Adapters.SQLite3
end
