defmodule ExScimEcto.MembershipTest do
  use ExUnit.Case, async: false

  # Requires a live Postgres; excluded by default. Run with: mix test --include db
  @moduletag :db

  alias ExScimEcto.StorageAdapter
  alias ExScimEcto.TestRepo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)

    prev = Application.get_env(:ex_scim, :membership_model)
    Application.put_env(:ex_scim, :membership_model, ExScimEcto.TestSupport.Membership)
    on_exit(fn -> Application.put_env(:ex_scim, :membership_model, prev) end)

    {:ok, _} = StorageAdapter.create_user(%{id: "u1", user_name: "alice"})
    {:ok, _} = StorageAdapter.create_group(%{id: "g1", display_name: "Inner"})
    {:ok, _} = StorageAdapter.create_group(%{id: "g2", display_name: "Outer"})
    :ok
  end

  test "memberships? reflects the :membership_model config" do
    assert StorageAdapter.memberships?()

    Application.delete_env(:ex_scim, :membership_model)
    refute StorageAdapter.memberships?()
  end

  test "replace_members then list_members returns the member records" do
    assert :ok = StorageAdapter.replace_members("g1", [{:user, "u1"}])
    assert :ok = StorageAdapter.replace_members("g2", [{:group, "g1"}, {:user, "u1"}])

    assert {:ok, [{:group, %{id: "g1"}}, {:user, %{id: "u1"}}]} =
             StorageAdapter.list_members("g2")
  end

  test "replace_members replaces the previous members" do
    :ok = StorageAdapter.replace_members("g2", [{:group, "g1"}, {:user, "u1"}])
    :ok = StorageAdapter.replace_members("g2", [{:user, "u1"}])

    assert {:ok, [{:user, %{id: "u1"}}]} = StorageAdapter.list_members("g2")
  end

  test "list_groups_for_member separates users and groups with the same id" do
    {:ok, _} = StorageAdapter.create_group(%{id: "u1", display_name: "Same id as a user"})
    :ok = StorageAdapter.replace_members("g1", [{:user, "u1"}])
    :ok = StorageAdapter.replace_members("g2", [{:group, "u1"}])

    assert {:ok, [%{id: "g1"}]} = StorageAdapter.list_groups_for_member({:user, "u1"})
    assert {:ok, [%{id: "g2"}]} = StorageAdapter.list_groups_for_member({:group, "u1"})
  end

  test "deleting a group removes its membership rows" do
    :ok = StorageAdapter.replace_members("g1", [{:user, "u1"}])
    :ok = StorageAdapter.delete_group("g1")

    assert {:ok, []} = StorageAdapter.list_groups_for_member({:user, "u1"})
  end
end
