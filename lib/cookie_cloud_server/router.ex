defmodule CookieCloudServer.Router do
  alias CookieCloudServer.{Repo, Schema.SyncRecord, Crypto, Reader, Adapters.Netscape}
  use Plug.Router

  # plug(:auth)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    body_reader: {CookieCloudServer.GzipBodyReader, :read_body, []}
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hello from cookiecloud!")
  end

  post "/update" do
    uuid = conn.body_params["uuid"]
    password = Application.fetch_env!(:cookie_cloud_server, :sync_password)
    encrypted = conn.body_params["encrypted"]

    crypto_type = Map.get(conn.body_params, "crypto_type", "legacy")

    if is_nil(encrypted) or is_nil(uuid) or encrypted == "" or uuid == "" do
      send_resp(conn, 400, "Bad Request")
    else
      if is_nil(password) do
        render_json(conn, 500, %{error: "Server configuration error: password missing"})
      else
        decrypted_data =
          Crypto.cookie_decrypt(
            uuid,
            encrypted,
            password,
            crypto_type
          )

        update_time_str = decrypted_data["update_time"]

        client_time =
          case DateTime.from_iso8601(update_time_str) do
            {:ok, dt, _offset} ->
              DateTime.to_naive(dt)

            {:error, _reason} ->
              NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          end

        params = %{
          uuid: uuid,
          data: decrypted_data,
          client_updated_at: client_time
        }

        result =
          %SyncRecord{}
          |> SyncRecord.changeset(params)
          |> Repo.insert(
            on_conflict: :replace_all,
            conflict_target: :uuid
          )

        case result do
          {:ok, _struct} ->
            render_json(conn, 200, %{action: "done"})

          {:error, _changeset} ->
            render_json(conn, 500, %{error: "Database error"})
        end
      end
    end
  end

  defp render_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  get "/get/:uuid" do
    if verify_token(conn) do
      domain_filter = conn.query_params["domain"]
      format = Map.get(conn.query_params, "format", "raw")

      raw_cookies =
        if domain_filter do
          Reader.get_cookies_by_domain(uuid, domain_filter)
        else
          Reader.get_all_cookies(uuid)
        end

      case format do
        # TODO
        # "playwright" ->
        #   data = Playwright.transform(raw_cookies)
        #   render_json(conn, 200, data)

        "netscape" ->
          text = Netscape.dump_string(raw_cookies)

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, text)

        # TODO
        # "header" ->
        #   text = Header.to_header_string(raw_cookies)

        #   conn
        #   |> put_resp_content_type("text/plain")
        #   |> send_resp(200, text)

        "raw" ->
          render_json(conn, 200, raw_cookies)

        _ ->
          send_resp(conn, 400, "Unknown format. Supported: playwright, netscape, header, raw")
      end
    else
      send_resp(conn, 401, "Unauthorized")
    end
  end

  defp verify_token(conn) do
    expected = Application.fetch_env!(:cookie_cloud_server, :sync_password)

    token_in_header =
      case Plug.Conn.get_req_header(conn, "authorization") do
        ["Bearer " <> t] -> t
        _ -> nil
      end

    token_in_query = conn.query_params["token"]

    provided_token = token_in_header || token_in_query

    provided_token == expected
  end

  match _ do
    send_resp(conn, 404, "Oops! Page not found.")
  end
end
