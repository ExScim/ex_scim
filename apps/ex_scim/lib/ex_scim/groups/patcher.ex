defmodule ExScim.Groups.Patcher do
  @moduledoc """
  Applies SCIM PatchOp operations to a group's SCIM representation.
  Handles multiple ops, optional path, simple/complex values, and removals.

  Attribute names are case-insensitive. A path may start with a schema URN:
  the core Group schema targets top-level attributes, any other schema the
  object keyed by its URN. Adding to an extension lists its URN in `schemas`.

  `replace` on a complex attribute keeps the sub-attributes the value omits.
  A sub-attribute path creates its missing parent.

  Paths may filter multi-valued attributes (RFC 7644 section 3.5.2), e.g.
  `members[value eq "2819c223"].display`. An `add` whose `eq` filter matches
  nothing appends a new value. A `remove` with a list as `value` removes those
  values.
  """

  @multi_valued ~w(members groups entitlements roles)
  @core_schema "urn:ietf:params:scim:schemas:core:2.0:Group"

  @doc """
  Applies SCIM PatchOp operations to a group.

  The `patch_ops` map must contain an `"Operations"` key with a non-empty list
  of operations. Each operation must have an `"op"` field (`"add"`, `"replace"`,
  or `"remove"`) and optionally `"path"` and `"value"` fields.

  Passing a struct or an atom-keyed map is deprecated and logs a warning.

  Returns `{:ok, updated_group}` or `{:error, {:invalid_patch, scim_type, message}}`.
  """
  @spec patch(map() | struct(), map()) ::
          {:ok, map() | struct()}
          | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def patch(group_data, patch_ops) do
    ExScim.Resources.Patcher.patch(group_data, patch_ops, @multi_valued, @core_schema)
  end
end
