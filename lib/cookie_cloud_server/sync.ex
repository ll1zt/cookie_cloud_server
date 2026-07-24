defmodule CookieCloudServer.Sync do
  @moduledoc """
  Business logic for CookieCloud sync records.

  Ciphertext is the source of truth. Decrypted `data` is an optional cache
  used by admin export features when a server password is configured.
  """

  alias CookieCloudServer.{Crypto, Repo, Schema.SyncRecord}

  @uuid_re ~r/^[A-Za-z0-9_-]{8,128}$/

  @doc """
  Upsert ciphertext for a uuid.

  Always stores encrypted payload. If `server_password` can decrypt the
  payload, also refreshes the plaintext cache; decrypt failure does **not**
  fail the update (compatible with official CookieCloud clients).
  """
  def put_encrypted(uuid, encrypted, crypto_type, server_password \\ nil) do
    with :ok <- validate_uuid(uuid),
         :ok <- validate_encrypted(encrypted),
         :ok <- validate_crypto_type(crypto_type) do
      {data, client_updated_at} = maybe_decrypt_cache(uuid, encrypted, crypto_type, server_password)

      params = %{
        uuid: uuid,
        encrypted: encrypted,
        crypto_type: crypto_type,
        data: data,
        client_updated_at: client_updated_at
      }

      %SyncRecord{}
      |> SyncRecord.changeset(params)
      |> Repo.insert(
        on_conflict: {:replace, [:encrypted, :crypto_type, :data, :client_updated_at, :updated_at]},
        conflict_target: :uuid
      )
    end
  end

  @doc "Fetch record by uuid, or nil."
  def get(uuid) when is_binary(uuid), do: Repo.get(SyncRecord, uuid)
  def get(_), do: nil

  @doc "Return ciphertext payload map for original CookieCloud clients."
  def ciphertext_payload(%SyncRecord{encrypted: enc, crypto_type: type})
      when is_binary(enc) and enc != "" do
    {:ok, %{encrypted: enc, crypto_type: type || "legacy"}}
  end

  def ciphertext_payload(_), do: {:error, :not_found}

  @doc """
  Decrypt with a client-provided password (original CookieCloud behavior).
  """
  def decrypt_with_password(%SyncRecord{} = record, password, crypto_type_override \\ nil) do
    type = crypto_type_override || record.crypto_type || "legacy"

    case Crypto.cookie_decrypt(record.uuid, record.encrypted, password, type) do
      {:ok, data} -> {:ok, data}
      {:error, _} = err -> err
    end
  end

  @doc """
  Admin path: use cached plaintext, or try server password to decrypt and
  optionally refresh the cache.
  """
  def decrypt_for_admin(%SyncRecord{} = record, server_password) do
    cond do
      is_map(record.data) and map_size(record.data) > 0 ->
        {:ok, record.data}

      is_binary(server_password) and server_password != "" and is_binary(record.encrypted) ->
        case Crypto.cookie_decrypt(
               record.uuid,
               record.encrypted,
               server_password,
               record.crypto_type || "legacy"
             ) do
          {:ok, data} ->
            maybe_refresh_cache(record, data)
            {:ok, data}

          {:error, _} = err ->
            err
        end

      true ->
        {:error, :no_plaintext}
    end
  end

  def valid_uuid?(uuid), do: match?(:ok, validate_uuid(uuid))

  defp maybe_decrypt_cache(_uuid, _encrypted, _type, nil), do: {nil, nil}
  defp maybe_decrypt_cache(_uuid, _encrypted, _type, ""), do: {nil, nil}

  defp maybe_decrypt_cache(uuid, encrypted, crypto_type, password) do
    case Crypto.cookie_decrypt(uuid, encrypted, password, crypto_type) do
      {:ok, data} ->
        {data, extract_client_time(data)}

      {:error, _} ->
        {nil, nil}
    end
  end

  defp maybe_refresh_cache(%SyncRecord{} = record, data) do
    record
    |> SyncRecord.changeset(%{
      data: data,
      client_updated_at: extract_client_time(data)
    })
    |> Repo.update()
  rescue
    _ -> :ok
  end

  defp extract_client_time(%{"update_time" => update_time_str}) when is_binary(update_time_str) do
    case DateTime.from_iso8601(update_time_str) do
      {:ok, dt, _offset} -> DateTime.to_naive(dt)
      {:error, _} -> NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    end
  end

  defp extract_client_time(_), do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  defp validate_uuid(uuid) when is_binary(uuid) do
    if Regex.match?(@uuid_re, uuid), do: :ok, else: {:error, :invalid_uuid}
  end

  defp validate_uuid(_), do: {:error, :invalid_uuid}

  defp validate_encrypted(enc) when is_binary(enc) and enc != "", do: :ok
  defp validate_encrypted(_), do: {:error, :invalid_encrypted}

  defp validate_crypto_type(type) when type in ["legacy", "aes-128-cbc-fixed"], do: :ok
  defp validate_crypto_type(_), do: {:error, :unknown_type}
end
