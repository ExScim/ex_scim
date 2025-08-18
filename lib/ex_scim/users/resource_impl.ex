defmodule ExScim.Users.ResourceImpl do
  alias ExScim.Users.User

  defimpl ExScim.Resources.Resource, for: User do
    def get_id(%User{id: id}), do: id
    def get_username(%User{user_name: user_name}), do: user_name
    def get_display_name(%User{display_name: display_name}), do: display_name
    def get_external_id(%User{external_id: external_id}), do: external_id
    def set_id(%User{} = user, id), do: %{user | id: id}
  end
end
