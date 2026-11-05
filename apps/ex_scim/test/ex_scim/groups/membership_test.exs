defmodule ExScim.Groups.MembershipTest do
  use ExUnit.Case, async: false

  alias ExScim.Operations.Groups
  alias ExScim.Operations.Users
  alias ExScim.Storage.EtsStorage

  @scope %ExScim.Scope{id: "test-client", scopes: ["scim:read", "scim:write"]}
  @group_schema "urn:ietf:params:scim:schemas:core:2.0:Group"
  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  setup do
    previous_storage = Application.get_env(:ex_scim, :storage_strategy)
    Application.put_env(:ex_scim, :storage_strategy, EtsStorage)
    EtsStorage.clear_all()

    on_exit(fn ->
      EtsStorage.clear_all()

      if previous_storage,
        do: Application.put_env(:ex_scim, :storage_strategy, previous_storage),
        else: Application.delete_env(:ex_scim, :storage_strategy)
    end)

    {:ok, user} = create_user("alice", "Alice")
    {:ok, user: user}
  end

  test "EtsStorage stores memberships" do
    assert ExScim.Storage.memberships?()
  end

  describe "Group.members" do
    test "lists users and groups with $ref, display and type", %{user: user} do
      {:ok, inner} = create_group("Inner", [%{"value" => user["id"], "type" => "User"}])
      {:ok, outer} = create_group("Outer", [%{"value" => inner["id"], "type" => "Group"}])

      assert [member] = inner["members"]
      assert member["value"] == user["id"]
      assert member["type"] == "User"
      assert member["display"] == "Alice"
      assert member["$ref"] =~ "/Users/#{user["id"]}"

      assert {:ok, %{"members" => [nested]}} = Groups.get_group(outer["id"], @scope)
      assert nested["value"] == inner["id"]
      assert nested["type"] == "Group"
      assert nested["display"] == "Inner"
      assert nested["$ref"] =~ "/Groups/#{inner["id"]}"
    end

    test "infers a missing type", %{user: user} do
      {:ok, inner} = create_group("Inner", [])
      {:ok, group} = create_group("Mixed", [%{"value" => user["id"]}, %{"value" => inner["id"]}])

      assert Enum.map(group["members"], & &1["type"]) == ["User", "Group"]
    end

    test "rejects unknown members and mismatched types", %{user: user} do
      assert {:error, [{"members", _}]} = create_group("G1", [%{"value" => "missing"}])

      assert {:error, [{"members", _}]} =
               create_group("G2", [%{"value" => user["id"], "type" => "Group"}])

      assert {:error, [type: _]} =
               create_group("G3", [%{"value" => user["id"], "type" => "Robot"}])

      assert {:error, [{"members", _}]} = create_group("G4", [%{"display" => "no value"}])
    end

    test "PATCH adds and removes members", %{user: user} do
      {:ok, group} = create_group("Team", [])

      assert {:ok, patched} =
               patch_group(group["id"], [
                 %{"op" => "add", "path" => "members", "value" => [%{"value" => user["id"]}]}
               ])

      assert [%{"value" => user_id}] = patched["members"]
      assert user_id == user["id"]

      assert {:ok, patched} =
               patch_group(group["id"], [
                 %{"op" => "remove", "path" => ~s(members[value eq "#{user["id"]}"])}
               ])

      assert patched["members"] == []
    end

    test "PATCH of other attributes keeps members", %{user: user} do
      {:ok, group} = create_group("Team", [%{"value" => user["id"]}])

      assert {:ok, patched} =
               patch_group(group["id"], [
                 %{"op" => "replace", "path" => "displayName", "value" => "Squad"}
               ])

      assert patched["displayName"] == "Squad"
      assert [%{"value" => _}] = patched["members"]
    end

    test "PUT replaces members", %{user: user} do
      {:ok, group} = create_group("Team", [%{"value" => user["id"]}])

      assert {:ok, replaced} =
               Groups.replace_group_from_scim(
                 group["id"],
                 %{"schemas" => [@group_schema], "displayName" => "Team"},
                 @scope
               )

      assert replaced["members"] == []
    end

    test "rejects a group as its own member" do
      {:ok, group} = create_group("Self", [])

      assert {:error, [{"members", message}]} =
               patch_group(group["id"], [
                 %{"op" => "add", "path" => "members", "value" => [%{"value" => group["id"]}]}
               ])

      assert message =~ "itself"
    end

    test "rejects circular memberships" do
      {:ok, a} = create_group("A", [])
      {:ok, b} = create_group("B", [%{"value" => a["id"]}])
      {:ok, c} = create_group("C", [%{"value" => b["id"]}])

      assert {:error, [{"members", message}]} =
               patch_group(a["id"], [
                 %{"op" => "add", "path" => "members", "value" => [%{"value" => c["id"]}]}
               ])

      assert message =~ c["id"]
    end
  end

  describe "User.groups" do
    test "lists direct and indirect groups", %{user: user} do
      {:ok, a} = create_group("A", [%{"value" => user["id"]}])
      {:ok, b} = create_group("B", [%{"value" => a["id"]}])
      {:ok, c} = create_group("C", [%{"value" => b["id"]}])

      assert {:ok, fetched} = Users.get_user(user["id"], @scope)

      assert Enum.map(fetched["groups"], &{&1["value"], &1["type"], &1["display"]}) == [
               {a["id"], "direct", "A"},
               {b["id"], "indirect", "B"},
               {c["id"], "indirect", "C"}
             ]

      assert hd(fetched["groups"])["$ref"] =~ "/Groups/#{a["id"]}"
    end

    test "a group reached both directly and indirectly is direct", %{user: user} do
      {:ok, a} = create_group("A", [%{"value" => user["id"]}])
      {:ok, _b} = create_group("B", [%{"value" => a["id"]}, %{"value" => user["id"]}])

      assert {:ok, fetched} = Users.get_user(user["id"], @scope)
      assert Enum.map(fetched["groups"], & &1["type"]) == ["direct", "direct"]
    end

    test "is ignored on PUT", %{user: user} do
      {:ok, a} = create_group("A", [])

      assert {:ok, replaced} =
               Users.replace_user_from_scim(
                 user["id"],
                 %{
                   "schemas" => [@user_schema],
                   "userName" => "alice",
                   "groups" => [%{"value" => a["id"]}]
                 },
                 @scope
               )

      assert replaced["groups"] == []
    end

    test "can't be changed by PATCH", %{user: user} do
      {:ok, a} = create_group("A", [])

      assert {:error, {:invalid_patch, :mutability, _}} =
               Users.patch_user_from_scim(
                 user["id"],
                 %{
                   "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
                   "Operations" => [
                     %{"op" => "add", "path" => "groups", "value" => [%{"value" => a["id"]}]}
                   ]
                 },
                 @scope
               )
    end
  end

  describe "deletes" do
    test "deleting a user removes it from its groups", %{user: user} do
      {:ok, group} = create_group("Team", [%{"value" => user["id"]}])

      assert :ok = Users.delete_user(user["id"], @scope)
      assert {:ok, %{"members" => []}} = Groups.get_group(group["id"], @scope)
    end

    test "deleting a group removes it from parents and drops its members", %{user: user} do
      {:ok, a} = create_group("A", [%{"value" => user["id"]}])
      {:ok, b} = create_group("B", [%{"value" => a["id"]}])

      assert :ok = Groups.delete_group(a["id"], @scope)
      assert {:ok, %{"members" => []}} = Groups.get_group(b["id"], @scope)
      assert {:ok, %{"groups" => []}} = Users.get_user(user["id"], @scope)
    end
  end

  defp create_user(user_name, display_name) do
    Users.create_user_from_scim(
      %{"schemas" => [@user_schema], "userName" => user_name, "displayName" => display_name},
      @scope
    )
  end

  defp create_group(display_name, members) do
    Groups.create_group_from_scim(
      %{"schemas" => [@group_schema], "displayName" => display_name, "members" => members},
      @scope
    )
  end

  defp patch_group(id, operations) do
    Groups.patch_group_from_scim(
      id,
      %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => operations
      },
      @scope
    )
  end
end
