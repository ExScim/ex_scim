defmodule ExScim.Users.Patcher do
  @moduledoc """
  Applies SCIM PatchOp operations to a user's SCIM representation.
  Handles multiple ops, optional path, simple/complex values, and removals.

  Attribute names are case-insensitive. A path may start with a schema URN:
  the core User schema targets top-level attributes, any other schema the
  object keyed by its URN, e.g.
  `urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber`.
  Adding to an extension lists its URN in `schemas`.

  `replace` on a complex attribute keeps the sub-attributes the value omits.
  `name.familyName` creates a missing `name`.

  Paths may filter multi-valued attributes (RFC 7644 section 3.5.2), e.g.
  `emails[type eq "work"].value`. An `add` whose `eq` filter matches nothing
  appends a new value, so `add emails[type eq "work"].value` creates a work
  email. A `remove` with a list as `value` removes those values.
  """

  @multi_valued ~w(emails phoneNumbers ims photos addresses groups entitlements roles x509Certificates)
  @core_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  @doc """
  Applies SCIM PatchOp operations to a user.

  The `patch_ops` map must contain an `"Operations"` key with a non-empty list
  of operations. Each operation must have an `"op"` field (`"add"`, `"replace"`,
  or `"remove"`) and optionally `"path"` and `"value"` fields.

  Returns `{:ok, updated_user}` or `{:error, {:invalid_patch, scim_type, message}}`.
  """
  @spec patch(map() | struct(), map()) ::
          {:ok, map() | struct()}
          | {:error, {:invalid_patch, ExScim.Error.scim_type(), String.t()}}
  def patch(user_data, patch_ops) do
    ExScim.Resources.Patcher.patch(user_data, patch_ops, @multi_valued, @core_schema)
  end
end
