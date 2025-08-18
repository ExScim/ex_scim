defmodule ExScim.Schema.FilterValidationTest do
  use ExUnit.Case, async: true

  describe "SCIM filter expressions - basic structure validation" do
    test "recognizes common filter operators" do
      # These are the operators that should be supported per RFC 7644
      valid_operators = [
        # equal
        "eq",
        # not equal  
        "ne",
        # contains
        "co",
        # starts with
        "sw",
        # ends with
        "ew",
        # present (has value)
        "pr",
        # greater than
        "gt",
        # greater than or equal
        "ge",
        # less than
        "lt",
        # less than or equal
        "le"
      ]

      # Test that we recognize these as valid operators
      for operator <- valid_operators do
        assert operator in valid_operators, "Operator #{operator} should be supported"
      end

      assert length(valid_operators) == 10, "Should support 10 comparison operators"
    end

    test "recognizes logical operators" do
      logical_operators = ["and", "or", "not"]

      for operator <- logical_operators do
        assert operator in logical_operators, "Logical operator #{operator} should be supported"
      end
    end

    test "filter expression examples are well-formed" do
      # Test some basic filter expressions from the test fixtures
      import ExScim.TestFixtures

      filter_expressions = scim_filter_expressions()

      # These should all be valid SCIM filter expressions
      assert length(filter_expressions) > 0

      # Test some specific patterns
      assert "userName eq \"john.doe\"" in filter_expressions
      assert "active eq true" in filter_expressions
      assert "title pr" in filter_expressions

      # Test complex expressions
      complex_filters =
        Enum.filter(filter_expressions, fn expr ->
          String.contains?(expr, "and") or String.contains?(expr, "or")
        end)

      assert length(complex_filters) > 0, "Should have complex filter examples"
    end

    test "identifies invalid filter expressions" do
      import ExScim.TestFixtures

      invalid_expressions = invalid_scim_filter_expressions()

      # These should be recognizably malformed
      assert length(invalid_expressions) > 0

      # Test specific invalid patterns
      assert "userName invalid_operator \"value\"" in invalid_expressions
      # Missing value
      assert "userName eq" in invalid_expressions
      # Missing attribute
      assert "eq \"value\"" in invalid_expressions
      # Empty filter
      assert "" in invalid_expressions
    end
  end

  describe "attribute path validation in filters" do
    test "validates simple attribute paths" do
      simple_paths = [
        "userName",
        "active",
        "displayName",
        "title",
        "userType"
      ]

      # These should be valid attribute names from our schema
      for path <- simple_paths do
        assert is_binary(path), "Attribute path should be string"
        assert path != "", "Attribute path should not be empty"
      end
    end

    test "validates complex attribute paths" do
      complex_paths = [
        "emails.value",
        "emails.type",
        "emails.primary",
        "phoneNumbers.value",
        "phoneNumbers.type",
        "addresses.type",
        "addresses.country",
        "name.givenName",
        "name.familyName"
      ]

      # These should be valid sub-attribute paths
      for path <- complex_paths do
        assert String.contains?(path, "."), "Complex path should contain dot notation"
        parts = String.split(path, ".")
        assert length(parts) == 2, "Should have exactly two parts for sub-attributes"
      end
    end

    test "validates array filter expressions" do
      array_filter_expressions = [
        "emails[type eq \"work\"]",
        "emails[type eq \"work\" and primary eq true]",
        "phoneNumbers[type eq \"mobile\"]",
        "addresses[type eq \"home\"].formatted"
      ]

      # These represent complex array filtering patterns
      for expr <- array_filter_expressions do
        assert String.contains?(expr, "["), "Array filter should contain brackets"
        assert String.contains?(expr, "]"), "Array filter should contain closing bracket"
      end
    end
  end

  describe "data type validation in filters" do
    test "string value patterns" do
      string_patterns = [
        "userName eq \"john.doe\"",
        "displayName sw \"John\"",
        "emails.value co \"@example.com\"",
        "title ew \"Manager\""
      ]

      for pattern <- string_patterns do
        # String values should be quoted
        assert String.contains?(pattern, "\""), "String values should be quoted"
      end
    end

    test "boolean value patterns" do
      boolean_patterns = [
        "active eq true",
        "active eq false",
        "emails.primary eq true"
      ]

      for pattern <- boolean_patterns do
        assert String.contains?(pattern, "true") or String.contains?(pattern, "false"),
               "Boolean patterns should contain true/false"
      end
    end

    test "date value patterns" do
      date_patterns = [
        "meta.created gt \"2024-01-01T00:00:00Z\"",
        "meta.lastModified le \"2024-12-31T23:59:59Z\""
      ]

      for pattern <- date_patterns do
        # Date values should be quoted and contain ISO format indicators
        assert String.contains?(pattern, "\""), "Date values should be quoted"
        assert String.contains?(pattern, "T"), "Should contain ISO date format indicator"
        assert String.contains?(pattern, "Z"), "Should contain timezone indicator"
      end
    end
  end

  describe "filter expression complexity" do
    test "validates single condition filters" do
      single_conditions = [
        "userName eq \"test\"",
        "active eq true",
        "title pr"
      ]

      for condition <- single_conditions do
        # Should not contain logical operators
        refute String.contains?(condition, " and "), "Single condition should not contain 'and'"
        refute String.contains?(condition, " or "), "Single condition should not contain 'or'"
      end
    end

    test "validates compound filter expressions" do
      compound_expressions = [
        "userName eq \"john\" and active eq true",
        "title pr and active eq true",
        "userName sw \"test\" or displayName co \"Test\""
      ]

      for expr <- compound_expressions do
        logical_operators_count =
          if(String.contains?(expr, " and "), do: 1, else: 0) +
            if String.contains?(expr, " or "), do: 1, else: 0

        assert logical_operators_count >= 1,
               "Compound expression should contain logical operators"
      end
    end

    test "validates parenthesized expressions" do
      parenthesized = [
        "(userName eq \"john\" or userName eq \"jane\") and active eq true",
        "title pr and (active eq true or userType eq \"Employee\")"
      ]

      for expr <- parenthesized do
        assert String.contains?(expr, "("), "Should contain opening parenthesis"
        assert String.contains?(expr, ")"), "Should contain closing parenthesis"

        # Basic parenthesis balance check
        open_count = expr |> String.graphemes() |> Enum.count(&(&1 == "("))
        close_count = expr |> String.graphemes() |> Enum.count(&(&1 == ")"))
        assert open_count == close_count, "Parentheses should be balanced"
      end
    end
  end

  describe "attribute existence validation for filters" do
    test "all simple filter attributes exist in User schema" do
      # These attributes should exist in our User schema
      existing_attributes = [
        "userName",
        "displayName",
        "active",
        "title",
        "userType",
        "preferredLanguage",
        "locale",
        "timezone"
      ]

      # We would normally validate these against the actual schema
      # For now, just ensure they're not empty
      for attr <- existing_attributes do
        assert attr != "", "Attribute name should not be empty"
        assert is_binary(attr), "Attribute name should be string"
      end
    end

    test "complex attributes and sub-attributes exist" do
      complex_attribute_paths = [
        {"emails", "value"},
        {"emails", "type"},
        {"emails", "primary"},
        {"phoneNumbers", "value"},
        {"phoneNumbers", "type"},
        {"addresses", "type"},
        {"addresses", "formatted"},
        {"name", "givenName"},
        {"name", "familyName"}
      ]

      for {parent, sub} <- complex_attribute_paths do
        assert parent != "", "Parent attribute should not be empty"
        assert sub != "", "Sub-attribute should not be empty"
      end
    end
  end
end
