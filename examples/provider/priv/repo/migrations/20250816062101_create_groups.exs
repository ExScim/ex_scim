defmodule Provider.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:display_name, :string)
      add(:description, :string)
      add(:external_id, :string)
      add(:active, :boolean, default: false, null: false)
      add(:meta_created, :utc_datetime_usec)
      add(:meta_last_modified, :utc_datetime_usec)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:groups, [:external_id]))
    create(index(:groups, [:display_name]))
  end
end
