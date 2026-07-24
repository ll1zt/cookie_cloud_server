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
end
