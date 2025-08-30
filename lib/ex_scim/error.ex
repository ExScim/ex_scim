defmodule ExScim.Error do
  @moduledoc """
  SCIM error handling and standardization per RFC 7644 Section 3.12.

  This module provides SCIM error types, standardization functions, and error response
  formatting that maintains proper separation between core SCIM logic and web concerns.
  """

  @scim_error_schema "urn:ietf:params:scim:api:messages:2.0:Error"

  @typedoc """
  SCIM error types as defined in RFC 7644 Section 3.12.
  """
  @type scim_type ::
          :invalid_filter
          | :invalid_path
          | :invalid_syntax
          | :invalid_target
          | :invalid_value
          | :invalid_version
          | :mutability
          | :no_authn
          | :no_target
          | :not_found
          | :sensitive
          | :too_large
          | :too_many
          | :uniqueness
          | :forbidden
          | :insufficient_rights
          | :insufficient_scope
          | :invalid_credentials
          | :internal_error
          | :unknown

  @typedoc """
  Standard SCIM error response structure.
  
  Contains string keys: "schemas", "status", "scimType", "detail", "errors".
  Generic String.t() keys used due to Elixir type system limitations.
  """
  @type error_response :: %{
          required(String.t()) => [String.t()],
          required(String.t()) => String.t(),
          required(String.t()) => String.t(),
          optional(String.t()) => String.t(),
          optional(String.t()) => [validation_error()]
        }

  @typedoc """
  Individual validation error for multi-error responses.
  
  Contains string keys: "path", "message".
  """
  @type validation_error :: %{
          required(String.t()) => String.t(),
          required(String.t()) => String.t()
        }

  @doc """
  Converts SCIM error types to their string representation.
  """
  @spec scim_type_to_string(scim_type()) :: String.t()
  def scim_type_to_string(:invalid_filter), do: "invalidFilter"
  def scim_type_to_string(:invalid_path), do: "invalidPath"
  def scim_type_to_string(:invalid_syntax), do: "invalidSyntax"
  def scim_type_to_string(:invalid_target), do: "invalidTarget"
  def scim_type_to_string(:invalid_value), do: "invalidValue"
  def scim_type_to_string(:invalid_version), do: "invalidVersion"
  def scim_type_to_string(:mutability), do: "mutability"
  def scim_type_to_string(:no_authn), do: "noAuthn"
  def scim_type_to_string(:no_target), do: "noTarget"
  def scim_type_to_string(:not_found), do: "notFound"
  def scim_type_to_string(:sensitive), do: "sensitive"
  def scim_type_to_string(:too_large), do: "tooLarge"
  def scim_type_to_string(:too_many), do: "tooMany"
  def scim_type_to_string(:uniqueness), do: "uniqueness"
  def scim_type_to_string(:forbidden), do: "forbidden"
  def scim_type_to_string(:insufficient_rights), do: "insufficientRights"
  def scim_type_to_string(:insufficient_scope), do: "insufficientScope"
  def scim_type_to_string(:invalid_credentials), do: "invalidCredentials"
  def scim_type_to_string(:internal_error), do: "internalError"
  def scim_type_to_string(:unknown), do: "unknown"

  @doc """
  Maps HTTP status codes to appropriate SCIM error types and default messages.
  """
  @spec map_status_to_scim_error(integer()) :: {scim_type(), String.t()}
  def map_status_to_scim_error(400),
    do: {:invalid_syntax, "Request is unparseable, syntactically incorrect, or violates schema"}

  def map_status_to_scim_error(401), do: {:invalid_credentials, "Authentication failure"}
  def map_status_to_scim_error(403), do: {:insufficient_rights, "Insufficient access rights"}
  def map_status_to_scim_error(404), do: {:not_found, "Specified resource does not exist"}
  def map_status_to_scim_error(409), do: {:uniqueness, "Resource already exists"}

  def map_status_to_scim_error(412),
    do: {:invalid_version, "Version specified in If-Match header does not match"}

  def map_status_to_scim_error(413), do: {:too_large, "Request entity too large"}
  def map_status_to_scim_error(500), do: {:internal_error, "Internal server error"}
  def map_status_to_scim_error(_), do: {:unknown, "An error occurred"}

  @doc """
  Creates a standard SCIM error response structure.
  """
  @spec build_error_response(integer(), scim_type(), String.t()) :: error_response()
  def build_error_response(status_code, scim_type, detail) do
    %{
      "schemas" => [@scim_error_schema],
      "status" => Integer.to_string(status_code),
      "scimType" => scim_type_to_string(scim_type),
      "detail" => detail
    }
  end

  @doc """
  Creates a SCIM validation error response with multiple errors.
  """
  @spec build_validation_error_response([validation_error()]) :: error_response()
  def build_validation_error_response(errors) when is_list(errors) do
    %{
      "schemas" => [@scim_error_schema],
      "status" => "400",
      "scimType" => "invalidValue",
      "errors" => errors |> convert_validation_errors_to_scim()
    }
  end

  defp convert_validation_errors_to_scim(errors) when is_list(errors) do
    errors
    |> Enum.map(fn
      {field, message} -> %{"path" => to_string(field), "message" => to_string(message)}
      %{"path" => _, "message" => _} = error -> error
      message when is_binary(message) -> %{"path" => "unknown", "message" => message}
      error -> %{"path" => "unknown", "message" => inspect(error)}
    end)
  end

  @doc """
  Creates a standardized error response from an HTTP status code.
  """
  @spec build_error_from_status(integer()) :: error_response()
  def build_error_from_status(status_code) do
    {scim_type, detail} = map_status_to_scim_error(status_code)
    build_error_response(status_code, scim_type, detail)
  end
end
