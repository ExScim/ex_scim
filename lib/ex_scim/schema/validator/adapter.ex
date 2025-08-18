defmodule ExScim.Schema.Validator.Adapter do
  @moduledoc "SCIM schema validator behaviour."

  @type scim_data :: map()
  @type validation_errors :: keyword()

  @callback validate_scim_schema(scim_data()) ::
              {:ok, scim_data()} | {:error, validation_errors()}

  @callback validate_scim_partial(scim_data(), operation_type :: atom()) ::
              {:ok, scim_data()} | {:error, validation_errors()}
end
