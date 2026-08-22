import Config

# Test config is fully owned by config/test.exs — do not override from env.
if config_env() != :test do
  password = System.get_env("COOKIE_CLOUD_SERVER_PASSWORD")
  config :cookie_cloud_server, :sync_password, password

  port = String.to_integer(System.get_env("PORT") || "4000")
  config :cookie_cloud_server, CookieCloudServer.Router, port: port

  database_path = System.get_env("DATABASE_PATH") || "data/cookie_cloud_server.db"
  database_path |> Path.dirname() |> File.mkdir_p!()
  config :cookie_cloud_server, CookieCloudServer.Repo, database: database_path

  api_root =
    System.get_env("API_ROOT", "")
    |> String.trim()
    |> String.trim_trailing("/")

  config :cookie_cloud_server, :api_root, api_root

  cors_origins = System.get_env("CORS_ORIGINS") || "*"
  config :cookie_cloud_server, :cors_origins, cors_origins

  # Set to true only when running behind a trusted reverse proxy that strips
  # or overwrites X-Forwarded-For; otherwise clients can spoof their IP.
  trust_proxy = System.get_env("TRUST_PROXY", "false") in ["1", "true", "yes"]
  config :cookie_cloud_server, :trust_proxy, trust_proxy

  rate_limit_max = String.to_integer(System.get_env("RATE_LIMIT_MAX") || "100")
  rate_limit_window_ms = String.to_integer(System.get_env("RATE_LIMIT_WINDOW_MS") || "900000")
  config :cookie_cloud_server, :rate_limit_max, rate_limit_max
  config :cookie_cloud_server, :rate_limit_window_ms, rate_limit_window_ms

  sweep_interval_ms =
    String.to_integer(
      System.get_env("RATE_LIMIT_SWEEP_INTERVAL_MS") || Integer.to_string(rate_limit_window_ms)
    )

  config :cookie_cloud_server, :rate_limit_sweep_interval_ms, sweep_interval_ms
end

config :cookie_cloud_server, :started_at_ms, System.system_time(:millisecond)
