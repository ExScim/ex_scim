defmodule ExScim.Schema.Validator do
  @moduledoc """
  Validates incoming SCIM payloads against registered schemas.

  Delegates to the configured validator adapter. Falls back to
  `ExScim.Schema.Validator.DefaultValidator` when no adapter is configured.

  ## Configuration

      config :ex_scim, scim_validator: MyApp.ScimValidator
  """

  @behaviour ExScim.Schema.Validator.Adapter

  @doc """
  Validates a complete SCIM resource payload (used for POST and PUT operations).

  Returns `{:ok, validated_data}` or `{:error, validation_errors}`.
  """
  @impl true
  def validate_scim_schema(scim_data) do
    adapter().validate_scim_schema(scim_data)
  end

  @doc """
  Validates a partial SCIM payload (used for PATCH operations).

  The `operation_type` indicates the kind of partial update (e.g. `:patch`).

  Returns `{:ok, validated_data}` or `{:error, validation_errors}`.
  """
  @impl true
  def validate_scim_partial(scim_data, operation_type) do
    adapter().validate_scim_partial(scim_data, operation_type)
  end

  @doc "Returns the configured validator adapter module."
  def adapter do
    Application.get_env(
      :ex_scim,
      :scim_validator,
      ExScim.Schema.Validator.DefaultValidator
    )
  end
end
