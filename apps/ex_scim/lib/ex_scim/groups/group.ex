defmodule ExScim.Groups.Group do
  @moduledoc """
  Group struct representing a SCIM Group resource.

  Provides the core data structure for group information following
  SCIM 2.0 Group schema (RFC 7643 Section 4.2).

  ## Required Fields

  - `:display_name` - Human-readable name for the group

  ## Examples

      iex> group = ExScim.Groups.Group.new("Engineering")
      iex> group.display_name
      "Engineering"

      iex> group = ExScim.Groups.Group.new("Admins", active: true, members: [])
      iex> {group.display_name, group.active}
      {"Admins", true}
  """

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

  @doc """
  Creates a new Group struct with the given display name and optional fields.

  ## Parameters

  - `display_name` - Required display name for the group
  - `opts` - Keyword list of optional group attributes

  ## Examples

      iex> group = ExScim.Groups.Group.new("Engineering")
      iex> group.display_name
      "Engineering"

      iex> group = ExScim.Groups.Group.new("Admins", active: true)
      iex> {group.display_name, group.active}
      {"Admins", true}
  """
  @spec new(String.t(), keyword()) :: t()
  def new(display_name, opts \\ []) do
    struct(__MODULE__, [display_name: display_name] ++ opts)
  end
end
