defmodule Provider.Repo.Migrations.CreateGroupMemberships do
  use Ecto.Migration

  def change do
    create table(:group_memberships) do
      add(:group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false)
      add(:member_id, :binary_id, null: false)
      add(:member_type, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:group_memberships, [:group_id, :member_type, :member_id]))
    create(index(:group_memberships, [:member_type, :member_id]))
  end
end
