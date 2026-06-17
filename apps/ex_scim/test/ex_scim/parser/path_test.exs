defmodule ExScim.Parser.PathTest do
  use ExUnit.Case, async: true

  alias ExScim.Parser.Path

  describe "path/1" do
    test "parses a simple attribute" do
      assert {:ok, %{schema: nil, attribute: "userName"}} = parse("userName")
    end

    test "parses an attribute with digits, underscores, and hyphens" do
      assert {:ok, %{schema: nil, attribute: "x_attr-1"}} = parse("x_attr-1")
    end

    test "parses a schema-qualified attribute (URN before the final colon segment)" do
      urn = "urn:ietf:params:scim:schemas:core:2.0:User:userName"

      assert {:ok, %{schema: "urn:ietf:params:scim:schemas:core:2.0:User", attribute: "userName"}} =
               parse(urn)
    end

    test "treats a dotted name as a single attribute (dots are part of attr_path)" do
      # attr_path's char set includes '.', so it consumes the whole dotted name;
      # the `.sub` branch only triggers after a value filter (see below).
      assert {:ok, %{schema: nil, attribute: "name.familyName", sub: _}} =
               parse("name.familyName") |> with_default_sub()
    end

    test "parses a value filter expression" do
      assert {:ok, %{schema: nil, attribute: "emails", filter: ~s(type eq "work")}} =
               parse(~s(emails[type eq "work"]))
    end

    test "parses a value filter expression with a sub-attribute" do
      assert {:ok, %{attribute: "emails", filter: ~s(type eq "work"), sub: "value"}} =
               parse(~s(emails[type eq "work"].value))
    end

    test "returns an error for an empty string" do
      assert {:error, _} = parse("")
    end

    test "returns an error for trailing junk (eos enforced)" do
      assert {:error, _} = parse("userName extra")
    end

    test "returns an error for an unclosed value filter bracket" do
      assert {:error, _} = parse(~s(emails[type eq "work"))
    end
  end

  describe "reducer functions" do
    test "reduce_attr_path/1 splits a schema-qualified path" do
      assert %{schema: "urn:a:b", attribute: "attr"} =
               Path.reduce_attr_path(["urn:a:b:attr"])
    end

    test "reduce_attr_path/1 returns nil schema for a bare attribute" do
      assert %{schema: nil, attribute: "userName"} = Path.reduce_attr_path(["userName"])
    end

    test "reduce_attr_with_filter/1 attaches a filter when present" do
      assert %{attribute: "emails", filter: "f"} =
               Path.reduce_attr_with_filter([%{attribute: "emails"}, "f"])
    end

    test "reduce_attr_with_filter/1 passes through when no filter" do
      assert %{attribute: "emails"} = Path.reduce_attr_with_filter([%{attribute: "emails"}])
    end

    test "reduce_final_path/1 attaches a sub-attribute when present" do
      assert %{attribute: "emails", sub: "value"} =
               Path.reduce_final_path([%{attribute: "emails"}, "value"])
    end

    test "reduce_final_path/1 passes through when no sub-attribute" do
      assert %{attribute: "emails"} = Path.reduce_final_path([%{attribute: "emails"}])
    end

    test "reduce_filter_exp/1 builds an attr/op/value map" do
      assert %{attr: "type", op: "eq", value: ~s("work")} =
               Path.reduce_filter_exp(["type", "eq", ~s("work")])
    end
  end

  # Extracts the single AST result from the NimbleParsec 6-tuple (path ends with eos()).
  defp parse(input) do
    case Path.path(input) do
      {:ok, [result], "", _, _, _} -> {:ok, result}
      {:ok, _, rest, _, _, _} -> {:error, {:incomplete, rest}}
      {:error, reason, _, _, _, _} -> {:error, reason}
    end
  end

  # The dotted-name result has no :sub key; normalize so the match above is meaningful.
  defp with_default_sub({:ok, map}), do: {:ok, Map.put_new(map, :sub, nil)}
  defp with_default_sub(other), do: other
end
