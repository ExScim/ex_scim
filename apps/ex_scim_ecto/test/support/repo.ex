defmodule ExScimEcto.TestRepo do
  @moduledoc "Postgres-backed repo used by the StorageAdapter integration tests."
  use Ecto.Repo, otp_app: :ex_scim_ecto, adapter: Ecto.Adapters.Postgres
end
