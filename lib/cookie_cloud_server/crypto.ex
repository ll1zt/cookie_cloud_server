defmodule CookieCloudServer.Crypto do
  @moduledoc """
  CookieCloud compatible decrypt helpers.

  Returns `{:ok, map}` / `{:error, reason}` so callers can handle bad input
  without process crashes.
  """

  @block_size 16
  @key_len 32
  @iv_len 16

  @type crypto_type :: String.t()
  @type error_reason ::
          :invalid_base64
          | :invalid_format
          | :bad_padding
          | :invalid_json
          | :unknown_type
          | :crypto_failed

  @doc """
  Decrypt CookieCloud payload.

  Supported `crypto_type`:
  - `"legacy"` (default) — OpenSSL-compatible Salted__ AES-256-CBC
  - `"aes-128-cbc-fixed"` — AES-128-CBC with fixed zero IV
  """
  @spec cookie_decrypt(String.t(), String.t(), String.t(), crypto_type()) ::
          {:ok, map()} | {:error, error_reason()}
  def cookie_decrypt(uuid, encrypted_b64, password, crypto_type \\ "legacy")

  def cookie_decrypt(uuid, encrypted_b64, password, crypto_type)
      when is_binary(uuid) and is_binary(encrypted_b64) and is_binary(password) and
             is_binary(crypto_type) do
    passphrase = derive_passphrase(uuid, password)

    case crypto_type do
      "aes-128-cbc-fixed" ->
        decrypt_aes128_fixed(encrypted_b64, passphrase)

      "legacy" ->
        decode_legacy(encrypted_b64, passphrase)

      _ ->
        {:error, :unknown_type}
    end
  end

  def cookie_decrypt(_, _, _, _), do: {:error, :invalid_format}

  defp derive_passphrase(uuid, password) do
    :crypto.hash(:md5, "#{uuid}-#{password}")
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp decrypt_aes128_fixed(encrypted_b64, passphrase) do
    with {:ok, ciphertext} <- decode64(encrypted_b64),
         {:ok, decrypted} <- aes_decrypt(:aes_128_cbc, passphrase, <<0::size(128)>>, ciphertext),
         {:ok, unpadded} <- pkcs7_unpad(decrypted),
         {:ok, data} <- decode_json(unpadded) do
      {:ok, data}
    end
  end

  defp decode_legacy(data_b64, passphrase) do
    with {:ok, binary} <- decode64(data_b64),
         {:ok, salt, ciphertext} <- split_salted(binary) do
      {key, iv} = evp_bytes_to_key(passphrase, salt, @key_len, @iv_len)

      with {:ok, decrypted} <- aes_decrypt(:aes_256_cbc, key, iv, ciphertext),
           {:ok, unpadded} <- pkcs7_unpad(decrypted),
           {:ok, data} <- decode_json(unpadded) do
        {:ok, data}
      end
    end
  end

  defp split_salted(<<"Salted__", salt::binary-size(8), ciphertext::binary>>)
       when byte_size(ciphertext) > 0 do
    {:ok, salt, ciphertext}
  end

  defp split_salted(_), do: {:error, :invalid_format}

  defp aes_decrypt(alg, key, iv, ciphertext) do
    try do
      {:ok, :crypto.crypto_one_time(alg, key, iv, ciphertext, false)}
    rescue
      _ -> {:error, :crypto_failed}
    end
  end

  defp decode64(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode_json(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :invalid_json}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp evp_bytes_to_key(password, salt, key_len, iv_len) do
    target_len = key_len + iv_len
    derived = generate_evp_bytes(password, salt, <<>>, target_len)
    <<key::binary-size(key_len), iv::binary-size(iv_len), _::binary>> = derived
    {key, iv}
  end

  defp generate_evp_bytes(_p, _s, acc, target) when byte_size(acc) >= target, do: acc

  defp generate_evp_bytes(p, s, <<>>, target) do
    d = :crypto.hash(:md5, p <> s)
    generate_evp_bytes(p, s, d, target)
  end

  defp generate_evp_bytes(p, s, acc, target) do
    last_chunk = binary_part(acc, byte_size(acc) - 16, 16)
    d = :crypto.hash(:md5, last_chunk <> p <> s)
    generate_evp_bytes(p, s, acc <> d, target)
  end

  defp pkcs7_unpad(data) when byte_size(data) == 0, do: {:error, :bad_padding}

  defp pkcs7_unpad(data) when is_binary(data) do
    pad_len = :binary.last(data)

    cond do
      pad_len < 1 or pad_len > @block_size ->
        {:error, :bad_padding}

      byte_size(data) < pad_len ->
        {:error, :bad_padding}

      not valid_pkcs7_padding?(data, pad_len) ->
        {:error, :bad_padding}

      true ->
        {:ok, binary_part(data, 0, byte_size(data) - pad_len)}
    end
  end

  defp valid_pkcs7_padding?(data, pad_len) do
    padding = binary_part(data, byte_size(data) - pad_len, pad_len)
    padding == :binary.copy(<<pad_len>>, pad_len)
  end
end
