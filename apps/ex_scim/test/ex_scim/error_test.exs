defmodule ExScim.ErrorTest do
  use ExUnit.Case, async: true

  alias ExScim.Error

  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"

  describe "scim_type_to_string/1" do
    @type_mappings [
      {:invalid_filter, "invalidFilter"},
      {:invalid_path, "invalidPath"},
      {:invalid_syntax, "invalidSyntax"},
      {:invalid_target, "invalidTarget"},
      {:invalid_value, "invalidValue"},
      {:invalid_version, "invalidVersion"},
      {:mutability, "mutability"},
      {:no_authn, "noAuthn"},
      {:no_target, "noTarget"},
      {:not_found, "notFound"},
      {:sensitive, "sensitive"},
      {:too_large, "tooLarge"},
      {:too_many, "tooMany"},
      {:uniqueness, "uniqueness"},
      {:forbidden, "forbidden"},
      {:insufficient_rights, "insufficientRights"},
      {:insufficient_scope, "insufficientScope"},
      {:invalid_credentials, "invalidCredentials"},
      {:internal_error, "internalError"},
      {:unknown, "unknown"}
    ]

    for {atom, string} <- @type_mappings do
      test "maps #{atom} to #{inspect(string)}" do
        assert Error.scim_type_to_string(unquote(atom)) == unquote(string)
      end
    end
  end

  describe "map_status_to_scim_error/1" do
    @status_mappings [
      {400, :invalid_syntax},
      {401, :invalid_credentials},
      {403, :insufficient_rights},
      {404, :not_found},
      {409, :uniqueness},
      {412, :invalid_version},
      {413, :too_large},
      {500, :internal_error}
    ]

    for {status, expected_type} <- @status_mappings do
      test "maps HTTP #{status} to :#{expected_type}" do
        {type, detail} = Error.map_status_to_scim_error(unquote(status))
        assert type == unquote(expected_type)
        assert is_binary(detail)
      end
    end

    test "maps unknown status to :unknown" do
      {type, detail} = Error.map_status_to_scim_error(418)
      assert type == :unknown
      assert is_binary(detail)
    end
  end

  describe "build_error_response/3" do
    test "returns map with required SCIM error keys" do
      resp = Error.build_error_response(404, :not_found, "User not found")

      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "404"
      assert resp["scimType"] == "notFound"
      assert resp["detail"] == "User not found"
    end

    test "status is a string, not an integer" do
      resp = Error.build_error_response(500, :internal_error, "Boom")
      assert is_binary(resp["status"])
    end
  end

  describe "build_validation_error_response/1" do
    test "formats {field, message} tuples" do
      errors = [{"userName", "is required"}, {"active", "must be boolean"}]
      resp = Error.build_validation_error_response(errors)

      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "400"
      assert resp["scimType"] == "invalidValue"
      assert length(resp["errors"]) == 2

      first = hd(resp["errors"])
      assert first["path"] == "userName"
      assert first["message"] == "is required"
    end

    test "passes through pre-formatted error maps" do
      errors = [%{"path" => "email", "message" => "invalid format"}]
      resp = Error.build_validation_error_response(errors)

      assert [%{"path" => "email", "message" => "invalid format"}] = resp["errors"]
    end

    test "wraps bare string errors with unknown path" do
      errors = ["something went wrong"]
      resp = Error.build_validation_error_response(errors)

      assert [%{"path" => "unknown", "message" => "something went wrong"}] = resp["errors"]
    end

    test "treats any 2-tuple as {field, message}" do
      errors = [{:unexpected, :thing}]
      resp = Error.build_validation_error_response(errors)

      [error] = resp["errors"]
      assert error["path"] == "unexpected"
      assert error["message"] == "thing"
    end

    test "handles non-matching terms via inspect fallback" do
      errors = [42]
      resp = Error.build_validation_error_response(errors)

      [error] = resp["errors"]
      assert error["path"] == "unknown"
      assert error["message"] == "42"
    end
  end

  describe "build_error_from_status/1" do
    test "produces complete SCIM error for known status" do
      resp = Error.build_error_from_status(404)

      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "404"
      assert resp["scimType"] == "notFound"
      assert is_binary(resp["detail"])
    end

    test "produces complete SCIM error for unknown status" do
      resp = Error.build_error_from_status(503)

      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "503"
      assert resp["scimType"] == "unknown"
    end
  end
end
