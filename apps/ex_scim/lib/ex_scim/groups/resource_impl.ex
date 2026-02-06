defmodule ExScim.Groups.ResourceImpl do
  defimpl ExScim.Resources.Resource, for: ExScim.Groups.Group do
    def get_id(%ExScim.Groups.Group{id: id}), do: id
    def get_external_id(%ExScim.Groups.Group{external_id: external_id}), do: external_id
    def set_id(%ExScim.Groups.Group{} = group, id), do: %{group | id: id}
  end
end
