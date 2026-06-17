defmodule ExScim.Parser.FilterTest do
  use ExUnit.Case, async: true

  alias ExScim.Parser.Filter

  # Helper: extract the AST from a successful parse
  defp parse!(input) do
    assert {:ok, [ast], "", _, _, _} = Filter.filter(input)
    ast
  end

  # Helper: assert parse failure
  defp assert_parse_error(input) do
    assert {:error, _, _, _, _, _} = Filter.filter(input)
  end

  describe "comparison operators with quoted values" do
    test "eq" do
      assert parse!("userName eq \"john\"") == {:eq, "userName", "john"}
    end

    test "ne" do
      assert parse!("active ne \"false\"") == {:ne, "active", "false"}
    end

    test "co (contains)" do
      assert parse!("email co \"example\"") == {:co, "email", "example"}
    end

    test "sw (starts with)" do
      assert parse!("userName sw \"admin\"") == {:sw, "userName", "admin"}
    end

    test "ew (ends with)" do
      assert parse!("email ew \"@corp.com\"") == {:ew, "email", "@corp.com"}
    end

    test "gt (greater than)" do
      assert parse!("count gt \"5\"") == {:gt, "count", "5"}
    end

    test "ge (greater or equal)" do
      assert parse!("count ge \"5\"") == {:ge, "count", "5"}
    end

    test "lt (less than)" do
      assert parse!("count lt \"10\"") == {:lt, "count", "10"}
    end

    test "le (less or equal)" do
      assert parse!("count le \"10\"") == {:le, "count", "10"}
    end
  end

  describe "comparison operators with unquoted keywords" do
    test "eq true" do
      assert parse!("active eq true") == {:eq, "active", "true"}
    end

    test "eq false" do
      assert parse!("active eq false") == {:eq, "active", "false"}
    end

    test "eq null" do
      assert parse!("value eq null") == {:eq, "value", "null"}
    end
  end

  describe "pr (present)" do
    test "simple attribute" do
      assert parse!("userName pr") == {:pr, "userName"}
    end

    test "dotted attribute" do
      assert parse!("name.familyName pr") == {:pr, "name.familyName"}
    end
  end

  describe "logical operators" do
    test "and" do
      assert parse!("a eq \"1\" and b eq \"2\"") ==
               {:and, {:eq, "a", "1"}, {:eq, "b", "2"}}
    end

    test "or" do
      assert parse!("a eq \"1\" or b eq \"2\"") ==
               {:or, {:eq, "a", "1"}, {:eq, "b", "2"}}
    end

    test "not" do
      assert parse!("not (active eq true)") == {:not, {:eq, "active", "true"}}
    end

    test "and binds tighter than or (left-to-right precedence)" do
      # "a and b or c" parses as "(a and b) or c"
      assert parse!("a eq \"1\" and b eq \"2\" or c eq \"3\"") ==
               {:or, {:and, {:eq, "a", "1"}, {:eq, "b", "2"}}, {:eq, "c", "3"}}
    end

    test "chained and" do
      assert parse!("a eq \"1\" and b eq \"2\" and c eq \"3\"") ==
               {:and, {:and, {:eq, "a", "1"}, {:eq, "b", "2"}}, {:eq, "c", "3"}}
    end
  end

  describe "grouped (parenthesized) expressions" do
    test "group overrides precedence" do
      assert parse!("(a eq \"1\" or b eq \"2\") and c eq \"3\"") ==
               {:and, {:or, {:eq, "a", "1"}, {:eq, "b", "2"}}, {:eq, "c", "3"}}
    end

    test "nested groups" do
      assert parse!("(a eq \"1\" and (b eq \"2\" or c eq \"3\"))") ==
               {:and, {:eq, "a", "1"}, {:or, {:eq, "b", "2"}, {:eq, "c", "3"}}}
    end
  end

  describe "attribute paths" do
    test "simple attribute" do
      assert parse!("userName eq \"x\"") == {:eq, "userName", "x"}
    end

    test "dotted path" do
      assert parse!("name.familyName eq \"Smith\"") == {:eq, "name.familyName", "Smith"}
    end

    test "schema-qualified path with colons" do
      assert parse!("urn:ietf:params:scim:schemas:core:2.0:User:userName eq \"x\"") ==
               {:eq, "urn:ietf:params:scim:schemas:core:2.0:User:userName", "x"}
    end
  end

  describe "value filter (bracket) expressions" do
    test "attribute with value filter" do
      assert parse!("emails[type eq \"work\"]") ==
               {"emails", [{:eq, "type", "work"}]}
    end
  end

  describe "operator case insensitivity" do
    test "uppercase EQ" do
      assert parse!("userName EQ \"john\"") == {:eq, "userName", "john"}
    end

    test "mixed case Eq" do
      assert parse!("userName Eq \"john\"") == {:eq, "userName", "john"}
    end

    test "uppercase AND" do
      assert parse!("a eq \"1\" AND b eq \"2\"") ==
               {:and, {:eq, "a", "1"}, {:eq, "b", "2"}}
    end

    test "mixed case Or" do
      assert parse!("a eq \"1\" Or b eq \"2\"") ==
               {:or, {:eq, "a", "1"}, {:eq, "b", "2"}}
    end

    test "uppercase PR" do
      assert parse!("userName PR") == {:pr, "userName"}
    end

    test "uppercase NOT" do
      assert parse!("NOT (active eq true)") == {:not, {:eq, "active", "true"}}
    end
  end

  describe "parse errors" do
    test "empty string" do
      assert_parse_error("")
    end

    test "attribute without operator" do
      assert_parse_error("userName")
    end

    test "operator without value" do
      assert_parse_error("userName eq")
    end

    test "unbalanced opening paren" do
      assert_parse_error("(a eq \"1\"")
    end

    test "unbalanced closing paren" do
      assert_parse_error("a eq \"1\")")
    end

    test "bare integer value (not quoted, not keyword)" do
      assert_parse_error("count gt 5")
    end
  end
end
