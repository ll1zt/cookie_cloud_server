defmodule CookieCloudServer.Reader do
  alias CookieCloudServer.{Repo, Schema.SyncRecord}
  # import Ecto.Query

  def get_all_cookies(uuid) do
    case Repo.get(SyncRecord, uuid) do
      nil ->
        []

      record ->
        record.data["cookie_data"]
        |> Map.values()
        |> List.flatten()
    end
  end

  def get_cookies_by_domain(uuid, domain_suffix) do
    get_all_cookies(uuid)
    |> Enum.filter(fn cookie ->
      String.ends_with?(cookie["domain"], domain_suffix)
    end)
  end
end
