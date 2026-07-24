ExUnit.start()

# Ensure test DB schema is up; Migrator also runs on app start
path = Application.app_dir(:cookie_cloud_server, "priv/repo/migrations")
Ecto.Migrator.run(CookieCloudServer.Repo, path, :up, all: true)
