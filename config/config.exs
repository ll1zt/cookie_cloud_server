import Config

config :cookie_cloud_server,
  ecto_repos: [CookieCloudServer.Repo]

config :cookie_cloud_server, CookieCloudServer.Repo,
  database: "data/cookie_cloud_server.db",
  default_transaction_mode: :immediate,
  journal_mode: :wal,
  pool_size: 5

config :logger, :console, format: "$time $metadata[$level] $message\n"
