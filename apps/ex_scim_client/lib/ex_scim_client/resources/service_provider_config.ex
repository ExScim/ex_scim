defmodule ExScimClient.Resources.ServiceProviderConfig do
  @moduledoc """
  Fetches the SCIM ServiceProviderConfig from a server.

  Returns the server's supported features including filtering, bulk, patch, and authentication schemes.
  """

  alias ExScimClient.Client
  alias ExScimClient.Request

  @doc "Retrieves the ServiceProviderConfig from the server."
  def get(%Client{} = client) do
    Request.new(client)
    |> Request.path("/ServiceProviderConfig")
    |> Request.method(:get)
    |> Request.run()
  end
end
