defmodule ProviderWeb.ScimFilterTest do
  use ProviderWeb.ConnCase

  import Provider.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer valid_user_token")
      |> put_req_header("content-type", "application/scim+json")

    alice = user_fixture(%{user_name: "alice", display_name: "Alice Smith", given_name: "Alice", family_name: "Smith", email: "alice@example.com"})
    user_fixture(%{user_name: "bob", display_name: "Bob Jones", given_name: "Bob", family_name: "Jones", email: "bob@example.org"})
    user_fixture(%{user_name: "carmen98", display_name: "Carmen Ortiz", given_name: "Carmen", family_name: "Ortiz", email: "carmen@example.com"})

    %{conn: conn, alice: alice}
  end

  describe "GET /scim/v2/Users with filter" do
    test "eq returns only the matching user", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName eq "alice"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "alice"
    end

    test "ne excludes the matching user", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName ne "alice"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 2
      usernames = Enum.map(body["Resources"], & &1["userName"])
      refute "alice" in usernames
      assert "bob" in usernames
      assert "carmen98" in usernames
    end

    test "co (contains) matches substring", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=displayName co "Ortiz"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "carmen98"
    end

    test "sw (starts with) matches prefix", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName sw "car"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "carmen98"
    end

    test "ew (ends with) matches suffix", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName ew "98"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "carmen98"
    end

    test "pr (present) returns users with attribute set", %{conn: conn} do
      conn = get(conn, "/scim/v2/Users?filter=active pr")
      body = json_response(conn, 200)

      assert body["totalResults"] == 3
    end

    test "and combines two conditions", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName sw "b" and displayName co "Jones"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "bob"
    end

    test "or matches either condition", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName eq "alice" or userName eq "bob"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 2
      usernames = Enum.map(body["Resources"], & &1["userName"]) |> Enum.sort()
      assert usernames == ["alice", "bob"]
    end

    test "no filter returns all users", %{conn: conn} do
      conn = get(conn, "/scim/v2/Users")
      body = json_response(conn, 200)

      assert body["totalResults"] == 3
    end

    test "displayName eq with space in value", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=displayName eq "Alice Smith"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "alice"
    end

    test "externalId eq maps correctly", %{conn: conn, alice: alice} do
      conn = get(conn, ~s|/scim/v2/Users?filter=externalId eq "#{alice.external_id}"|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 1
      assert [user] = body["Resources"]
      assert user["userName"] == "alice"
    end

    test "empty filter is treated as no filter", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=|)
      body = json_response(conn, 200)

      assert body["totalResults"] == 3
    end

    test "invalid filter returns 400 error", %{conn: conn} do
      conn = get(conn, ~s|/scim/v2/Users?filter=userName BADOP "x"|)
      body = json_response(conn, 400)

      assert body["detail"] =~ "Invalid"
    end
  end
end
