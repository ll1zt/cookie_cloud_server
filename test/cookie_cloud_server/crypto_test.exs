defmodule CookieCloudServer.CryptoTest do
  use ExUnit.Case, async: true

  alias CookieCloudServer.Crypto

  @aes128_uuid "test-uuid"
  @aes128_password "test-password"

  setup_all do
    # Build a known-good aes-128-cbc-fixed ciphertext with Erlang crypto
    uuid = @aes128_uuid
    password = @aes128_password
    passphrase =
      :crypto.hash(:md5, "#{uuid}-#{password}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    plaintext = Jason.encode!(%{"hello" => "world", "cookie_data" => %{}})
    pad_len = 16 - rem(byte_size(plaintext), 16)
    padded = plaintext <> :binary.copy(<<pad_len>>, pad_len)
    iv = <<0::size(128)>>
    ciphertext = :crypto.crypto_one_time(:aes_128_cbc, passphrase, iv, padded, true)
    encrypted = Base.encode64(ciphertext)

    # legacy: OpenSSL Salted__ format
    salt = :crypto.strong_rand_bytes(8)
    {key, legacy_iv} = evp_bytes_to_key(passphrase, salt, 32, 16)
    legacy_ct = :crypto.crypto_one_time(:aes_256_cbc, key, legacy_iv, padded, true)
    legacy_encrypted = Base.encode64(<<"Salted__", salt::binary, legacy_ct::binary>>)

    %{
      aes128_encrypted: encrypted,
      legacy_encrypted: legacy_encrypted,
      passphrase: passphrase
    }
  end

  test "aes-128-cbc-fixed decrypts known payload", %{aes128_encrypted: encrypted} do
    assert {:ok, data} =
             Crypto.cookie_decrypt(
               @aes128_uuid,
               encrypted,
               @aes128_password,
               "aes-128-cbc-fixed"
             )

    assert data["hello"] == "world"
  end

  test "legacy decrypts salted openssl payload", %{legacy_encrypted: encrypted} do
    assert {:ok, data} =
             Crypto.cookie_decrypt(@aes128_uuid, encrypted, @aes128_password, "legacy")

    assert data["hello"] == "world"
  end

  test "invalid base64 returns error" do
    assert {:error, :invalid_base64} =
             Crypto.cookie_decrypt("u", "%%%not-base64%%%", "p", "aes-128-cbc-fixed")
  end

  test "unknown crypto type returns error" do
    assert {:error, :unknown_type} =
             Crypto.cookie_decrypt("u", Base.encode64("x"), "p", "nope")
  end

  test "wrong password fails for aes-128-cbc-fixed", %{aes128_encrypted: encrypted} do
    assert {:error, reason} =
             Crypto.cookie_decrypt(@aes128_uuid, encrypted, "wrong", "aes-128-cbc-fixed")

    assert reason in [:bad_padding, :invalid_json, :crypto_failed]
  end

  test "legacy rejects non-salted payload" do
    assert {:error, :invalid_format} =
             Crypto.cookie_decrypt("u", Base.encode64("not-salted-payload!!"), "p", "legacy")
  end

  defp evp_bytes_to_key(password, salt, key_len, iv_len) do
    target = key_len + iv_len
    derived = generate(<<>>, password, salt, target)
    <<key::binary-size(key_len), iv::binary-size(iv_len), _::binary>> = derived
    {key, iv}
  end

  defp generate(acc, _p, _s, target) when byte_size(acc) >= target, do: acc

  defp generate(<<>>, p, s, target) do
    generate(:crypto.hash(:md5, p <> s), p, s, target)
  end

  defp generate(acc, p, s, target) do
    last = binary_part(acc, byte_size(acc) - 16, 16)
    generate(acc <> :crypto.hash(:md5, last <> p <> s), p, s, target)
  end
end
