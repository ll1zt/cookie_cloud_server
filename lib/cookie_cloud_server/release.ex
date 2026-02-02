defmodule CookieCloudServer.Release do
  @moduledoc """
  Responsible for performing database migrations during release startup.
  """
  use Task

  def start_link(_arg) do
    Task.start_link(fn ->
      migrate()
    end)
  end

  def migrate do
    Application.load(:cookie_cloud_server)
    
    path = Application.app_dir(:cookie_cloud_server, "priv/repo/migrations")
    Ecto.Migrator.run(CookieCloudServer.Repo, path, :up, all: true)
  end
end
