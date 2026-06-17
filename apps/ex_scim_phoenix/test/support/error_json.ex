defmodule ExScimPhoenix.Test.ErrorJSON do
  @moduledoc """
  JSON error view for the test endpoint, so uncaught exceptions render as a
  SCIM error body (instead of failing to find an HTML template). Used by
  `render_errors` in `ExScimPhoenix.Test.Endpoint`'s config.
  """

  def render(template, _assigns) do
    status = template |> String.split(".") |> hd()

    %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "status" => status,
      "detail" => Phoenix.Controller.status_message_from_template(template)
    }
  end
end
