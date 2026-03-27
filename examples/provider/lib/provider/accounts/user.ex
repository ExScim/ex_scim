defmodule Provider.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:user_name, :string)
    field(:given_name, :string)
    field(:family_name, :string)
    field(:display_name, :string)
    field(:email, :string)
    field(:active, :boolean, default: true)
    field(:external_id, :string)
    field(:meta_created, :utc_datetime_usec)
    field(:meta_last_modified, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :external_id,
      :user_name,
      :given_name,
      :family_name,
      :display_name,
      :email,
      :active,
      :meta_created,
      :meta_last_modified
    ])
    |> validate_required([:external_id, :user_name, :active])
    |> unique_constraint(:external_id, name: "users_external_id_index")
  end
end
