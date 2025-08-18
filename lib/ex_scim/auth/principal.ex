defmodule ExScim.Auth.Principal do
  @enforce_keys [:id, :type, :scopes]
  defstruct [
    # Internal ID or client ID
    :id,
    # :client or :user
    :type,
    # For Basic Auth users
    :username,
    # Human-readable
    :display_name,
    # List of scopes
    :scopes,
    # Extra information
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: :client | :user,
          username: String.t() | nil,
          display_name: String.t() | nil,
          scopes: [String.t()],
          metadata: map()
        }
end
