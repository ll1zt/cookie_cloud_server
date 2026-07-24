defmodule CookieCloudServer.Schema.SyncRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:uuid, :string, autogenerate: false}

  schema "sync_records" do
    field(:encrypted, :string)
    field(:crypto_type, :string, default: "legacy")
    # Optional plaintext cache for admin export features
    field(:data, :map)
    field(:client_updated_at, :naive_datetime)

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:uuid, :encrypted, :crypto_type, :data, :client_updated_at])
    |> validate_required([:uuid, :encrypted])
    |> validate_format(:uuid, ~r/^[A-Za-z0-9_-]{8,128}$/)
    |> validate_inclusion(:crypto_type, ["legacy", "aes-128-cbc-fixed"])
  end
end
