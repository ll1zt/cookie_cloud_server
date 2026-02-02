defmodule CookieCloudServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:cookie_cloud_server, CookieCloudServer.Router)[:port] || 4000

    children = [
      CookieCloudServer.Repo,
      # Automatically run database migration (blocks until completion)
      CookieCloudServer.Migrator,
      {Bandit, plug: CookieCloudServer.Router, port: port}
      # Starts a worker by calling: CookieCloudServer.Worker.start_link(arg)
      # {CookieCloudServer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CookieCloudServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
