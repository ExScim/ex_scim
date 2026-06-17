defmodule ExScimPhoenix.ErrorResponseTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import ExScimPhoenix.Test.ConnHelpers

  alias ExScimPhoenix.ErrorResponse

  @error_schema "urn:ietf:params:scim:api:messages:2.0:Error"

  describe "send_scim_error/4" do
    test "sets status code and SCIM error body" do
      conn =
        conn(:get, "/Users")
        |> ErrorResponse.send_scim_error(:not_found, :not_found, "User not found")

      assert conn.status == 404
      assert conn.halted

      resp = decode_response(conn)
      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "404"
      assert resp["scimType"] == "notFound"
      assert resp["detail"] == "User not found"
    end

    test "accepts integer status codes" do
      conn =
        conn(:post, "/Users")
        |> ErrorResponse.send_scim_error(409, :uniqueness, "Already exists")

      assert conn.status == 409

      resp = decode_response(conn)
      assert resp["scimType"] == "uniqueness"
    end
  end

  describe "send_validation_errors/2" do
    test "sends 400 with validation error list" do
      errors = [{"userName", "is required"}, {"active", "must be boolean"}]

      conn =
        conn(:post, "/Users")
        |> ErrorResponse.send_validation_errors(errors)

      assert conn.status == 400
      assert conn.halted

      resp = decode_response(conn)
      assert resp["schemas"] == [@error_schema]
      assert resp["status"] == "400"
      assert resp["scimType"] == "invalidValue"
      assert length(resp["errors"]) == 2
    end
  end

  describe "send_scim_error_from_status/2" do
    test "maps atom status to SCIM error" do
      conn =
        conn(:get, "/Users/123")
        |> ErrorResponse.send_scim_error_from_status(:not_found)

      assert conn.status == 404
      assert conn.halted

      resp = decode_response(conn)
      assert resp["scimType"] == "notFound"
    end

    test "maps integer status to SCIM error" do
      conn =
        conn(:post, "/Users")
        |> ErrorResponse.send_scim_error_from_status(400)

      assert conn.status == 400

      resp = decode_response(conn)
      assert resp["scimType"] == "invalidSyntax"
    end
  end
end
