defmodule ExScimEcto.TestSupport.UserEmail do
  @moduledoc "Associated table for exercising preloads."
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_emails" do
    field(:value, :string)
    field(:type, :string)
    belongs_to(:user, ExScimEcto.TestSupport.User, type: :string)
  end

  def changeset(email, attrs) do
    cast(email, attrs, [:value, :type, :user_id])
  end
end

defmodule ExScimEcto.TestSupport.User do
  @moduledoc "User schema for the StorageAdapter integration tests (string id = SCIM id)."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "users" do
    field(:user_name, :string)
    field(:external_id, :string)
    field(:display_name, :string)
    field(:active, :boolean)
    field(:status, :string)
    field(:organization_id, :string)
    has_many(:user_emails, ExScimEcto.TestSupport.UserEmail, foreign_key: :user_id)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :id,
      :user_name,
      :external_id,
      :display_name,
      :active,
      :status,
      :organization_id
    ])
    |> validate_required([:id, :user_name])
    |> unique_constraint(:user_name)
  end
end

defmodule ExScimEcto.TestSupport.UserStatus do
  @moduledoc "Maps SCIM/domain :active onto a DB :status column (for field_mapping tests)."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "users" do
    field(:user_name, :string)
    field(:status, :string)
    field(:organization_id, :string)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :user_name, :status, :organization_id])
    |> validate_required([:id])
  end
end

defmodule ExScimEcto.TestSupport.Group do
  @moduledoc "Group schema for the StorageAdapter integration tests."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "groups" do
    field(:display_name, :string)
    field(:external_id, :string)
    field(:organization_id, :string)
    timestamps()
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:id, :display_name, :external_id, :organization_id])
    |> validate_required([:id, :display_name])
  end
end
