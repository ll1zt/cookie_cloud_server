defmodule CookieCloudServer.Reader do
  @moduledoc """
  Read helpers over decrypted CookieCloud payload maps.
  """

  def cookies_from_data(data, domain_filter \\ nil)

  def cookies_from_data(%{"cookie_data" => cookie_data}, domain_filter)
      when is_map(cookie_data) do
    cookies =
      cookie_data
      |> Map.values()
      |> List.flatten()

    if domain_filter do
      Enum.filter(cookies, fn cookie ->
        domain = cookie["domain"] || ""
        String.ends_with?(domain, domain_filter)
      end)
    else
      cookies
    end
  end

  def cookies_from_data(_, _), do: []

  # Backward-compatible helpers used by older call sites
  def get_all_cookies(uuid) do
    case CookieCloudServer.Sync.get(uuid) do
      nil -> []
      record -> cookies_from_data(record.data)
    end
  end

  def get_cookies_by_domain(uuid, domain_suffix) do
    case CookieCloudServer.Sync.get(uuid) do
      nil -> []
      record -> cookies_from_data(record.data, domain_suffix)
    end
  end
end
