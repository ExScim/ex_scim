defmodule ExScim.Resources.ResourceImpl do
  @moduledoc "Generic Map implementation of ExScim.Resources.Resource protocol."

  defimpl ExScim.Resources.Resource, for: Map do
    def get_id(%{id: id}), do: id
    def get_id(%{"id" => id}), do: id
    def get_id(_), do: nil

    def get_external_id(%{external_id: external_id}), do: external_id
    def get_external_id(%{"externalId" => external_id}), do: external_id
    def get_external_id(_), do: nil

    def set_id(%{id: _} = resource, id), do: Map.put(resource, :id, id)

    def set_id(resource, id) when is_map(resource) do
      if Enum.any?(Map.keys(resource), &is_binary/1),
        do: Map.put(resource, "id", id),
        else: Map.put(resource, :id, id)
    end
  end
end
