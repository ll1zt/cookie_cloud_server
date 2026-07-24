defmodule CookieCloudServer.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias CookieCloudServer.{Repo, Router, Schema.SyncRecord}

  @opts Router.init([])
  @uuid "testuuid01"
  @password "client-password"
  @server_password "test-server-password"

  setup do
    Repo.delete_all(SyncRecord)
    :ok
  end

  test "POST /update stores ciphertext without requiring decrypt" do
    {_plain, encrypted} = build_encrypted(@uuid, @password, %{"cookie_data" => %{"a.com" => []}})

    conn =
      conn(:post, "/update", %{
        "uuid" => @uuid,
        "encrypted" => encrypted,
        "crypto_type" => "aes-128-cbc-fixed"
      })
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"action" => "done"}

    record = Repo.get!(SyncRecord, @uuid)
    assert record.encrypted == encrypted
    assert record.crypto_type == "aes-128-cbc-fixed"
    # server password differs from client password → no plaintext cache
    assert record.data in [nil, %{}] or is_nil(record.data)
  end

  test "POST /update accepts urlencoded body" do
    {_plain, encrypted} = build_encrypted(@uuid, @password, %{"ok" => true})

    conn =
      conn(:post, "/update", %{
        "uuid" => @uuid,
        "encrypted" => encrypted,
        "crypto_type" => "aes-128-cbc-fixed"
      })
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call(@opts)

    assert conn.status == 200
  end

  test "POST /update rejects invalid uuid" do
    conn =
      conn(:post, "/update", %{"uuid" => "../evil", "encrypted" => "abc"})
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 400
  end

  test "GET /get/:uuid returns ciphertext by default" do
    {_plain, encrypted} = build_encrypted(@uuid, @password, %{"x" => 1})
    seed_record(@uuid, encrypted, "aes-128-cbc-fixed")

    conn = conn(:get, "/get/#{@uuid}") |> Router.call(@opts)

    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["encrypted"] == encrypted
    assert body["crypto_type"] == "aes-128-cbc-fixed"
  end

  test "POST /get/:uuid decrypts with client password" do
    plain = %{"cookie_data" => %{"example.com" => [%{"name" => "a", "value" => "1", "domain" => ".example.com"}]}}
    {_p, encrypted} = build_encrypted(@uuid, @password, plain)
    seed_record(@uuid, encrypted, "aes-128-cbc-fixed")

    conn =
      conn(:post, "/get/#{@uuid}", %{"password" => @password})
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["cookie_data"]["example.com"]
  end

  test "GET /get/:uuid with Bearer returns raw cookies when cache exists" do
    plain = %{
      "cookie_data" => %{
        "example.com" => [
          %{"name" => "sid", "value" => "1", "domain" => ".example.com", "path" => "/", "secure" => true}
        ]
      }
    }

    # Encrypt with server password so update cache / admin decrypt works
    {_p, encrypted} = build_encrypted(@uuid, @server_password, plain)

    conn =
      conn(:post, "/update", %{
        "uuid" => @uuid,
        "encrypted" => encrypted,
        "crypto_type" => "aes-128-cbc-fixed"
      })
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 200

    conn =
      conn(:get, "/get/#{@uuid}?format=raw")
      |> put_req_header("authorization", "Bearer #{@server_password}")
      |> Router.call(@opts)

    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert [%{"name" => "sid", "value" => "1"}] = body
  end

  test "GET /get/:uuid returns 404 when missing" do
    conn = conn(:get, "/get/missing01") |> Router.call(@opts)
    assert conn.status == 404
  end

  test "GET / returns greeting" do
    conn = conn(:get, "/") |> Router.call(@opts)
    assert conn.status == 200
    assert conn.resp_body =~ "cookiecloud"
  end

  test "GET /health returns OK json" do
    conn = conn(:get, "/health") |> Router.call(@opts)
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["status"] == "OK"
    assert is_binary(body["timestamp"])
  end

  test "CORS headers are present and OPTIONS is 204" do
    conn = conn(:get, "/") |> Router.call(@opts)
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]

    conn = conn(:options, "/update") |> Router.call(@opts)
    assert conn.status == 204
  end

  test "API_ROOT prefix is stripped" do
    Application.put_env(:cookie_cloud_server, :api_root, "/cookie")
    on_exit(fn -> Application.put_env(:cookie_cloud_server, :api_root, "") end)

    conn = conn(:get, "/cookie/health") |> Router.call(@opts)
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body)["status"] == "OK"
  end

  defp seed_record(uuid, encrypted, crypto_type) do
    %SyncRecord{}
    |> SyncRecord.changeset(%{
      uuid: uuid,
      encrypted: encrypted,
      crypto_type: crypto_type
    })
    |> Repo.insert!()
  end

  defp build_encrypted(uuid, password, map) do
    passphrase =
      :crypto.hash(:md5, "#{uuid}-#{password}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    plaintext = Jason.encode!(map)
    pad_len = 16 - rem(byte_size(plaintext), 16)
    padded = plaintext <> :binary.copy(<<pad_len>>, pad_len)
    iv = <<0::size(128)>>
    ciphertext = :crypto.crypto_one_time(:aes_128_cbc, passphrase, iv, padded, true)
    {map, Base.encode64(ciphertext)}
  end
end
