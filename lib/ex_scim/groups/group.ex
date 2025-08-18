defmodule ExScim.Groups.Group do
  @moduledoc "Basic Group struct for SCIM operations."

  @enforce_keys [:display_name]
  defstruct [
    :id,
    :display_name,
    :external_id,
    :members,
    :meta_created,
    :meta_last_modified,
    :active
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          display_name: String.t(),
          external_id: String.t() | nil,
          members: [map()] | nil,
          meta_created: DateTime.t() | nil,
          meta_last_modified: DateTime.t() | nil,
          active: boolean() | nil
        }

  def new(display_name, opts \\ []) do
    struct(__MODULE__, [display_name: display_name] ++ opts)
  end
end
