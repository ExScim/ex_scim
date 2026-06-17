defmodule ExScimPhoenix.Test.Router do
  @moduledoc """
  Phoenix router for controller pipeline tests.

  Uses `ExScimPhoenix.Router` to inject the full set of SCIM routes. The
  router macro injects routes at the module level (it does not wrap them in a
  pipeline), so the SCIM auth and content-type plugs are applied at the
  endpoint level in `ExScimPhoenix.Test.Endpoint`.
  """

  use Phoenix.Router
  use ExScimPhoenix.Router
end
