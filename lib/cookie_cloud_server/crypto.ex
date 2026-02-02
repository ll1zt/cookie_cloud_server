defmodule CookieCloudServer.Crypto do
  @block_size 16
  @key_len 32
  @iv_len 16

  def cookie_decrypt(uuid, encrypted_b64, password, crypto_type \\ "legacy") do
    key_base = "#{uuid}-#{password}"
    passphrase = :crypto.hash(:md5, key_base) |> Base.encode16(case: :lower) |> binary_part(0, 16)

    case crypto_type do
      "aes-128-cbc-fixed" ->
        iv = <<0::size(128)>>
        ciphertext = Base.decode64!(encrypted_b64)
        decrypted = :crypto.crypto_one_time(:aes_128_cbc, passphrase, iv, ciphertext, false)
        decrypted |> pkcs7_unpad() |> Jason.decode!()

      _ ->
        decode_legacy(encrypted_b64, passphrase)
    end
  end

  defp decode_legacy(data_b64, passphrase) do
    binary = Base.decode64!(data_b64)
    <<"Salted__", salt::binary-size(8), ciphertext::binary>> = binary

    {key, iv} = evp_bytes_to_key(passphrase, salt, @key_len, @iv_len)

    decrypted = :crypto.crypto_one_time(:aes_256_cbc, key, iv, ciphertext, false)
    decrypted |> pkcs7_unpad() |> Jason.decode!()
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

  defp pkcs7_unpad(data) do
    pad_len = :binary.last(data)

    if pad_len > 0 and pad_len <= @block_size do
      binary_part(data, 0, byte_size(data) - pad_len)
    else
      data
    end
  end
end
