defmodule ExScim.Schema.Validator do
  @behaviour ExScim.Schema.Validator.Adapter

  @impl true
  def validate_scim_schema(scim_data) do
    adapter().validate_scim_schema(scim_data)
  end

  @impl true
  def validate_scim_partial(scim_data, operation_type) do
    adapter().validate_scim_partial(scim_data, operation_type)
  end

  def adapter do
    Application.get_env(
      :ex_scim,
      :scim_validator,
      ExScim.Schema.Validator.DefaultValidator
    )
  end
end
