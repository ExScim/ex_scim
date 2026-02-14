defmodule ExScim.ScopeTest do
  use ExUnit.Case, async: true

  alias ExScim.Scope

  describe "new/1" do
    test "creates scope from map with required keys" do
      assert {:ok, %Scope{id: "user_1", scopes: ["scim:read"]}} =
               Scope.new(%{id: "user_1", scopes: ["scim:read"]})
    end

    test "creates scope from keyword list" do
      assert {:ok, %Scope{id: "user_1", scopes: ["scim:read"]}} =
               Scope.new(id: "user_1", scopes: ["scim:read"])
    end

    test "creates scope with tenant_id" do
      assert {:ok, scope} =
               Scope.new(%{id: "user_1", scopes: ["scim:read"], tenant_id: "org_123"})

      assert scope.tenant_id == "org_123"
    end

    test "creates scope without tenant_id (single-tenant mode)" do
      assert {:ok, scope} = Scope.new(%{id: "user_1", scopes: ["scim:read"]})
      assert scope.tenant_id == nil
    end

    test "creates scope with all optional fields" do
      assert {:ok, scope} =
               Scope.new(%{
                 id: "user_1",
                 scopes: ["scim:read", "scim:write"],
                 tenant_id: "org_123",
                 username: "admin",
                 display_name: "Admin User",
                 metadata: %{"role" => "admin"}
               })

      assert scope.id == "user_1"
      assert scope.scopes == ["scim:read", "scim:write"]
      assert scope.tenant_id == "org_123"
      assert scope.username == "admin"
      assert scope.display_name == "Admin User"
      assert scope.metadata == %{"role" => "admin"}
    end

    test "defaults metadata to empty map" do
      assert {:ok, scope} = Scope.new(%{id: "user_1", scopes: []})
      assert scope.metadata == %{}
    end

    test "returns :error when missing id" do
      assert :error = Scope.new(%{scopes: ["scim:read"]})
    end

    test "returns :error when missing scopes" do
      assert :error = Scope.new(%{id: "user_1"})
    end

    test "returns :error for empty map" do
      assert :error = Scope.new(%{})
    end

    test "returns :error when id is not a string" do
      assert :error = Scope.new(%{id: 123, scopes: ["scim:read"]})
    end

    test "returns :error when scopes is not a list" do
      assert :error = Scope.new(%{id: "user_1", scopes: "scim:read"})
    end
  end

  describe "has_scope?/2" do
    test "returns true when scope is present" do
      scope = %Scope{id: "user_1", scopes: ["scim:read", "scim:write"]}
      assert Scope.has_scope?(scope, "scim:read")
    end

    test "returns false when scope is not present" do
      scope = %Scope{id: "user_1", scopes: ["scim:read"]}
      refute Scope.has_scope?(scope, "scim:write")
    end

    test "returns false for empty scopes" do
      scope = %Scope{id: "user_1", scopes: []}
      refute Scope.has_scope?(scope, "scim:read")
    end
  end

  describe "has_all_scopes?/2" do
    test "returns true when all scopes are present" do
      scope = %Scope{id: "user_1", scopes: ["scim:read", "scim:write", "scim:admin"]}
      assert Scope.has_all_scopes?(scope, ["scim:read", "scim:write"])
    end

    test "returns false when some scopes are missing" do
      scope = %Scope{id: "user_1", scopes: ["scim:read"]}
      refute Scope.has_all_scopes?(scope, ["scim:read", "scim:write"])
    end

    test "returns true for empty required scopes" do
      scope = %Scope{id: "user_1", scopes: ["scim:read"]}
      assert Scope.has_all_scopes?(scope, [])
    end

    test "returns false when scope has no scopes and some are required" do
      scope = %Scope{id: "user_1", scopes: []}
      refute Scope.has_all_scopes?(scope, ["scim:read"])
    end
  end

  describe "struct construction" do
    test "can be created directly with required keys" do
      scope = %Scope{id: "user_1", scopes: ["scim:read"], tenant_id: "org_1"}
      assert scope.id == "user_1"
      assert scope.tenant_id == "org_1"
    end

    test "tenant_id defaults to nil" do
      scope = %Scope{id: "user_1", scopes: []}
      assert scope.tenant_id == nil
    end

    test "supports pattern matching on tenant_id" do
      scope = %Scope{id: "user_1", scopes: [], tenant_id: "org_1"}

      assert %Scope{tenant_id: "org_1"} = scope
    end

    test "supports updating tenant_id" do
      scope = %Scope{id: "user_1", scopes: []}
      updated = %{scope | tenant_id: "org_123"}

      assert updated.tenant_id == "org_123"
      assert updated.id == "user_1"
    end
  end
end
