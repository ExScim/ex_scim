defmodule ExScimEcto.FieldMappingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for the field_mapping functionality in the storage adapter.
  """

  defp field_mapping do
    %{
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
    }
  end

  defp multi_mapping do
    %{
      active:
        {:status,
         fn
           true -> "active"
           false -> "inactive"
         end,
         fn
           "active" -> true
           _ -> false
         end},
      role:
        {:role_code,
         fn
           :admin -> 1
           :user -> 2
         end,
         fn
           1 -> :admin
           _ -> :user
         end}
    }
  end

  # Replicate the to_storage logic for unit testing
  defp apply_to_storage(attrs, field_mapping) when map_size(field_mapping) == 0, do: attrs

  defp apply_to_storage(attrs, field_mapping) do
    Enum.reduce(field_mapping, attrs, fn {domain_key, {db_key, to_fn, _from_fn}}, acc ->
      case Map.pop(acc, domain_key) do
        {nil, acc} -> acc
        {value, acc} -> Map.put(acc, db_key, to_fn.(value))
      end
    end)
  end

  # Replicate the from_storage logic for unit testing
  defp apply_from_storage(record, field_mapping) when map_size(field_mapping) == 0, do: record

  defp apply_from_storage(record, field_mapping) do
    map =
      if is_struct(record),
        do: record |> Map.from_struct() |> Map.drop([:__meta__]),
        else: record

    Enum.reduce(field_mapping, map, fn {domain_key, {db_key, _to_fn, from_fn}}, acc ->
      case Map.pop(acc, db_key) do
        {nil, acc} -> acc
        {value, acc} -> Map.put(acc, domain_key, from_fn.(value))
      end
    end)
  end

  describe "apply_field_mapping_to_storage" do
    test "transforms domain field to db field with value transformation" do
      attrs = %{active: true, user_name: "john"}
      result = apply_to_storage(attrs, field_mapping())

      assert result == %{status: "active", user_name: "john"}
    end

    test "transforms false value" do
      attrs = %{active: false, user_name: "john"}
      result = apply_to_storage(attrs, field_mapping())

      assert result == %{status: "inactive", user_name: "john"}
    end

    test "ignores attrs without a mapping entry" do
      attrs = %{user_name: "john", given_name: "John"}
      result = apply_to_storage(attrs, field_mapping())

      assert result == %{user_name: "john", given_name: "John"}
    end

    test "handles missing domain key in attrs gracefully" do
      attrs = %{user_name: "john"}
      result = apply_to_storage(attrs, field_mapping())

      assert result == %{user_name: "john"}
    end

    test "no-ops with empty field_mapping" do
      attrs = %{active: true, user_name: "john"}
      result = apply_to_storage(attrs, %{})

      assert result == %{active: true, user_name: "john"}
    end
  end

  describe "apply_field_mapping_from_storage" do
    test "transforms db field to domain field with reverse value transformation" do
      record = %{status: "active", user_name: "john", id: 1}
      result = apply_from_storage(record, field_mapping())

      assert result == %{active: true, user_name: "john", id: 1}
    end

    test "transforms inactive status to false" do
      record = %{status: "inactive", user_name: "john", id: 1}
      result = apply_from_storage(record, field_mapping())

      assert result == %{active: false, user_name: "john", id: 1}
    end

    test "handles unknown status value via catch-all" do
      record = %{status: "suspended", user_name: "john", id: 1}
      result = apply_from_storage(record, field_mapping())

      assert result == %{active: false, user_name: "john", id: 1}
    end

    test "ignores records without the db key" do
      record = %{user_name: "john", id: 1}
      result = apply_from_storage(record, field_mapping())

      assert result == %{user_name: "john", id: 1}
    end

    test "no-ops with empty field_mapping" do
      record = %{status: "active", user_name: "john"}
      result = apply_from_storage(record, %{})

      assert result == %{status: "active", user_name: "john"}
    end
  end

  describe "round-trip" do
    test "to_storage then from_storage preserves domain value" do
      original = %{active: true, user_name: "john"}

      stored = apply_to_storage(original, field_mapping())
      assert stored == %{status: "active", user_name: "john"}

      restored = apply_from_storage(stored, field_mapping())
      assert restored == %{active: true, user_name: "john"}
    end

    test "round-trip with false value" do
      original = %{active: false, user_name: "jane"}

      stored = apply_to_storage(original, field_mapping())
      assert stored == %{status: "inactive", user_name: "jane"}

      restored = apply_from_storage(stored, field_mapping())
      assert restored == %{active: false, user_name: "jane"}
    end
  end

  describe "multiple field mappings" do
    test "to_storage transforms multiple fields" do
      attrs = %{active: true, role: :admin, user_name: "john"}
      result = apply_to_storage(attrs, multi_mapping())

      assert result == %{status: "active", role_code: 1, user_name: "john"}
    end

    test "from_storage transforms multiple fields" do
      record = %{status: "inactive", role_code: 2, user_name: "john"}
      result = apply_from_storage(record, multi_mapping())

      assert result == %{active: false, role: :user, user_name: "john"}
    end
  end
end
