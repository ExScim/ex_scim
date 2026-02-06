defmodule ExScim.Users.ResourceImpl do
  defimpl ExScim.Resources.Resource, for: ExScim.Users.User do
    def get_id(%ExScim.Users.User{id: id}), do: id
    def get_external_id(%ExScim.Users.User{external_id: external_id}), do: external_id
    def set_id(%ExScim.Users.User{} = user, id), do: %{user | id: id}
  end
end
