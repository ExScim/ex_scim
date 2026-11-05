defmodule ExScim.DefaultSetupTest do
  @moduledoc """
  Runs the operations against the defaults: EtsStorage with the default mappers.
  """
  use ExUnit.Case, async: false

  alias ExScim.Operations.Users
  alias ExScim.Storage.EtsStorage

  @scope %ExScim.Scope{id: "test-client", scopes: ["scim:read", "scim:write"]}
  @user_schema "urn:ietf:params:scim:schemas:core:2.0:User"

  setup do
    previous_storage = Application.get_env(:ex_scim, :storage_strategy)
    Application.delete_env(:ex_scim, :storage_strategy)
    EtsStorage.clear_all()

    on_exit(fn ->
      EtsStorage.clear_all()
      if previous_storage, do: Application.put_env(:ex_scim, :storage_strategy, previous_storage)
    end)
  end

  test "a created user can be fetched by its id and keeps its attributes" do
    assert {:ok, created} =
             Users.create_user_from_scim(
               %{
                 "schemas" => [@user_schema],
                 "id" => "client-chosen",
                 "userName" => "alice",
                 "password" => "secret",
                 "phoneNumbers" => [%{"value" => "+1-555-0100", "type" => "work"}]
               },
               @scope
             )

    assert created["id"] != "client-chosen"
    refute Map.has_key?(created, "password")
    assert %DateTime{} = DateTime.from_iso8601(created["meta"]["created"]) |> elem(1)

    assert {:ok, fetched} = Users.get_user(created["id"], @scope)
    assert fetched["userName"] == "alice"
    assert fetched["phoneNumbers"] == [%{"value" => "+1-555-0100", "type" => "work"}]
    refute Map.has_key?(fetched, "password")
  end

  test "users can be filtered by userName" do
    {:ok, _} =
      Users.create_user_from_scim(%{"schemas" => [@user_schema], "userName" => "alice"}, @scope)

    {:ok, _} =
      Users.create_user_from_scim(%{"schemas" => [@user_schema], "userName" => "bob"}, @scope)

    assert {:ok, [user], 1} =
             Users.list_users_scim(@scope, %{filter: {:eq, "userName", "alice"}})

    assert user["userName"] == "alice"
  end
end
