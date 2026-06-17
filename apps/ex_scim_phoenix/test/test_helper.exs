Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:ex_scim_phoenix, ExScimPhoenix.Test.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  server: false,
  render_errors: [formats: [json: ExScimPhoenix.Test.ErrorJSON], layout: false]
)

{:ok, _} = ExScimPhoenix.Test.Endpoint.start_link()

ExUnit.start()
