defmodule ExScim.Schema.Validator.Adapter do
  @moduledoc """
  Behaviour for SCIM schema validators.

  Implementations validate incoming SCIM payloads against schema definitions.
  Two validation modes are supported:

  - **Full validation** (`validate_scim_schema/1`) - for POST and PUT operations
    where a complete resource representation is required.
  - **Partial validation** (`validate_scim_partial/2`) - for PATCH operations
    where only a subset of attributes may be present.
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

  @doc """
  Validates a partial SCIM payload (PATCH).

  The `operation_type` indicates the kind of partial update (e.g. `:patch`).
  Returns `{:ok, validated_data}` or `{:error, validation_errors}`.
  """
  @callback validate_scim_partial(scim_data(), operation_type :: atom()) ::
              {:ok, scim_data()} | {:error, validation_errors()}
end
