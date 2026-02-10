# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :provider,
  ecto_repos: [Provider.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :provider, ProviderWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ProviderWeb.ErrorHTML, json: ProviderWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Provider.PubSub,
  live_view: [signing_salt: "GhknlGDr"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :provider, Provider.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  provider: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  provider: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ],
  path: System.get_env("TAILWINDCSS_PATH")

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ex_scim,
  base_url: "http://localhost:4000",
  auth_provider_adapter: Provider.Scim.FakeAuthProvider,
  user_resource_mapper: Provider.Scim.UserMapper,
  group_resource_mapper: Provider.Scim.GroupMapper,
  scim_validator: ExScim.Schema.Validator.DefaultValidator,
  scim_schema_repository: ExScim.Schema.Repository.DefaultRepository,
  lifecycle_adapter: Provider.Scim.Lifecycle,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: Provider.Repo,
  user_model:
    {Provider.Accounts.User,
     filter_mapping: %{
       "emails.value" => :email,
       "name.givenName" => :given_name,
       "name.familyName" => :family_name,
       "name.formatted" => :display_name
     }},
  group_model: Provider.Accounts.Group,
  bulk_supported: true,
  bulk_max_operations: 1000,
  bulk_max_payload_size: 1_048_576,
  patch_supported: true,
  filter_supported: true,
  filter_max_results: 200,
  change_password_supported: true,
  sort_supported: true,
  etag_supported: true,
  documentation_uri: "http://localhost:4000/scim/docs",
  authentication_schemes: [
    %{
      "type" => "oauthbearertoken",
      "name" => "OAuth Bearer Token",
      "description" => "Authentication scheme using the OAuth Bearer Token Standard",
      "specUri" => "https://www.rfc-editor.org/info/rfc6750",
      "primary" => true
    },
    %{
      "type" => "httpbasic",
      "name" => "HTTP Basic",
      "description" => "Authentication scheme using the HTTP Basic Standard",
      "specUri" => "https://www.rfc-editor.org/info/rfc2617"
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
