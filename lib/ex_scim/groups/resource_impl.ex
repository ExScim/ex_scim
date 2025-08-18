defmodule ExScim.Groups.ResourceImpl do
  alias ExScim.Groups.Group

  defimpl ExScim.Resources.Resource, for: Group do
    def get_id(%Group{id: id}), do: id

    def get_username(%Group{}),
      do: raise(ArgumentError, "Groups do not have usernames. Use get_display_name/1 instead.")

    def get_display_name(%Group{display_name: display_name}), do: display_name
    def get_external_id(%Group{external_id: external_id}), do: external_id
    def set_id(%Group{} = group, id), do: %{group | id: id}
  end
end
