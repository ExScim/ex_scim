defprotocol ExScim.Resources.Resource do
  @moduledoc """
  Protocol for SCIM resource operations.
  """

  @doc "Returns the internal ID of the resource, or `nil` if not yet assigned."
  def get_id(resource)

  @doc "Returns the external ID (provider-assigned) of the resource, or `nil`."
  def get_external_id(resource)

  @doc "Returns a new resource with the given ID set."
  def set_id(resource, id)
end
