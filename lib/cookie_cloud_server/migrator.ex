defmodule CookieCloudServer.Migrator do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Synchronous Migration
    path = Application.app_dir(:cookie_cloud_server, "priv/repo/migrations")
    Ecto.Migrator.run(CookieCloudServer.Repo, path, :up, all: true)
    
    {:ok, nil}
  end
end
