import Config

config :cookie_cloud_server, CookieCloudServer.Repo,
  database: "data/cookie_cloud_server_test.db",
  pool_size: 1

# Don't bind a real HTTP port during tests; tests use Plug.Test
config :cookie_cloud_server, CookieCloudServer.Router, port: 0

config :cookie_cloud_server, :sync_password, "test-server-password"

config :logger, level: :warning
