defmodule ExScimEcto.QueryFilterTest do
  use ExUnit.Case, async: true

  alias ExScimEcto.QueryFilter
  import Ecto.Query

  # Minimal test schemas (no database needed, only inspect the Ecto.Query struct).

  defmodule UserEmail do
    use Ecto.Schema

    schema "user_emails" do
      field(:default_value, :string)
      field(:type, :string)
      belongs_to(:user, ExScimEcto.QueryFilterTest.User)
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field(:user_name, :string)
      field(:given_name, :string)
      field(:family_name, :string)
      field(:active, :boolean)
      field(:status, :string)
      has_many(:user_emails, ExScimEcto.QueryFilterTest.UserEmail)
    end
  end

  @assoc_opts [
    filter_mapping: %{
      "emails.value" => {:assoc, :user_emails, :default_value},
      "emails.type" => {:assoc, :user_emails, :type},
      "name.givenName" => :given_name
    }
  ]

  @atom_opts [
    filter_mapping: %{
      "name.givenName" => :given_name,
      "name.familyName" => :family_name
    }
  ]

  defp field_mapping_opts do
    [
      field_mapping: %{
        active:
          {:status,
           fn
             true -> "active"
             false -> "inactive"
           end,
           fn
             "active" -> true
             _ -> false
           end}
      },
      schema_fields: User.__schema__(:fields)
    ]
  end

  defp filter_and_field_mapping_opts do
    [
      filter_mapping: %{
        "name.givenName" => :given_name
      },
      field_mapping: %{
        active:
          {:status,
           fn
             true -> "active"
             false -> "inactive"
           end,
           fn
             "active" -> true
             _ -> false
           end}
      },
      schema_fields: User.__schema__(:fields)
    ]
  end

  defp base_query, do: from(u in User)

  # Helper to extract join info from an Ecto.Query
  defp join_count(query), do: length(query.joins)

  defp has_join_on?(query, assoc_name) do
    Enum.any?(query.joins, fn %{as: as} -> as == assoc_name end)
  end

  defp has_distinct?(query), do: query.distinct != nil

  # 1. Simple atom mapping still works (no joins added)

  describe "atom field mapping" do
    test "eq with atom mapping produces no joins" do
      ast = {:eq, "name.givenName", "John"}
      query = QueryFilter.apply_filter(base_query(), ast, @atom_opts)

      assert join_count(query) == 0
      refute has_distinct?(query)
    end

    test "2-arity apply_filter still works" do
      # Ensure atom_to_existing_atom path works
      ast = {:eq, "user_name", "john"}
      query = QueryFilter.apply_filter(base_query(), ast)

      assert join_count(query) == 0
    end
  end

  # 2. Association mapping adds named LEFT JOIN and filters on association field

  describe "association field mapping" do
    test "eq on association adds a named left join" do
      ast = {:eq, "emails.value", "john@example.com"}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_join_on?(query, :user_emails)
    end

    test "join is a left join" do
      ast = {:eq, "emails.value", "john@example.com"}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      [join] = query.joins
      assert join.qual == :left
    end
  end

  # 3. distinct: true added only when associations are joined

  describe "distinct behavior" do
    test "distinct added when association join present" do
      ast = {:eq, "emails.value", "john@example.com"}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert has_distinct?(query)
    end

    test "distinct not added for atom-only filters" do
      ast = {:eq, "name.givenName", "John"}
      query = QueryFilter.apply_filter(base_query(), ast, @atom_opts)

      refute has_distinct?(query)
    end
  end

  # 4. Two filters on same association produce only one join

  describe "join deduplication" do
    test "and with two filters on same association produces one join" do
      ast = {:and, {:eq, "emails.value", "john@example.com"}, {:eq, "emails.type", "work"}}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_join_on?(query, :user_emails)
    end
  end

  # 5. Mixed local + association filters

  describe "mixed local and association filters" do
    test "and with local and association filter" do
      ast = {:and, {:eq, "name.givenName", "John"}, {:eq, "emails.value", "john@example.com"}}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_join_on?(query, :user_emails)
      assert has_distinct?(query)
    end

    test "or with local and association filter" do
      ast = {:or, {:eq, "name.givenName", "John"}, {:eq, "emails.value", "john@example.com"}}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_distinct?(query)
    end
  end

  # 6. All 10 operators work with association refs

  describe "all operators with association refs" do
    for op <- [:eq, :ne, :gt, :ge, :lt, :le] do
      test "#{op} works with association field" do
        ast = {unquote(op), "emails.value", "test"}
        query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

        assert join_count(query) == 1
        assert has_join_on?(query, :user_emails)
      end
    end

    for op <- [:co, :sw, :ew] do
      test "#{op} works with association field" do
        ast = {unquote(op), "emails.value", "test"}
        query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

        assert join_count(query) == 1
        assert has_join_on?(query, :user_emails)
      end
    end

    test "pr works with association field" do
      ast = {:pr, "emails.value"}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_join_on?(query, :user_emails)
    end
  end

  # 7. nil AST returns query unchanged

  describe "nil AST" do
    test "apply_filter/2 with nil returns query unchanged" do
      query = base_query()
      assert QueryFilter.apply_filter(query, nil) == query
    end

    test "apply_filter/3 with nil returns query unchanged" do
      query = base_query()
      assert QueryFilter.apply_filter(query, nil, @assoc_opts) == query
    end
  end

  # 8. Pre-existing named binding is not duplicated

  describe "pre-existing binding" do
    test "does not duplicate join when binding already exists" do
      pre_joined =
        from(u in User,
          left_join: ue in assoc(u, :user_emails),
          as: :user_emails
        )

      ast = {:eq, "emails.value", "john@example.com"}
      query = QueryFilter.apply_filter(pre_joined, ast, @assoc_opts)

      assert join_count(query) == 1
    end
  end

  # 9. :not wrapping an association filter

  describe "not operator" do
    test "not wrapping association filter works" do
      ast = {:not, {:eq, "emails.value", "john@example.com"}}
      query = QueryFilter.apply_filter(base_query(), ast, @assoc_opts)

      assert join_count(query) == 1
      assert has_join_on?(query, :user_emails)
      assert has_distinct?(query)
    end

    test "not wrapping local filter works" do
      ast = {:not, {:eq, "name.givenName", "John"}}
      query = QueryFilter.apply_filter(base_query(), ast, @atom_opts)

      assert join_count(query) == 0
      refute has_distinct?(query)
    end
  end

  # 10. field_mapping transforms values and renames fields

  describe "field_mapping value transformation" do
    test "eq with field_mapping transforms value and uses db field" do
      ast = {:eq, "active", true}
      query = QueryFilter.apply_filter(base_query(), ast, field_mapping_opts())

      assert join_count(query) == 0
      refute has_distinct?(query)
      # The query should use :status field with "active" value
      assert inspect(query.wheres) =~ "status"
    end

    test "ne with field_mapping transforms value" do
      ast = {:ne, "active", true}
      query = QueryFilter.apply_filter(base_query(), ast, field_mapping_opts())

      assert join_count(query) == 0
      assert inspect(query.wheres) =~ "status"
    end

    test "pr with field_mapping uses db field without transforming value" do
      ast = {:pr, "active"}
      query = QueryFilter.apply_filter(base_query(), ast, field_mapping_opts())

      assert join_count(query) == 0
      assert inspect(query.wheres) =~ "status"
    end

    test "co with field_mapping transforms value" do
      ast = {:co, "active", true}
      query = QueryFilter.apply_filter(base_query(), ast, field_mapping_opts())

      assert join_count(query) == 0
      assert inspect(query.wheres) =~ "status"
    end

    test "field_mapping does not add joins or distinct" do
      ast = {:eq, "active", false}
      query = QueryFilter.apply_filter(base_query(), ast, field_mapping_opts())

      assert join_count(query) == 0
      refute has_distinct?(query)
    end
  end

  # 11. filter_mapping and field_mapping work together

  describe "filter_mapping and field_mapping interaction" do
    test "filter_mapping resolves path, field_mapping not applied to filter_mapping result" do
      # "name.givenName" is resolved by filter_mapping to :given_name
      # :given_name has no field_mapping entry, so it stays as-is
      ast = {:eq, "name.givenName", "John"}
      query = QueryFilter.apply_filter(base_query(), ast, filter_and_field_mapping_opts())

      assert join_count(query) == 0
      assert inspect(query.wheres) =~ "given_name"
    end

    test "field_mapping works alongside filter_mapping for different fields" do
      ast = {:and, {:eq, "name.givenName", "John"}, {:eq, "active", true}}
      query = QueryFilter.apply_filter(base_query(), ast, filter_and_field_mapping_opts())

      assert join_count(query) == 0
      wheres = inspect(query.wheres)
      assert wheres =~ "given_name"
      assert wheres =~ "status"
    end
  end
end
