defmodule ExScimClient.DeserializerTest do
  use ExUnit.Case, async: true

  alias ExScimClient.Deserializer

  # Minimal model: a struct with a decode/1 (identity) as the Deserializer expects.
  defmodule TestModel do
    defstruct [:a, :b]
    def decode(value), do: value
  end

  describe "json_decode/1" do
    test "decodes a valid JSON object" do
      assert {:ok, %{"a" => 1}} = Deserializer.json_decode(~s({"a": 1}))
    end

    test "returns an error for invalid JSON" do
      assert {:error, _} = Deserializer.json_decode("{not json")
    end
  end

  describe "json_decode/2" do
    test "decodes JSON into a struct of the given module" do
      assert {:ok, %TestModel{a: 1, b: 2}} =
               Deserializer.json_decode(~s({"a": 1, "b": 2}), TestModel)
    end

    test "propagates a decode error" do
      assert {:error, _} = Deserializer.json_decode("{bad", TestModel)
    end
  end

  describe "deserialize/4 :list" do
    test "maps each element to a struct" do
      model = %{items: [%{"a" => 1}, %{"a" => 2}]}
      result = Deserializer.deserialize(model, :items, :list, TestModel)

      assert [%TestModel{a: 1}, %TestModel{a: 2}] = result.items
    end

    test "passes through a nil field" do
      result = Deserializer.deserialize(%{items: nil}, :items, :list, TestModel)
      assert result.items == nil
    end
  end

  describe "deserialize/4 :struct" do
    test "converts a map value to a struct" do
      result = Deserializer.deserialize(%{nested: %{"a" => 1}}, :nested, :struct, TestModel)
      assert %TestModel{a: 1} = result.nested
    end

    test "passes through a nil field" do
      result = Deserializer.deserialize(%{nested: nil}, :nested, :struct, TestModel)
      assert result.nested == nil
    end

    test "uses the module decode/1 fallback for a scalar value" do
      result = Deserializer.deserialize(%{nested: "scalar"}, :nested, :struct, TestModel)
      assert result.nested == "scalar"
    end
  end

  describe "deserialize/4 :map" do
    test "converts each value in a map to a struct" do
      model = %{by_key: %{"x" => %{"a" => 1}}}
      result = Deserializer.deserialize(model, :by_key, :map, TestModel)

      assert %{"x" => %TestModel{a: 1}} = result.by_key
    end

    test "passes through a nil field" do
      result = Deserializer.deserialize(%{by_key: nil}, :by_key, :map, TestModel)
      assert result.by_key == nil
    end
  end

  describe "deserialize/4 :date" do
    test "parses an ISO 8601 date string" do
      result = Deserializer.deserialize(%{d: "2024-01-15"}, :d, :date, nil)
      assert result.d == ~D[2024-01-15]
    end

    test "leaves an invalid date string unchanged" do
      result = Deserializer.deserialize(%{d: "not-a-date"}, :d, :date, nil)
      assert result.d == "not-a-date"
    end

    test "leaves a non-binary value unchanged" do
      result = Deserializer.deserialize(%{d: nil}, :d, :date, nil)
      assert result.d == nil
    end
  end

  describe "deserialize/4 :datetime" do
    test "parses an ISO 8601 datetime string" do
      result = Deserializer.deserialize(%{dt: "2024-01-15T10:00:00Z"}, :dt, :datetime, nil)
      assert %DateTime{} = result.dt
    end

    test "leaves an invalid datetime string unchanged" do
      result = Deserializer.deserialize(%{dt: "nope"}, :dt, :datetime, nil)
      assert result.dt == "nope"
    end

    test "leaves a non-binary value unchanged" do
      result = Deserializer.deserialize(%{dt: 123}, :dt, :datetime, nil)
      assert result.dt == 123
    end
  end
end
