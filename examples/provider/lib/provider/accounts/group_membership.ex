defmodule Provider.Accounts.GroupMembership do
  @moduledoc """
  Links a group to one member, a user or a nested group.

  Used by `ExScimEcto.StorageAdapter` through the `:membership_model` config.
  """

  use Ecto.Schema

  schema "group_memberships" do
    field(:member_id, :binary_id)
    field(:member_type, :string)

    belongs_to(:group, Provider.Accounts.Group, type: :binary_id)

    timestamps(type: :utc_datetime)
  end
end
