if File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Enum.each(fn line ->
    line =
      if String.starts_with?(line, "export ") do
        String.replace_prefix(line, "export ", "")
      else
        line
      end

    case String.split(line, "=", parts: 2) do
      [key, value] -> System.put_env(String.trim(key), String.trim(value))
      _ -> :ok
    end
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
