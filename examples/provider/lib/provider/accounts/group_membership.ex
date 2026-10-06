defmodule Provider.Accounts.GroupMembership do
  use Ecto.Schema
  import Ecto.Changeset
  alias Provider.Accounts.User
  alias Provider.Accounts.Group

  schema "group_memberships" do
    field(:type, :string)
    # field :group_id, :id
    # field :user_id, :id

    belongs_to(:group, Group)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group_membership, attrs) do
    group_membership
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
