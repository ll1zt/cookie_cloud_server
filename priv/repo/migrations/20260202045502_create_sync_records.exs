defmodule CookieCloudServer.Repo.Migrations.CreateSyncRecords do
  use Ecto.Migration

  def change do
        create table(:sync_records, primary_key: false) do
      add :uuid, :string, primary_key: true
      add :data, :map
      add :client_updated_at, :naive_datetime
      timestamps()
      end
  end
end
