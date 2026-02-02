import Config

password =
  System.get_env("COOKIE_CLOUD_SERVER_PASSWORD") ||
    raise "COOKIE_CLOUD_SERVER_PASSWORD is missing. Please export it in your shell or .env"

config :cookie_cloud_server, :sync_password, password

port = String.to_integer(System.get_env("PORT") || "4000")
config :cookie_cloud_server, CookieCloudServer.Router, port: port

database_path = System.get_env("DATABASE_PATH") || "data/cookie_cloud_server.db"

if config_env() != :test do
  database_path |> Path.dirname() |> File.mkdir_p!()
end

config :cookie_cloud_server, CookieCloudServer.Repo, database: database_path
