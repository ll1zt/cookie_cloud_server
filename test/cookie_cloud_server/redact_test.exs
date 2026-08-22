defmodule CookieCloudServer.RedactTest do
  use ExUnit.Case, async: true

  alias CookieCloudServer.Redact

  test "masked_cookies masks values and keeps safe metadata only" do
    cookie = %{
      "name" => "SESSDATA",
      "value" => "super-secret-token",
      "domain" => ".deepseek.com",
      "path" => "/",
      "secure" => true,
      "httpOnly" => true,
      "expirationDate" => 1_800_000_000,
      "storeId" => "0"
    }

    masked = Redact.masked_cookies([cookie]) |> hd()

    assert masked["name"] == "SESSDATA"
    assert masked["domain"] == ".deepseek.com"
    assert masked["secure"] == true
    assert masked["value"] == "********"
    # length capped, exact length not leaked
    assert String.length(masked["value"]) == 8
    # unsafe fields dropped
    refute Map.has_key?(masked, "storeId")
  end

  test "masked_cookies keeps short values fully masked and empty values empty" do
    masked =
      Redact.masked_cookies([
        %{"name" => "a", "value" => "abc"},
        %{"name" => "b", "value" => ""},
        %{"name" => "c"}
      ])

    assert Enum.map(masked, & &1["value"]) == ["***", "", nil]
  end

  test "local_storage_keys reduces buckets to sorted key names" do
    data = %{
      "local_storage_data" => %{
        "LS-chat.deepseek.com" => %{"userToken" => "secret", "theme" => "dark"},
        "LS-example.com" => "not-a-map"
      }
    }

    assert Redact.local_storage_keys(data) == %{
             "LS-chat.deepseek.com" => ["theme", "userToken"],
             "LS-example.com" => []
           }
  end

  test "local_storage_keys honours the domain filter" do
    data = %{
      "local_storage_data" => %{
        "LS-chat.deepseek.com" => %{"userToken" => "secret"},
        "LS-example.com" => %{"a" => "b"}
      }
    }

    assert Redact.local_storage_keys(data, "deepseek.com") == %{
             "LS-chat.deepseek.com" => ["userToken"]
           }
  end

  test "handles missing local_storage_data" do
    assert Redact.local_storage_keys(%{}) == %{}
  end
end
