defmodule ExScim.Users.ResourceImpl do
  alias ExScim.Users.User

  defimpl ExScim.Resources.Resource, for: User do
    def get_id(%User{id: id}), do: id
    def get_external_id(%User{external_id: external_id}), do: external_id
    def set_id(%User{} = user, id), do: %{user | id: id}
  end
end
