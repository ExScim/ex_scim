defprotocol ExScim.Resources.Resource do
  @moduledoc """
  Protocol for SCIM resource operations.

  `get_username/1` raises `ArgumentError` for Group resources.
  """

  def get_id(resource)
  def get_external_id(resource)
  def set_id(resource, id)
end
