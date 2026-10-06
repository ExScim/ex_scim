defmodule Provider.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:external_id, :string)
      add(:user_name, :string, null: false)
      add(:given_name, :string)
      add(:family_name, :string)
      add(:display_name, :string)
      add(:email, :string)
      add(:active, :boolean, default: false, null: false)
      add(:meta_created, :utc_datetime)
      add(:meta_last_modified, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:users, [:user_name]))
    create(unique_index(:users, [:external_id]))
  end
end
