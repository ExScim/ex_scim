defmodule ExScim.Schema.Validator.Adapter do
  @moduledoc """
  Behaviour for SCIM schema validators.

  Implementations validate complete SCIM resource payloads for POST and PUT
  with `validate_scim_schema/1`. PATCH requests are validated against the
  resource type's schemas by ExScim itself.
  """

  @typedoc "A SCIM resource payload as a JSON-decoded map."
  @type scim_data :: map()

  @typedoc "A keyword list of validation errors, e.g. `[userName: \"is required\"]`."
  @type validation_errors :: keyword()

  @doc """
  Validates a complete SCIM resource payload (POST/PUT).

  Returns `{:ok, validated_data}` with potentially normalized data,
  or `{:error, validation_errors}`.
  """
  @callback validate_scim_schema(scim_data()) ::
              {:ok, scim_data()} | {:error, validation_errors()}
end
