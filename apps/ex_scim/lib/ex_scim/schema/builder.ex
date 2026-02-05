defmodule ExScim.Schema.Builder do
  @moduledoc """
  DSL for defining SCIM schemas declaratively.

  This module provides macros for building RFC 7643-compliant SCIM schema
  definitions in a clean, readable format.

  ## Example

      defmodule MyApp.Schemas.User do
        use ExScim.Schema.Builder

        schema "urn:ietf:params:scim:schemas:core:2.0:User" do
          name "User"
          description "User Account"

          attribute :userName, :string, required: true, uniqueness: :server
          attribute :active, :boolean

          attribute :name, :complex do
            sub_attribute :givenName, :string
            sub_attribute :familyName, :string
          end

          attribute :emails, :complex, multi_valued: true do
            sub_attribute :value, :string
            sub_attribute :type, :string, canonical_values: ["work", "home", "other"]
            sub_attribute :primary, :boolean
          end
        end
      end

  ## Generated Functions

  Using this module generates the following functions:

  - `schema_id/0` - Returns the schema URI
  - `to_map/0` - Returns the complete schema as a map
  - `__schema__/0` - Returns schema metadata (for internal use)
  """

  alias ExScim.Schema.Builder.Helpers

  @doc false
  defmacro __using__(_opts) do
    quote do
      import ExScim.Schema.Builder,
        only: [
          schema: 2,
          name: 1,
          description: 1,
          attribute: 2,
          attribute: 3,
          attribute: 4,
          sub_attribute: 2,
          sub_attribute: 3
        ]

      Module.register_attribute(__MODULE__, :schema_id, accumulate: false)
      Module.register_attribute(__MODULE__, :schema_name, accumulate: false)
      Module.register_attribute(__MODULE__, :schema_description, accumulate: false)
      Module.register_attribute(__MODULE__, :schema_attributes, accumulate: true)

      @before_compile ExScim.Schema.Builder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    schema_id = Module.get_attribute(env.module, :schema_id)
    schema_name = Module.get_attribute(env.module, :schema_name) || ""
    schema_description = Module.get_attribute(env.module, :schema_description) || ""
    # Attributes are accumulated in reverse order
    attributes = Module.get_attribute(env.module, :schema_attributes) |> Enum.reverse()

    quote do
      @doc "Returns the schema URI identifier."
      @spec schema_id() :: String.t()
      def schema_id, do: unquote(schema_id)

      @doc "Returns the complete schema as an RFC 7643-compliant map."
      @spec to_map() :: map()
      def to_map do
        ExScim.Schema.Builder.Helpers.build_schema(
          unquote(schema_id),
          unquote(schema_name),
          unquote(schema_description),
          unquote(Macro.escape(attributes))
        )
      end

      @doc false
      def __schema__ do
        %{
          id: unquote(schema_id),
          name: unquote(schema_name),
          description: unquote(schema_description),
          attributes: unquote(Macro.escape(attributes))
        }
      end
    end
  end

  @doc """
  Defines a SCIM schema with the given URI identifier.

  The block should contain `name/1`, `description/1`, and `attribute` calls.

  ## Example

      schema "urn:ietf:params:scim:schemas:core:2.0:User" do
        name "User"
        description "User Account"
        # attributes...
      end
  """
  defmacro schema(schema_id, do: block) do
    quote do
      @schema_id unquote(schema_id)
      unquote(block)
    end
  end

  @doc """
  Sets the human-readable name for the schema.
  """
  defmacro name(value) do
    quote do
      @schema_name unquote(value)
    end
  end

  @doc """
  Sets the description for the schema.
  """
  defmacro description(value) do
    quote do
      @schema_description unquote(value)
    end
  end

  @doc """
  Defines a simple attribute with name and type.

  ## Example

      attribute :active, :boolean
  """
  defmacro attribute(name, type) do
    quote do
      @schema_attributes Helpers.build_attribute(unquote(name), unquote(type), [])
    end
  end

  @doc """
  Defines an attribute with options, or a complex attribute with sub-attributes.

  ## Simple attribute with options

      attribute :userName, :string, required: true, uniqueness: :server

  ## Complex attribute with sub-attributes

      attribute :name, :complex do
        sub_attribute :givenName, :string
        sub_attribute :familyName, :string
      end

  ## Options

  - `:required` - boolean, default `false`
  - `:multi_valued` - boolean, default `false`
  - `:case_exact` - boolean, default `false` (only for string/reference types)
  - `:mutability` - atom, one of `:read_write`, `:read_only`, `:write_only`, `:immutable`
  - `:returned` - atom, one of `:default`, `:always`, `:never`, `:request`
  - `:uniqueness` - atom, one of `:none`, `:server`, `:global`
  - `:canonical_values` - list of strings
  - `:reference_types` - list of strings (only for reference type)
  - `:description` - string
  """
  defmacro attribute(name, type, opts_or_block)

  defmacro attribute(name, type, do: block) do
    quote do
      @__current_sub_attributes []
      unquote(block)
      sub_attrs = @__current_sub_attributes |> Enum.reverse()
      @schema_attributes Helpers.build_attribute(unquote(name), unquote(type), [], sub_attrs)
    end
  end

  defmacro attribute(name, type, opts) when is_list(opts) do
    quote do
      @schema_attributes Helpers.build_attribute(unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc """
  Defines a complex attribute with both options and sub-attributes.

  ## Example

      attribute :emails, :complex, multi_valued: true do
        sub_attribute :value, :string
        sub_attribute :type, :string, canonical_values: ["work", "home", "other"]
        sub_attribute :primary, :boolean
      end
  """
  defmacro attribute(name, type, opts, do: block) do
    quote do
      @__current_sub_attributes []
      unquote(block)
      sub_attrs = @__current_sub_attributes |> Enum.reverse()
      @schema_attributes Helpers.build_attribute(unquote(name), unquote(type), unquote(opts), sub_attrs)
    end
  end

  @doc """
  Defines a sub-attribute within a complex attribute block.

  Must be called inside an `attribute ... do ... end` block.

  ## Example

      attribute :name, :complex do
        sub_attribute :givenName, :string
        sub_attribute :familyName, :string, description: "The family name"
      end

  ## Options

  Same options as `attribute/3`, with the addition of `:include_uniqueness`
  which forces uniqueness to be included even for boolean types.
  """
  defmacro sub_attribute(name, type, opts \\ []) do
    # Sub-attributes always include uniqueness (even for booleans)
    quote do
      opts_with_uniqueness = Keyword.put_new(unquote(opts), :include_uniqueness, true)

      @__current_sub_attributes [
        Helpers.build_sub_attribute(unquote(name), unquote(type), opts_with_uniqueness)
        | @__current_sub_attributes
      ]
    end
  end
end
