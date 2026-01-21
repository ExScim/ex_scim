defmodule ExScim.Groups.ResourceImpl do
  alias ExScim.Groups.Group

  defimpl ExScim.Resources.Resource, for: Group do
    def get_id(%Group{id: id}), do: id
    def get_external_id(%Group{external_id: external_id}), do: external_id
    def set_id(%Group{} = group, id), do: %{group | id: id}
  end
end
