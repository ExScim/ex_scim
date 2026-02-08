defmodule ExScimClient.FilterTest do
  use ExUnit.Case

  alias ExScimClient.Filter

  describe "filter creation" do
    test "creates empty filter" do
      assert Filter.new() == %Filter{expr: nil}
    end

    test "adds single expression" do
      filter =
        Filter.new()
        |> Filter.equals("userName", "foo")

      assert filter == %Filter{expr: {:eq, "userName", "foo"}}
    end

    test "combines expressions with and" do
      filter =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.and1(Filter.new() |> Filter.equals("displayName", "Foobar"))

      assert filter == %Filter{
               expr: {:and, {:eq, "userName", "foo"}, {:eq, "displayName", "Foobar"}}
             }
    end

    test "combines expressions with or" do
      filter =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.or1(Filter.new() |> Filter.equals("displayName", "Foobar"))

      assert filter == %Filter{
               expr: {:or, {:eq, "userName", "foo"}, {:eq, "displayName", "Foobar"}}
             }
    end

    test "combines expressions with not" do
      filter =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.not1(Filter.new() |> Filter.equals("displayName", "Foobar"))

      assert filter == %Filter{
               expr: {:not, {:eq, "userName", "foo"}, {:eq, "displayName", "Foobar"}}
             }
    end
  end

  describe "comparison operators" do
    test "equals operator" do
      filter = Filter.new() |> Filter.equals("userName", "foo")
      assert filter.expr == {:eq, "userName", "foo"}
    end

    test "not equal operator" do
      filter = Filter.new() |> Filter.not_equal("userName", "foo")
      assert filter.expr == {:ne, "userName", "foo"}
    end

    test "contains operator" do
      filter = Filter.new() |> Filter.contains("userName", "foo")
      assert filter.expr == {:co, "userName", "foo"}
    end

    test "starts with operator" do
      filter = Filter.new() |> Filter.starts_with("userName", "foo")
      assert filter.expr == {:sw, "userName", "foo"}
    end

    test "ends with operator" do
      filter = Filter.new() |> Filter.ends_with("userName", "foo")
      assert filter.expr == {:ew, "userName", "foo"}
    end

    test "greater than operator" do
      filter = Filter.new() |> Filter.greater_than("age", "25")
      assert filter.expr == {:gt, "age", "25"}
    end

    test "greater or equal operator" do
      filter = Filter.new() |> Filter.greater_or_equal("age", "25")
      assert filter.expr == {:ge, "age", "25"}
    end

    test "less than operator" do
      filter = Filter.new() |> Filter.less_than("age", "25")
      assert filter.expr == {:lt, "age", "25"}
    end

    test "less or equal operator" do
      filter = Filter.new() |> Filter.less_or_equal("age", "25")
      assert filter.expr == {:le, "age", "25"}
    end

    test "present operator" do
      filter = Filter.new() |> Filter.present("userName", nil)
      assert filter.expr == {:pr, "userName", nil}
    end
  end

  describe "filter rendering" do
    test "renders empty filter" do
      assert Filter.new() |> Filter.build() == ""
    end

    test "renders equals comparison" do
      result =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.build()

      assert result == ~S|userName eq "foo"|
    end

    test "renders not equal comparison" do
      result =
        Filter.new()
        |> Filter.not_equal("userName", "foo")
        |> Filter.build()

      assert result == ~S|userName ne "foo"|
    end

    test "renders contains comparison" do
      result =
        Filter.new()
        |> Filter.contains("userName", "foo")
        |> Filter.build()

      assert result == ~S|userName co "foo"|
    end

    test "renders starts with comparison" do
      result =
        Filter.new()
        |> Filter.starts_with("userName", "foo")
        |> Filter.build()

      assert result == ~S|userName sw "foo"|
    end

    test "renders ends with comparison" do
      result =
        Filter.new()
        |> Filter.ends_with("userName", "foo")
        |> Filter.build()

      assert result == ~S|userName ew "foo"|
    end

    test "renders greater than comparison" do
      result =
        Filter.new()
        |> Filter.greater_than("age", "25")
        |> Filter.build()

      assert result == ~S|age gt "25"|
    end

    test "renders greater or equal comparison" do
      result =
        Filter.new()
        |> Filter.greater_or_equal("age", "25")
        |> Filter.build()

      assert result == ~S|age ge "25"|
    end

    test "renders less than comparison" do
      result =
        Filter.new()
        |> Filter.less_than("age", "25")
        |> Filter.build()

      assert result == ~S|age lt "25"|
    end

    test "renders less or equal comparison" do
      result =
        Filter.new()
        |> Filter.less_or_equal("age", "25")
        |> Filter.build()

      assert result == ~S|age le "25"|
    end

    test "renders present comparison" do
      result =
        Filter.new()
        |> Filter.present("userName", nil)
        |> Filter.build()

      assert result == "userName pr"
    end

    test "renders and operation" do
      result =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.and1(Filter.new() |> Filter.equals("displayName", "Foobar"))
        |> Filter.build()

      assert result == ~S|(userName eq "foo") and (displayName eq "Foobar")|
    end

    test "renders or operation" do
      result =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.or1(Filter.new() |> Filter.equals("displayName", "Foobar"))
        |> Filter.build()

      assert result == ~S|(userName eq "foo") or (displayName eq "Foobar")|
    end

    test "renders not operation" do
      result =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.not1(Filter.new() |> Filter.equals("displayName", "Foobar"))
        |> Filter.build()

      assert result == ~S|(userName eq "foo") not (displayName eq "Foobar")|
    end

    test "renders complex nested operations" do
      result =
        Filter.new()
        |> Filter.equals("userName", "foo")
        |> Filter.and1(
          Filter.new()
          |> Filter.contains("displayName", "bar")
          |> Filter.or1(Filter.new() |> Filter.greater_than("age", "18"))
        )
        |> Filter.build()

      assert result == ~S|(userName eq "foo") and ((displayName co "bar") or (age gt "18"))|
    end

    test "renders multiple nested and/or operations" do
      result =
        Filter.new()
        |> Filter.equals("active", "true")
        |> Filter.and1(
          Filter.new()
          |> Filter.starts_with("userName", "admin")
          |> Filter.or1(Filter.new() |> Filter.ends_with("email", "@company.com"))
        )
        |> Filter.and1(Filter.new() |> Filter.present("lastLogin", nil))
        |> Filter.build()

      assert result ==
               ~S|((active eq "true") and ((userName sw "admin") or (email ew "@company.com"))) and (lastLogin pr)|
    end
  end
end
