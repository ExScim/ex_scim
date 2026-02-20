defmodule ExScimClient.Resources.ResourceTypes do
  @moduledoc """
  Fetches SCIM ResourceType definitions from a server.

  Used for discovering what resource types the server supports.
  """

  alias ExScimClient.Client
  alias ExScimClient.Request

  @doc "Lists all ResourceType definitions from the server."
  def list(%Client{} = client, opts \\ []) do
    filter = Keyword.get(opts, :filter)
    sorting = Keyword.get(opts, :sorting)
    pagination = Keyword.get(opts, :pagination)
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/ResourceTypes")
    |> Request.method(:get)
    |> Request.filter(filter)
    |> Request.sort_by(sorting)
    |> Request.paginate(pagination)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  @doc "Retrieves a single ResourceType definition by name."
  def get(%Client{} = client, resource_type_name, opts \\ [])
      when is_binary(resource_type_name) do
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/ResourceTypes/#{resource_type_name}")
    |> Request.method(:get)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end
end
