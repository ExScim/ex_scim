defmodule Provider.Accounts.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "groups" do
    field(:active, :boolean, default: false)
    field(:description, :string)
    field(:display_name, :string)
    field(:external_id, :string)
    field(:meta_created, :utc_datetime_usec)
    field(:meta_last_modified, :utc_datetime_usec)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :display_name,
      :description,
      :external_id,
      :active,
      :meta_created,
      :meta_last_modified
    ])
    |> validate_required([
      :display_name,
      :description,
      :external_id,
      :active,
      :meta_created,
      :meta_last_modified
    ])
    |> unique_constraint(:external_id)
  end
end
