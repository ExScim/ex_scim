defmodule ExScimPhoenix.Test.Endpoint do
  @moduledoc """
  Minimal Phoenix endpoint for controller pipeline tests.

  Runs the real request path: JSON body parsing, the SCIM content-type plug,
  the SCIM auth plug (which assigns `:scim_scope`), then the SCIM router. This
  lets controller tests exercise the full HTTP pipeline including the
  per-controller `RequireScopes` plugs.
  """

  use Phoenix.Endpoint, otp_app: :ex_scim_phoenix

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(ExScimPhoenix.Plugs.ScimContentType)
  plug(ExScimPhoenix.Plugs.ScimAuth)
  plug(ExScimPhoenix.Test.Router)
end
