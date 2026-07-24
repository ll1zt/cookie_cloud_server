defmodule CookieCloudServer.Repo.Migrations.AddEncryptedFieldsToSyncRecords do
  use Ecto.Migration

  def change do
    alter table(:sync_records) do
      add :encrypted, :text
      add :crypto_type, :string, default: "legacy"
    end
  end
end
