defmodule ExScim.Users.Mapper.Adapter do
  @moduledoc "User resource mapper behaviour."

  @type user_struct :: struct() | map()
  @type scim_data :: map()

  @callback from_scim(scim_data()) :: user_struct()

  @callback to_scim(user_struct(), keyword()) :: scim_data()
end
