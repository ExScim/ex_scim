defmodule ExScim.QueryFilter.EtsQueryFilterTest do
  use ExUnit.Case, async: true

  alias ExScim.QueryFilter.EtsQueryFilter

  @users [
    %{"userName" => "alice", "active" => "true", "displayName" => "Alice Smith", "age" => "30"},
    %{"userName" => "bob", "active" => "false", "displayName" => "Bob Jones", "age" => "25"},
    %{
      "userName" => "charlie",
      "active" => "true",
      "displayName" => "Charlie Brown",
      "age" => "40"
    }
  ]

  describe "apply_filter/2 with nil" do
    test "returns all users unfiltered" do
      assert EtsQueryFilter.apply_filter(@users, nil) == @users
    end
  end

  describe "eq" do
    test "matches exact value" do
      result = EtsQueryFilter.apply_filter(@users, {:eq, "userName", "alice"})
      assert length(result) == 1
      assert hd(result)["userName"] == "alice"
    end

    test "returns empty when no match" do
      assert EtsQueryFilter.apply_filter(@users, {:eq, "userName", "nobody"}) == []
    end
  end

  describe "ne" do
    test "excludes matching value" do
      result = EtsQueryFilter.apply_filter(@users, {:ne, "userName", "alice"})
      assert length(result) == 2
      refute Enum.any?(result, &(&1["userName"] == "alice"))
    end
  end

  describe "co (contains)" do
    test "matches substring" do
      result = EtsQueryFilter.apply_filter(@users, {:co, "displayName", "Brown"})
      assert length(result) == 1
      assert hd(result)["userName"] == "charlie"
    end

    test "matches at start" do
      result = EtsQueryFilter.apply_filter(@users, {:co, "displayName", "Alice"})
      assert length(result) == 1
    end

    test "returns empty when substring not found" do
      assert EtsQueryFilter.apply_filter(@users, {:co, "displayName", "Zara"}) == []
    end
  end

  describe "sw (starts with)" do
    test "matches prefix" do
      result = EtsQueryFilter.apply_filter(@users, {:sw, "displayName", "Bob"})
      assert length(result) == 1
      assert hd(result)["userName"] == "bob"
    end

    test "does not match mid-string" do
      assert EtsQueryFilter.apply_filter(@users, {:sw, "displayName", "Jones"}) == []
    end
  end

  describe "ew (ends with)" do
    test "matches suffix" do
      result = EtsQueryFilter.apply_filter(@users, {:ew, "displayName", "Smith"})
      assert length(result) == 1
      assert hd(result)["userName"] == "alice"
    end

    test "does not match prefix" do
      assert EtsQueryFilter.apply_filter(@users, {:ew, "displayName", "Alice"}) == []
    end
  end

  describe "gt / ge / lt / le (ordering)" do
    test "gt filters strictly greater" do
      result = EtsQueryFilter.apply_filter(@users, {:gt, "age", "30"})
      assert length(result) == 1
      assert hd(result)["userName"] == "charlie"
    end

    test "ge includes equal" do
      result = EtsQueryFilter.apply_filter(@users, {:ge, "age", "30"})
      assert length(result) == 2
      names = Enum.map(result, & &1["userName"])
      assert "alice" in names
      assert "charlie" in names
    end

    test "lt filters strictly less" do
      result = EtsQueryFilter.apply_filter(@users, {:lt, "age", "30"})
      assert length(result) == 1
      assert hd(result)["userName"] == "bob"
    end

    test "le includes equal" do
      result = EtsQueryFilter.apply_filter(@users, {:le, "age", "30"})
      assert length(result) == 2
    end
  end

  describe "pr (present)" do
    test "matches when field exists and is non-nil" do
      result = EtsQueryFilter.apply_filter(@users, {:pr, "displayName"})
      assert length(result) == 3
    end

    test "excludes when field is nil" do
      users_with_nil = [%{"userName" => "alice", "title" => nil}]
      assert EtsQueryFilter.apply_filter(users_with_nil, {:pr, "title"}) == []
    end

    test "excludes when field is absent" do
      users_without = [%{"userName" => "alice"}]
      assert EtsQueryFilter.apply_filter(users_without, {:pr, "title"}) == []
    end
  end

  describe "and" do
    test "intersects two conditions" do
      filter = {:and, {:eq, "active", "true"}, {:sw, "userName", "a"}}
      result = EtsQueryFilter.apply_filter(@users, filter)

      assert length(result) == 1
      assert hd(result)["userName"] == "alice"
    end
  end

  describe "or" do
    test "unions two conditions" do
      filter = {:or, {:eq, "userName", "alice"}, {:eq, "userName", "bob"}}
      result = EtsQueryFilter.apply_filter(@users, filter)

      assert length(result) == 2
      names = Enum.map(result, & &1["userName"])
      assert "alice" in names
      assert "bob" in names
    end
  end

  describe "complex filters" do
    test "nested and/or" do
      # (active == true) and (name starts with "A" or name starts with "C")
      filter =
        {:and, {:eq, "active", "true"}, {:or, {:sw, "userName", "a"}, {:sw, "userName", "c"}}}

      result = EtsQueryFilter.apply_filter(@users, filter)
      assert length(result) == 2
      names = Enum.map(result, & &1["userName"])
      assert "alice" in names
      assert "charlie" in names
    end
  end

  describe "unrecognized AST node" do
    test "returns false (filters out the entry)" do
      result = EtsQueryFilter.apply_filter(@users, {:unknown_op, "x", "y"})
      assert result == []
    end
  end
end
