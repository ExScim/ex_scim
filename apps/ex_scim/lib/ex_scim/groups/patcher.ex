defmodule ExScim.Groups.Patcher do
  @moduledoc """
  Applies SCIM PatchOp operations to group data (maps or structs).
  Handles multiple ops, optional path, simple/complex values, and removals.

  Attribute names ignore case and underscores, so `"displayName"` targets
  `:display_name` or `"displayName"`. Schema-qualified paths are supported.
  Attributes a struct doesn't define are ignored.

  Paths may filter multi-valued attributes (RFC 7644 section 3.5.2), e.g.
  `members[value eq "2819c223"].display`. An `add` whose `eq` filter matches
  nothing appends a new value. A `remove` with a list as `value` removes those
  values.
  """

  @multi_valued ~w(members groups entitlements roles)

  @doc """
  Applies SCIM PatchOp operations to a group.

  The `patch_ops` map must contain an `"Operations"` key with a non-empty list
  of operations. Each operation must have an `"op"` field (`"add"`, `"replace"`,
  or `"remove"`) and optionally `"path"` and `"value"` fields.

  Returns `{:ok, updated_group}` or `{:error, {:invalid_patch, scim_type, message}}`.
  """
  @spec patch(map() | struct(), map()) ::
          {:ok, map() | struct()}
          | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def patch(group_data, patch_ops) do
    ExScim.Resources.Patcher.patch(group_data, patch_ops, @multi_valued)
  end
end
