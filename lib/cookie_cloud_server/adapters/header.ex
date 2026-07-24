defmodule CookieCloudServer.Adapters.Header do
  @moduledoc """
  Export cookies as an HTTP Cookie header string for tools like RSSHub.

  Output shape: `name1=value1; name2=value2`
  """

  @doc """
  Build `name=value` pairs joined by `"; "`.

  Later cookies with the same name overwrite earlier ones (browser-like).
  Empty names are skipped.
  """
  def dump_string(cookies) when is_list(cookies) do
    cookies
    |> Enum.reduce(%{}, fn cookie, acc ->
      name = Map.get(cookie, "name") || Map.get(cookie, :name)
      value = Map.get(cookie, "value") || Map.get(cookie, :value) || ""

      if is_binary(name) and name != "" do
        Map.put(acc, name, to_string(value))
      else
        acc
      end
    end)
    |> Enum.map(fn {name, value} -> "#{name}=#{value}" end)
    |> Enum.join("; ")
  end

  def dump_string(_), do: ""

  @doc """
  Build a single env file line: `ENV_NAME=name=value; ...`

  Suitable for RSSHub `secretFiles` / dotenv style loading.
  """
  def dump_env_line(cookies, env_name) when is_binary(env_name) and env_name != "" do
    "#{env_name}=#{dump_string(cookies)}"
  end

  def dump_env_line(cookies, _), do: dump_string(cookies)
end
