defmodule CookieCloudServer.Schema.SyncRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:uuid, :string, autogenerate: false}

  schema "sync_records" do
    field(:data, :map)
    field(:client_updated_at, :naive_datetime)

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:uuid, :data, :client_updated_at])
    |> validate_required([:uuid, :data])
  end
end
