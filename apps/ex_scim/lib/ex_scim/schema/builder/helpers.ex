defmodule ExScim.Schema.Builder.Helpers do
  @moduledoc """
  Pure functions for building SCIM schema maps.

  These helpers convert DSL attribute definitions into RFC 7643-compliant
  schema map structures.
  """

  import ExScim.Config

  @doc """
  Builds the complete schema map from DSL-collected data.
  """
  @spec build_schema(String.t(), String.t(), String.t(), list(map())) :: map()
  def build_schema(schema_id, name, description, attributes) do
    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Schema"],
      "id" => schema_id,
      "name" => name,
      "description" => description,
      "attributes" => attributes,
      "meta" => %{
        "resourceType" => "Schema",
        "location" => "#{base_url()}/scim/v2/Schemas/#{schema_id}"
      }
    }
  end

  @doc """
  Builds an attribute map from DSL options.

  The key presence varies by type to match existing schema behavior:
  - string: includes caseExact and uniqueness
  - boolean: no caseExact, uniqueness optional (only if explicitly provided)
  - complex: includes subAttributes, mutability, returned, uniqueness
  - reference: includes referenceTypes, caseExact, uniqueness
  """
  @spec build_attribute(atom(), atom(), keyword(), list(map()) | nil) :: map()
  def build_attribute(name, type, opts, sub_attributes \\ nil) do
    base = %{
      "name" => to_string(name),
      "type" => type_to_string(type),
      "multiValued" => Keyword.get(opts, :multi_valued, false),
      "description" => Keyword.get(opts, :description, ""),
      "required" => Keyword.get(opts, :required, false)
    }

    base
    |> maybe_add_sub_attributes(type, sub_attributes)
    |> maybe_add_reference_types(type, opts)
    |> maybe_add_case_exact(type, opts)
    |> maybe_add_canonical_values(opts)
    |> add_mutability(opts)
    |> add_returned(opts)
    |> maybe_add_uniqueness(type, opts)
  end

  @doc """
  Builds a sub-attribute map (used inside complex attributes).
  """
  @spec build_sub_attribute(atom() | String.t(), atom(), keyword()) :: map()
  def build_sub_attribute(name, type, opts) do
    base = %{
      "name" => to_string(name),
      "type" => type_to_string(type),
      "multiValued" => Keyword.get(opts, :multi_valued, false),
      "description" => Keyword.get(opts, :description, ""),
      "required" => Keyword.get(opts, :required, false)
    }

    base
    |> maybe_add_reference_types(type, opts)
    |> maybe_add_case_exact(type, opts)
    |> maybe_add_canonical_values(opts)
    |> add_mutability(opts)
    |> add_returned(opts)
    |> maybe_add_uniqueness(type, opts)
  end

  # Type conversion: atoms to SCIM type strings
  defp type_to_string(:string), do: "string"
  defp type_to_string(:boolean), do: "boolean"
  defp type_to_string(:complex), do: "complex"
  defp type_to_string(:reference), do: "reference"
  defp type_to_string(:date_time), do: "dateTime"
  defp type_to_string(:binary), do: "binary"
  defp type_to_string(:integer), do: "integer"
  defp type_to_string(:decimal), do: "decimal"
  defp type_to_string(other) when is_atom(other), do: Atom.to_string(other)

  # Mutability conversion: atoms to SCIM strings
  defp mutability_to_string(:read_write), do: "readWrite"
  defp mutability_to_string(:read_only), do: "readOnly"
  defp mutability_to_string(:write_only), do: "writeOnly"
  defp mutability_to_string(:immutable), do: "immutable"
  defp mutability_to_string(other) when is_atom(other), do: Atom.to_string(other)

  # Returned conversion: atoms to SCIM strings
  defp returned_to_string(:default), do: "default"
  defp returned_to_string(:always), do: "always"
  defp returned_to_string(:never), do: "never"
  defp returned_to_string(:request), do: "request"
  defp returned_to_string(other) when is_atom(other), do: Atom.to_string(other)

  # Uniqueness conversion: atoms to SCIM strings
  defp uniqueness_to_string(:none), do: "none"
  defp uniqueness_to_string(:server), do: "server"
  defp uniqueness_to_string(:global), do: "global"
  defp uniqueness_to_string(other) when is_atom(other), do: Atom.to_string(other)

  # Add subAttributes for complex types
  defp maybe_add_sub_attributes(map, :complex, sub_attributes) when is_list(sub_attributes) do
    Map.put(map, "subAttributes", sub_attributes)
  end

  defp maybe_add_sub_attributes(map, _type, _sub_attributes), do: map

  # Add referenceTypes for reference types
  defp maybe_add_reference_types(map, :reference, opts) do
    case Keyword.get(opts, :reference_types) do
      nil -> map
      types -> Map.put(map, "referenceTypes", types)
    end
  end

  defp maybe_add_reference_types(map, _type, _opts), do: map

  # Add caseExact for string and reference types (not boolean)
  defp maybe_add_case_exact(map, type, opts) when type in [:string, :reference] do
    Map.put(map, "caseExact", Keyword.get(opts, :case_exact, false))
  end

  defp maybe_add_case_exact(map, _type, _opts), do: map

  # Add canonicalValues if provided
  defp maybe_add_canonical_values(map, opts) do
    case Keyword.get(opts, :canonical_values) do
      nil -> map
      values -> Map.put(map, "canonicalValues", values)
    end
  end

  # Always add mutability
  defp add_mutability(map, opts) do
    mutability = Keyword.get(opts, :mutability, :read_write)
    Map.put(map, "mutability", mutability_to_string(mutability))
  end

  # Always add returned
  defp add_returned(map, opts) do
    returned = Keyword.get(opts, :returned, :default)
    Map.put(map, "returned", returned_to_string(returned))
  end

  # Add uniqueness based on type and options
  # - For boolean type at top-level without explicit uniqueness: omit the key
  # - For boolean sub-attributes: include uniqueness
  # - For all other types: always include uniqueness
  defp maybe_add_uniqueness(map, :boolean, opts) do
    # For boolean, only include uniqueness if explicitly provided
    # or if it's a sub-attribute (has :include_uniqueness flag)
    cond do
      Keyword.has_key?(opts, :uniqueness) ->
        Map.put(map, "uniqueness", uniqueness_to_string(Keyword.get(opts, :uniqueness)))

      Keyword.get(opts, :include_uniqueness, false) ->
        Map.put(map, "uniqueness", uniqueness_to_string(:none))

      true ->
        map
    end
  end

  defp maybe_add_uniqueness(map, _type, opts) do
    uniqueness = Keyword.get(opts, :uniqueness, :none)
    Map.put(map, "uniqueness", uniqueness_to_string(uniqueness))
  end
end
