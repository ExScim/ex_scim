defmodule ExScim.Resources.ResourceImpl do
  @moduledoc "Generic Map implementation of ExScim.Resources.Resource protocol."

  defimpl ExScim.Resources.Resource, for: Map do
    def get_id(%{id: id}), do: id
    def get_id(_), do: nil

    def get_username(%{user_name: username}), do: username

    def get_username(%{display_name: _} = resource) do
      if Map.has_key?(resource, :members) or Map.has_key?(resource, "members") do
        raise ArgumentError, "Groups do not have usernames. Use get_display_name/1 instead."
      else
        nil
      end
    end

    def get_username(_), do: nil

    def get_display_name(%{display_name: display_name}), do: display_name
    def get_display_name(_), do: nil

    def get_external_id(%{external_id: external_id}), do: external_id
    def get_external_id(_), do: nil

    def set_id(resource, id) when is_map(resource), do: Map.put(resource, :id, id)
  end
end
