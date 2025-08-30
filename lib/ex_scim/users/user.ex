defmodule ExScim.Users.User do
  @moduledoc """
  User struct representing a SCIM User resource.
  
  Provides the core data structure for user identity information following 
  SCIM 2.0 User schema (RFC 7643 Section 4.1).
  
  ## Required Fields
  
  - `:user_name` - Unique identifier for the user, typically an email or username
  
  ## Examples
  
      iex> user = ExScim.Users.User.new("john.doe@example.com")
      iex> user.user_name
      "john.doe@example.com"
      
      iex> user = ExScim.Users.User.new("john", display_name: "John Doe")
      iex> user.display_name
      "John Doe"
  """

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

  @doc """
  Creates a new User struct with the given user_name and optional fields.
  
  ## Parameters
  
  - `user_name` - Required unique identifier for the user
  - `opts` - Keyword list of optional user attributes
  
  ## Examples
  
      iex> user = ExScim.Users.User.new("john@example.com")
      iex> user.user_name
      "john@example.com"
      
      iex> user = ExScim.Users.User.new("jane", display_name: "Jane Doe", active: true)
      iex> {user.user_name, user.display_name, user.active}
      {"jane", "Jane Doe", true}
  """
  @spec new(String.t(), keyword()) :: t()
  def new(user_name, opts \\ []) do
    struct(__MODULE__, [user_name: user_name] ++ opts)
  end
end
