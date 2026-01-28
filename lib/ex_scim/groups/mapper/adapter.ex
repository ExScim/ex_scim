defmodule ExScim.Groups.Mapper.Adapter do
  @moduledoc "Group resource mapper behaviour."

  @type group_struct :: struct() | map()
  @type scim_data :: map()

  @callback from_scim(scim_data()) :: group_struct()
  @callback to_scim(group_struct(), keyword()) :: scim_data()

  @callback get_meta_created(group_struct()) :: DateTime.t() | nil
  @callback get_meta_last_modified(group_struct()) :: DateTime.t() | nil
  @callback get_meta_version(group_struct()) :: String.t() | nil
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
        resource_type = Keyword.get(opts, :resource_type, "Group")

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
