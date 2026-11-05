defmodule Provider.Scim.ResourceImpl do
  @moduledoc """
  Implementation of ExScim.Resources.Resource protocol for Provider domain structs.
  """

  alias Provider.Accounts.Group
  alias Provider.Accounts.User

  defimpl ExScim.Resources.Resource, for: User do
    @doc "Get the SCIM resource ID from a User struct"
    def get_id(%User{id: id}), do: id

    @doc "Get the username from a User struct"
    def get_username(%User{user_name: username}), do: username

    @doc "Get the display name from a User struct"
    def get_display_name(%User{display_name: display_name}), do: display_name

    @doc "Get the external ID from a User struct"
    def get_external_id(%User{external_id: external_id}), do: external_id

    @doc "Set the SCIM resource ID on a User struct"
    def set_id(%User{} = user, id), do: %{user | id: id}
  end

  defimpl ExScim.Resources.Resource, for: Group do
    @doc "Get the SCIM resource ID from a Group struct"
    def get_id(%Group{id: id}), do: id

    @doc "Groups don't have usernames - this should not be called for groups"
    def get_username(%Group{}), do: raise("Groups do not have usernames")

    @doc "Get the display name from a Group struct"
    def get_display_name(%Group{display_name: display_name}), do: display_name

    @doc "Get the external ID from a Group struct"
    def get_external_id(%Group{external_id: external_id}), do: external_id

    @doc "Set the SCIM resource ID on a Group struct"
    def set_id(%Group{} = group, id), do: %{group | id: id}
  end
end
