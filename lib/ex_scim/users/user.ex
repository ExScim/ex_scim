defmodule ExScim.Users.User do
  @moduledoc "Basic User struct for SCIM operations."

  @enforce_keys [:user_name]
  defstruct [
    :id,
    :user_name,
    :display_name,
    :external_id,
    :name,
    :emails,
    :phone_numbers,
    :active,
    :title,
    :user_type,
    :preferred_language,
    :locale,
    :timezone,
    :addresses,
    :photos,
    :meta_created,
    :meta_last_modified
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          user_name: String.t(),
          display_name: String.t() | nil,
          external_id: String.t() | nil,
          name: map() | nil,
          emails: [map()] | nil,
          phone_numbers: [map()] | nil,
          active: boolean() | nil,
          title: String.t() | nil,
          user_type: String.t() | nil,
          preferred_language: String.t() | nil,
          locale: String.t() | nil,
          timezone: String.t() | nil,
          addresses: [map()] | nil,
          photos: [map()] | nil,
          meta_created: DateTime.t() | nil,
          meta_last_modified: DateTime.t() | nil
        }

  def new(user_name, opts \\ []) do
    struct(__MODULE__, [user_name: user_name] ++ opts)
  end
end
