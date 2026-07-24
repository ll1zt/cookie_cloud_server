defmodule CookieCloudServer.Router do
  use Plug.Router

  alias CookieCloudServer.{Auth, Reader, Sync, Adapters.Netscape}

  @body_length 50_000_000

  plug(:fetch_query_params)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: @body_length,
    body_reader: {CookieCloudServer.GzipBodyReader, :read_body, []}
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hello from cookiecloud!")
  end

  post "/update" do
    uuid = param(conn, "uuid")
    encrypted = param(conn, "encrypted")
    crypto_type = param(conn, "crypto_type") || "legacy"

    case Sync.put_encrypted(uuid, encrypted, crypto_type, Auth.server_password()) do
      {:ok, _record} ->
        render_json(conn, 200, %{action: "done"})

      {:error, %Ecto.Changeset{}} ->
        render_json(conn, 500, %{action: "error", error: "Database error"})

      {:error, :invalid_uuid} ->
        send_resp(conn, 400, "Bad Request")

      {:error, :invalid_encrypted} ->
        send_resp(conn, 400, "Bad Request")

      {:error, :unknown_type} ->
        send_resp(conn, 400, "Bad Request")

      {:error, _} ->
        render_json(conn, 500, %{action: "error"})
    end
  end

  # Original CookieCloud clients use GET and POST
  get "/get/:uuid" do
    handle_get(conn, uuid)
  end

  post "/get/:uuid" do
    handle_get(conn, uuid)
  end

  match _ do
    send_resp(conn, 404, "Oops! Page not found.")
  end

  defp handle_get(conn, uuid) do
    unless Sync.valid_uuid?(uuid) do
      send_resp(conn, 400, "Bad Request")
    else
      case Sync.get(uuid) do
        nil ->
          send_resp(conn, 404, "Not Found")

        record ->
          cond do
            # Admin path: bearer/query token matches server password
            Auth.admin_authorized?(conn) ->
              handle_admin_get(conn, record)

            # Original path: client password decrypts for this request only
            client_password(conn) ->
              handle_client_decrypt(conn, record, client_password(conn))

            # Default: return ciphertext (official CookieCloud behavior)
            true ->
              case Sync.ciphertext_payload(record) do
                {:ok, payload} ->
                  render_json(conn, 200, payload)

                {:error, :not_found} ->
                  send_resp(conn, 404, "Not Found")
              end
          end
      end
    end
  end

  defp handle_client_decrypt(conn, record, password) do
    crypto_type = conn.query_params["crypto_type"]

    case Sync.decrypt_with_password(record, password, crypto_type) do
      {:ok, data} ->
        render_json(conn, 200, data)

      {:error, _} ->
        render_json(conn, 400, %{error: "Decrypt failed"})
    end
  end

  defp handle_admin_get(conn, record) do
    case Sync.decrypt_for_admin(record, Auth.server_password()) do
      {:ok, data} ->
        domain_filter = conn.query_params["domain"]
        format = Map.get(conn.query_params, "format", "raw")

        case format do
          "netscape" ->
            cookies = Reader.cookies_from_data(data, domain_filter)
            text = Netscape.dump_string(cookies)

            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(200, text)

          "full" ->
            render_json(conn, 200, data)

          "raw" ->
            cookies = Reader.cookies_from_data(data, domain_filter)
            render_json(conn, 200, cookies)

          _ ->
            send_resp(conn, 400, "Unknown format. Supported: raw, full, netscape")
        end

      {:error, :no_plaintext} ->
        render_json(conn, 409, %{
          error: "No plaintext cache and server cannot decrypt. Re-sync or provide password."
        })

      {:error, _} ->
        render_json(conn, 400, %{error: "Decrypt failed"})
    end
  end

  defp client_password(conn) do
    body_pw = param(conn, "password")
    query_pw = conn.query_params["password"]

    cond do
      is_binary(body_pw) and body_pw != "" -> body_pw
      is_binary(query_pw) and query_pw != "" -> query_pw
      true -> nil
    end
  end

  # Support JSON, urlencoded and multipart field names
  defp param(conn, key) do
    Map.get(conn.body_params, key) || Map.get(conn.params, key)
  end

  defp render_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
