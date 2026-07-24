defmodule CookieCloudServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    CookieCloudServer.Plugs.RateLimit.setup!()

    children =
      [
        CookieCloudServer.Repo,
        # Automatically run database migration (blocks until completion)
        CookieCloudServer.Migrator
      ] ++ http_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CookieCloudServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_children do
    port = Application.get_env(:cookie_cloud_server, CookieCloudServer.Router)[:port] || 4000

    # port 0 means "do not start HTTP server" (used in tests with Plug.Test)
    if port > 0 do
      [{Bandit, plug: CookieCloudServer.Router, port: port}]
    else
      []
    end
  end
end
