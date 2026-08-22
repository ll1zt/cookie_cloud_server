defmodule CookieCloudServer.Redact do
  @moduledoc """
  Privacy-safe views over decrypted CookieCloud payloads, aimed at AI
  agents and humans inspecting sync state.

  Structure and metadata are preserved (`name`, `domain`, `path`, flags,
  local storage key names) while secret material is masked: cookie values
  become asterisks and local storage values are dropped entirely.
  """

  alias CookieCloudServer.Reader

  # Fields safe to expose verbatim; everything else (notably `value`) is dropped.
  @cookie_safe_fields [
    "name",
    "domain",
    "path",
    "secure",
    "httpOnly",
    "sameSite",
    "session",
    "hostOnly",
    "expirationDate"
  ]

  @mask_char "*"
  # Cap the mask length so exact value lengths are not leaked either.
  @max_mask_length 8

  @doc """
  Masked cookie list for an already-filtered cookie list.

  `value` becomes `"*"` repeated up to #{@max_mask_length} chars (empty stays
  empty); all fields outside the safe metadata set are removed.
  """
  def masked_cookies(cookies) when is_list(cookies) do
    Enum.map(cookies, fn cookie ->
      cookie
      |> Map.take(@cookie_safe_fields)
      |> Map.put("value", mask(Map.get(cookie, "value")))
    end)
  end

  def masked_cookies(_), do: []

  @doc """
  Local storage data reduced to buckets of key names (sorted); values are
  never included. Buckets are filtered by domain like cookie buckets.
  """
  def local_storage_keys(data, domain_filter \\ nil)

  def local_storage_keys(%{"local_storage_data" => ls}, domain_filter) when is_map(ls) do
    ls
    |> Enum.filter(fn {bucket, _} ->
      is_nil(domain_filter) or Reader.bucket_match?(bucket, domain_filter)
    end)
    |> Map.new(fn {bucket, kv} ->
      keys = if is_map(kv), do: kv |> Map.keys() |> Enum.sort(), else: []
      {bucket, keys}
    end)
  end

  def local_storage_keys(_, _), do: %{}

  defp mask(nil), do: nil

  defp mask(""), do: ""

  defp mask(value) when is_binary(value) do
    @mask_char
    |> String.duplicate(min(String.length(value), @max_mask_length))
  end

  defp mask(value), do: mask(to_string(value))
end
