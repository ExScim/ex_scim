defmodule ExScim.Groups.Mapper.Adapter do
  @moduledoc "Group resource mapper behaviour."

  @typedoc "A domain group struct or map."
  @type group_struct :: struct() | map()

  @typedoc "A SCIM group resource as a JSON-decoded map."
  @type scim_data :: map()

  @doc "Converts a SCIM JSON map into a domain group struct."
  @callback from_scim(scim_data(), ExScim.Scope.t()) ::
              {:ok, group_struct()} | {:error, atom() | term()}

  @doc "Converts a domain group struct into a SCIM JSON map."
  @callback to_scim(group_struct(), ExScim.Scope.t(), keyword()) ::
              {:ok, scim_data()} | {:error, atom() | term()}

  @doc "Extracts the creation timestamp from a group struct. Used for SCIM `meta.created`."
  @callback get_meta_created(group_struct()) :: DateTime.t() | nil

  @doc "Extracts the last-modified timestamp from a group struct. Used for SCIM `meta.lastModified`."
  @callback get_meta_last_modified(group_struct()) :: DateTime.t() | nil

  @doc "Computes an ETag version string from a group struct. Used for SCIM `meta.version`."
  @callback get_meta_version(group_struct()) :: String.t() | nil

  @doc "Builds the complete SCIM `meta` object for a group. Receives the struct and options like `:location` and `:resource_type`."
  @callback format_meta(group_struct(), keyword()) :: map()

  @optional_callbacks [
    get_meta_created: 1,
    get_meta_last_modified: 1,
    get_meta_version: 1,
    format_meta: 2
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour ExScim.Groups.Mapper.Adapter

      alias ExScim.Resources.Metadata

      @impl true
      def get_meta_created(resource), do: Map.get(resource, :meta_created)

      @impl true
      def get_meta_last_modified(resource), do: Map.get(resource, :meta_last_modified)

      @impl true
      def get_meta_version(resource) do
        Metadata.compute_version(
          Map.get(resource, :meta_version),
          get_meta_last_modified(resource)
        )
      end

      @impl true
      def format_meta(resource, opts) do
        Metadata.build_meta(
          get_meta_created(resource),
          get_meta_last_modified(resource),
          get_meta_version(resource),
          Keyword.get(opts, :location),
          Keyword.get(opts, :resource_type, "Group")
        )
      end

      @doc false
      def format_datetime(value), do: Metadata.format_datetime(value)

      @doc false
      def parse_datetime(value), do: Metadata.parse_datetime(value)

      defoverridable get_meta_created: 1,
                     get_meta_last_modified: 1,
                     get_meta_version: 1,
                     format_meta: 2
    end
  end
end
