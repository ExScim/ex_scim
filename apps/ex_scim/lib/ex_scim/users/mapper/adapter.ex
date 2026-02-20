defmodule ExScim.Users.Mapper.Adapter do
  @moduledoc "User resource mapper behaviour."

  @typedoc "A domain user struct or map."
  @type user_struct :: struct() | map()

  @typedoc "A SCIM user resource as a JSON-decoded map."
  @type scim_data :: map()

  @doc "Converts a SCIM JSON map into a domain user struct."
  @callback from_scim(scim_data(), ExScim.Scope.t()) ::
              {:ok, user_struct()} | {:error, atom() | term()}

  @doc "Converts a domain user struct into a SCIM JSON map."
  @callback to_scim(user_struct(), ExScim.Scope.t(), keyword()) ::
              {:ok, scim_data()} | {:error, atom() | term()}

  @doc "Extracts the creation timestamp from a user struct. Used for SCIM `meta.created`."
  @callback get_meta_created(user_struct()) :: DateTime.t() | nil

  @doc "Extracts the last-modified timestamp from a user struct. Used for SCIM `meta.lastModified`."
  @callback get_meta_last_modified(user_struct()) :: DateTime.t() | nil

  @doc "Computes an ETag version string from a user struct. Used for SCIM `meta.version`."
  @callback get_meta_version(user_struct()) :: String.t() | nil

  @doc "Builds the complete SCIM `meta` object for a user. Receives the struct and options like `:location` and `:resource_type`."
  @callback format_meta(user_struct(), keyword()) :: map()

  @optional_callbacks [
    get_meta_created: 1,
    get_meta_last_modified: 1,
    get_meta_version: 1,
    format_meta: 2
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour ExScim.Users.Mapper.Adapter

      @impl true
      def get_meta_created(resource) do
        Map.get(resource, :meta_created)
      end

      @impl true
      def get_meta_last_modified(resource) do
        Map.get(resource, :meta_last_modified)
      end

      @impl true
      def get_meta_version(resource) do
        case get_meta_last_modified(resource) do
          %DateTime{} = dt ->
            hash =
              dt
              |> DateTime.to_iso8601()
              |> then(&:crypto.hash(:md5, &1))
              |> Base.encode16(case: :lower)

            "W/\"#{hash}\""

          _ ->
            nil
        end
      end

      @impl true
      def format_meta(resource, opts) do
        location = Keyword.get(opts, :location)
        resource_type = Keyword.get(opts, :resource_type, "User")

        %{
          "resourceType" => resource_type,
          "created" => format_datetime(get_meta_created(resource)),
          "lastModified" => format_datetime(get_meta_last_modified(resource)),
          "location" => location,
          "version" => get_meta_version(resource)
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end

      @doc false
      def format_datetime(nil), do: nil
      def format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
      def format_datetime(binary) when is_binary(binary), do: binary

      @doc false
      def parse_datetime(nil), do: nil
      def parse_datetime(%DateTime{} = dt), do: dt

      def parse_datetime(binary) when is_binary(binary) do
        case DateTime.from_iso8601(binary) do
          {:ok, dt, _offset} -> dt
          {:error, _} -> nil
        end
      end

      defoverridable get_meta_created: 1,
                     get_meta_last_modified: 1,
                     get_meta_version: 1,
                     format_meta: 2
    end
  end
end
