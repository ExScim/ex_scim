defmodule ExScim.Schema.PatchValidatorTest do
  use ExUnit.Case, async: false

  alias ExScim.Schema.PatchValidator

  @enterprise "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

  defp ops(operations), do: %{"Operations" => List.wrap(operations)}

  defp validate(operations, type \\ "User"), do: PatchValidator.validate(ops(operations), type)

  describe "validate/2" do
    test "rewrites paths and value keys to the schema's spelling" do
      assert {:ok, %{"Operations" => [by_path, without_path]}} =
               validate([
                 %{"op" => "replace", "path" => "NAME.familyname", "value" => "Smith"},
                 %{
                   "op" => "replace",
                   "value" => %{"DisplayName" => "JD", "NAME" => %{"GIVENNAME" => "J"}}
                 }
               ])

      assert by_path["path"] == "name.familyName"
      assert without_path["value"] == %{"displayName" => "JD", "name" => %{"givenName" => "J"}}
    end

    test "keeps filters and rewrites the sub-attribute after them" do
      assert {:ok, %{"Operations" => [op]}} =
               validate(%{
                 "op" => "replace",
                 "path" => ~s(EMAILS[type eq "work"].VALUE),
                 "value" => "a@b.c"
               })

      assert op["path"] == ~s(emails[type eq "work"].value)
    end

    test "accepts extension attributes by path and as objects without a path" do
      assert {:ok, %{"Operations" => [by_path, without_path]}} =
               validate([
                 %{"op" => "add", "path" => "#{@enterprise}:EMPLOYEENUMBER", "value" => "42"},
                 %{"op" => "add", "value" => %{@enterprise => %{"department" => "R&D"}}}
               ])

      assert by_path["path"] == "#{@enterprise}:employeeNumber"
      assert without_path["value"] == %{@enterprise => %{"department" => "R&D"}}
    end

    test "accepts externalId" do
      assert {:ok, _} = validate(%{"op" => "replace", "path" => "externalId", "value" => "x"})
    end

    test "rejects unknown attributes, sub-attributes and schemas" do
      for path <- ["favoriteColor", "name.nickname", "urn:example:schema:User:x", "a.b.c"] do
        assert {:error, {:invalid_patch, :invalid_path, _}} =
                 validate(%{"op" => "replace", "path" => path, "value" => "x"}),
               path
      end

      assert {:error, {:invalid_patch, :invalid_path, _}} =
               validate(%{"op" => "replace", "value" => %{"name" => %{"nickname" => "x"}}})
    end

    test "rejects paths to read-only attributes" do
      for operation <- [
            %{"op" => "replace", "path" => "id", "value" => "x"},
            %{"op" => "remove", "path" => "meta"},
            %{"op" => "replace", "path" => "#{@enterprise}:manager.displayName", "value" => "x"}
          ] do
        assert {:error, {:invalid_patch, :mutability, _}} = validate(operation)
      end
    end

    test "leaves read-only values inside value to validate_changes/3" do
      assert {:ok, _} =
               validate(%{"op" => "replace", "value" => %{"id" => "1", "active" => false}})
    end

    test "rejects replacing or removing immutable attributes" do
      path = ~s(members[value eq "u1"].value)

      for op <- ["replace", "remove"] do
        assert {:error, {:invalid_patch, :mutability, _}} =
                 validate(%{"op" => op, "path" => path, "value" => "u2"}, "Group")
      end
    end

    test "allows whole members to be added, removed and replaced" do
      for operation <- [
            %{"op" => "add", "path" => "members", "value" => [%{"value" => "u1"}]},
            %{"op" => "remove", "path" => ~s(members[value eq "u1"])},
            %{"op" => "replace", "path" => "members", "value" => [%{"value" => "u2"}]}
          ] do
        assert {:ok, _} = validate(operation, "Group")
      end
    end

    test "passes malformed operations through" do
      assert {:ok, _} = validate(%{"path" => "displayName"})
    end
  end

  describe "validate_changes/3 with read-only values" do
    test "drops read-only values that equal the current ones" do
      patch_ops = ops(%{"op" => "replace", "value" => %{"id" => "1", "displayName" => "Eng"}})

      assert {:ok, %{"Operations" => [%{"value" => %{"displayName" => "Eng"}}]}} =
               PatchValidator.validate_changes(patch_ops, %{"id" => "1"}, "User")
    end

    test "drops read-only sub-attributes that equal the current ones" do
      patch_ops =
        ops(%{
          "op" => "replace",
          "path" => "#{@enterprise}:manager",
          "value" => %{"value" => "boss", "displayName" => "Boss"}
        })

      resource = %{@enterprise => %{"manager" => %{"displayName" => "Boss"}}}

      assert {:ok, %{"Operations" => [%{"value" => %{"value" => "boss"}}]}} =
               PatchValidator.validate_changes(patch_ops, resource, "User")
    end

    test "rejects read-only values that differ from the current ones" do
      patch_ops = ops(%{"op" => "replace", "value" => %{"id" => "2", "displayName" => "Eng"}})

      assert {:error, {:invalid_patch, :mutability, _}} =
               PatchValidator.validate_changes(patch_ops, %{"id" => "1"}, "User")
    end
  end

  describe "validate_changes/3 with immutable attributes" do
    defmodule DeviceSchema do
      use ExScim.Schema.Builder

      schema "urn:example:schemas:Device" do
        name("Device")
        attribute(:serialNumber, :string, mutability: :immutable)
      end
    end

    setup do
      previous =
        {Application.get_env(:ex_scim, :schema_modules),
         Application.get_env(:ex_scim, :resource_types)}

      Application.put_env(:ex_scim, :schema_modules, [DeviceSchema])

      Application.put_env(:ex_scim, :resource_types, [
        %{id: "Device", schema: "urn:example:schemas:Device", schema_extensions: []}
      ])

      on_exit(fn ->
        {schema_modules, resource_types} = previous
        restore(:schema_modules, schema_modules)
        restore(:resource_types, resource_types)
      end)
    end

    test "allows adding an immutable attribute without a value" do
      patch_ops = ops(%{"op" => "add", "path" => "serialNumber", "value" => "SN1"})

      assert {:ok, ^patch_ops} = PatchValidator.validate_changes(patch_ops, %{}, "Device")
    end

    test "rejects adding an immutable attribute that has a value" do
      for operation <- [
            %{"op" => "add", "path" => "serialNumber", "value" => "SN2"},
            %{"op" => "add", "value" => %{"serialNumber" => "SN2"}}
          ] do
        assert {:error, {:invalid_patch, :mutability, _}} =
                 PatchValidator.validate_changes(
                   ops(operation),
                   %{"serialNumber" => "SN1"},
                   "Device"
                 )
      end
    end
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
