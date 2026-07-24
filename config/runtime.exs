import Config

# Server password is optional.
# - When set: enables decrypt-cache on /update and admin Bearer export on /get
# - When unset: pure ciphertext store mode (official CookieCloud compatible)
password = System.get_env("COOKIE_CLOUD_SERVER_PASSWORD")
config :cookie_cloud_server, :sync_password, password

port = String.to_integer(System.get_env("PORT") || "4000")
config :cookie_cloud_server, CookieCloudServer.Router, port: port

database_path = System.get_env("DATABASE_PATH") || "data/cookie_cloud_server.db"

if config_env() != :test do
  database_path |> Path.dirname() |> File.mkdir_p!()
end

config :cookie_cloud_server, CookieCloudServer.Repo, database: database_path
