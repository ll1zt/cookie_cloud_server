import Config

config :cookie_cloud_server, CookieCloudServer.Repo,
  database: "data/cookie_cloud_server_test.db",
  pool_size: 1

# Don't bind a real HTTP port during tests; tests use Plug.Test
config :cookie_cloud_server, CookieCloudServer.Router, port: 0

config :cookie_cloud_server, :sync_password, "test-server-password"
config :cookie_cloud_server, :api_root, ""
config :cookie_cloud_server, :cors_origins, "*"
# Disable rate limiting in tests by default
config :cookie_cloud_server, :rate_limit_max, 0
config :cookie_cloud_server, :rate_limit_window_ms, 900_000

config :logger, level: :warning
