defmodule CookieCloudServer.Reader do
  @moduledoc """
  Read helpers over decrypted CookieCloud payload maps.

  CookieCloud stores cookies as `cookie_data` keyed by domain / host bucket
  (e.g. `"bilibili.com" => [cookie, ...]`). RSSHub and similar tools usually
  want one bucket filtered by domain then rendered as a Cookie header string.
  """

  def cookies_from_data(data, domain_filter \\ nil)

  def cookies_from_data(%{"cookie_data" => cookie_data}, domain_filter)
      when is_map(cookie_data) do
    cookies =
      cookie_data
      |> filter_buckets(domain_filter)
      |> Enum.flat_map(fn
        {_bucket, list} when is_list(list) -> list
        list when is_list(list) -> list
        _ -> []
      end)
      |> Enum.filter(&is_map/1)

    filter_cookie_domains(cookies, domain_filter)
  end

  def cookies_from_data(_, _), do: []

  @doc """
  Return cookie_data buckets matching domain filter (for multi-site env export).
  """
  def buckets_from_data(data, domain_filter \\ nil)

  def buckets_from_data(%{"cookie_data" => cookie_data}, domain_filter)
      when is_map(cookie_data) do
    cookie_data
    |> filter_buckets(domain_filter)
    |> Map.new()
  end

  def buckets_from_data(_, _), do: %{}

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

  defp filter_buckets(cookie_data, nil), do: Map.to_list(cookie_data)
  defp filter_buckets(cookie_data, ""), do: Map.to_list(cookie_data)

  defp filter_buckets(cookie_data, domain_filter) when is_binary(domain_filter) do
    needle = normalize_domain(domain_filter)

    cookie_data
    |> Enum.filter(fn {bucket, cookies} ->
      bucket_match?(bucket, needle) or cookies_match_domain?(cookies, needle)
    end)
  end

  defp bucket_match?(bucket, needle) when is_binary(bucket) do
    b = normalize_domain(bucket)
    b == needle or String.ends_with?(b, "." <> needle) or String.ends_with?(needle, "." <> b)
  end

  defp bucket_match?(_, _), do: false

  defp cookies_match_domain?(cookies, needle) when is_list(cookies) do
    Enum.any?(cookies, fn cookie ->
      domain = normalize_domain(cookie["domain"] || cookie[:domain] || "")

      domain != "" and
        (domain == needle or String.ends_with?(domain, needle) or
           String.ends_with?(domain, "." <> needle))
    end)
  end

  defp cookies_match_domain?(_, _), do: false

  defp filter_cookie_domains(cookies, nil), do: cookies
  defp filter_cookie_domains(cookies, ""), do: cookies

  defp filter_cookie_domains(cookies, domain_filter) when is_binary(domain_filter) do
    needle = normalize_domain(domain_filter)

    Enum.filter(cookies, fn cookie ->
      domain = normalize_domain(cookie["domain"] || cookie[:domain] || "")
      # Keep cookies with empty domain if bucket already matched filter
      domain == "" or domain == needle or String.ends_with?(domain, needle) or
        String.ends_with?(domain, "." <> needle)
    end)
  end

  defp normalize_domain(domain) when is_binary(domain) do
    domain
    |> String.trim()
    |> String.downcase()
    |> String.trim_leading(".")
  end

  defp normalize_domain(_), do: ""
end
