defmodule ExScim.Groups.Mapper.Adapter do
  @moduledoc "Group resource mapper behaviour."

  @type group_struct :: struct() | map()
  @type scim_data :: map()

  @callback from_scim(scim_data()) :: group_struct()

  @callback to_scim(group_struct(), keyword()) :: scim_data()
end
