defmodule ExScim.Resources.ResourceImpl do
  @moduledoc "Generic Map implementation of ExScim.Resources.Resource protocol."

  defimpl ExScim.Resources.Resource, for: Map do
    def get_id(%{id: id}), do: id
    def get_id(_), do: nil

    def get_external_id(%{external_id: external_id}), do: external_id
    def get_external_id(_), do: nil

    def set_id(resource, id) when is_map(resource), do: Map.put(resource, :id, id)
  end
end
