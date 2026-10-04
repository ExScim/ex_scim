defmodule ExScim.Resources.PatchError do
  @moduledoc """
  Raised by the patchers for a PatchOp request that cannot be applied.

  `ExScim.Users.Patcher.patch/2` and `ExScim.Groups.Patcher.patch/2` convert it to
  `{:error, {:invalid_patch, scim_type, message}}`.
  """

  defexception [:message, scim_type: :invalid_syntax]

  @type t :: %__MODULE__{message: String.t(), scim_type: ExScim.Error.scim_type()}
end
