ExUnit.start(exclude: [:db])

if :db in ExUnit.configuration()[:include] do
  Application.put_env(:ex_scim_ecto, ExScimEcto.TestRepo,
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    hostname: System.get_env("PGHOST", "127.0.0.1"),
    port: String.to_integer(System.get_env("PGPORT", "5433")),
    database: System.get_env("PGDATABASE", "ex_scim_ecto_test"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 5,
    log: false
  )

  Application.put_env(:ex_scim, :storage_repo, ExScimEcto.TestRepo)
  Application.put_env(:ex_scim, :user_model, ExScimEcto.TestSupport.User)
  Application.put_env(:ex_scim, :group_model, ExScimEcto.TestSupport.Group)

  {:ok, _} = ExScimEcto.TestRepo.start_link()

  alias Ecto.Adapters.SQL

  SQL.query!(ExScimEcto.TestRepo, "DROP TABLE IF EXISTS user_emails", [])
  SQL.query!(ExScimEcto.TestRepo, "DROP TABLE IF EXISTS users", [])
  SQL.query!(ExScimEcto.TestRepo, "DROP TABLE IF EXISTS groups", [])

  SQL.query!(
    ExScimEcto.TestRepo,
    """
    CREATE TABLE users (
      id text PRIMARY KEY,
      user_name text,
      external_id text,
      display_name text,
      active boolean,
      status text,
      organization_id text,
      inserted_at timestamp(0) NOT NULL DEFAULT now(),
      updated_at timestamp(0) NOT NULL DEFAULT now()
    )
    """,
    []
  )

  SQL.query!(
    ExScimEcto.TestRepo,
    "CREATE UNIQUE INDEX users_user_name_index ON users (user_name)",
    []
  )

  SQL.query!(
    ExScimEcto.TestRepo,
    """
    CREATE TABLE user_emails (
      id bigserial PRIMARY KEY,
      user_id text REFERENCES users(id) ON DELETE CASCADE,
      value text,
      type text
    )
    """,
    []
  )

  SQL.query!(
    ExScimEcto.TestRepo,
    """
    CREATE TABLE groups (
      id text PRIMARY KEY,
      display_name text,
      external_id text,
      organization_id text,
      inserted_at timestamp(0) NOT NULL DEFAULT now(),
      updated_at timestamp(0) NOT NULL DEFAULT now()
    )
    """,
    []
  )

  Ecto.Adapters.SQL.Sandbox.mode(ExScimEcto.TestRepo, :manual)
end
