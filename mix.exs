if File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.filter(&String.starts_with?(&1, "export "))
  |> Enum.each(fn line ->
    [_, var_string] = String.split(line, "export ", parts: 2)
    [key, value] = String.split(var_string, "=", parts: 2)
    System.put_env(key, value)
  end)
end

defmodule CookieCloudServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :cookie_cloud_server,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CookieCloudServer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:jason, "~> 1.4"},
      {:ecto_sqlite3, "~> 0.17"}
      # {:personal_elixir_utils,
      #  git: "https://github.com/ll1zt/personal_elixir_utils.git", branch: "main"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
