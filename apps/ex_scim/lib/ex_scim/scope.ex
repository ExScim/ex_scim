defmodule ExScim.Scope do
  @moduledoc """
  Represents the scope of a SCIM request: identity, authorization, and tenant context.

  When `tenant_id` is `nil`, the system behaves as single-tenant (no isolation).

  ## Authorization Scopes

  The following standard scopes are enforced by `ExScimPhoenix`:

  | Scope | Endpoints | Actions |
  |---|---|---|
  | `scim:read` | `/Users`, `/Groups`, `/Schemas`, `/ResourceTypes`, `/ServiceProviderConfig` | GET (list, show, search) |
  | `scim:create` | `/Users`, `/Groups`, `/Bulk` (POST operations) | POST |
  | `scim:update` | `/Users`, `/Groups`, `/Bulk` (PUT/PATCH operations) | PUT, PATCH |
  | `scim:delete` | `/Users`, `/Groups`, `/Bulk` (DELETE operations) | DELETE |

  `/Me` uses its own set of fine-grained scopes:

  | Scope | Action |
  |---|---|
  | `scim:me:read` | GET `/Me` |
  | `scim:me:create` | POST `/Me` |
  | `scim:me:update` | PUT `/Me`, PATCH `/Me` |
  | `scim:me:delete` | DELETE `/Me` |

  For bulk operations, scope is enforced per individual operation rather than on the
  request as a whole. A caller with only `scim:create` may submit a bulk request
  containing POST operations; any PUT, PATCH, or DELETE operations in the same payload
  will return a `403` operation result.

  ### Example scope lists

  Read-only client:
  ```elixir
  scopes: ["scim:read"]
  ```

  Provisioning client (create and update, but not delete):
  ```elixir
  scopes: ["scim:read", "scim:create", "scim:update"]
  ```

  Full-access admin client:
  ```elixir
  scopes: ["scim:read", "scim:create", "scim:update", "scim:delete"]
  ```
  """

  @enforce_keys [:id, :scopes]
  defstruct [
    # Who: API client or user ID (required)
    :id,
    # Where: tenant identifier (nil = single-tenant)
    :tenant_id,
    # For Basic Auth users
    :username,
    # Human-readable
    :display_name,
    # List of scopes
    :scopes,
    # Extra information (e.g. JWT claims, OAuth user_info)
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t() | nil,
          username: String.t() | nil,
          display_name: String.t() | nil,
          scopes: [String.t()],
          metadata: map()
        }

  @doc """
  Creates a new Scope from a map or keyword list.

  Raises `ArgumentError` if required keys `:id` or `:scopes` are missing.

  ## Examples

      iex> Scope.new(%{id: "user_1", scopes: ["scim:read"]})
      {:ok, %Scope{id: "user_1", scopes: ["scim:read"], metadata: %{}}}

      iex> Scope.new(id: "client_1", scopes: ["scim:read", "scim:write"], tenant_id: "org_123")
      {:ok, %Scope{id: "client_1", scopes: ["scim:read", "scim:write"], tenant_id: "org_123", metadata: %{}}}
  """
  @spec new(map() | keyword()) :: {:ok, t()} | :error
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(%{id: id, scopes: scopes} = attrs) when is_binary(id) and is_list(scopes) do
    {:ok,
     %__MODULE__{
       id: id,
       scopes: scopes,
       tenant_id: Map.get(attrs, :tenant_id),
       username: Map.get(attrs, :username),
       display_name: Map.get(attrs, :display_name),
       metadata: Map.get(attrs, :metadata, %{})
     }}
  end

  def new(attrs) when is_map(attrs), do: :error

  @doc """
  Returns `true` if the scope has the given authorization scope.
  """
  @spec has_scope?(t(), String.t()) :: boolean()
  def has_scope?(%__MODULE__{scopes: scopes}, scope) when is_binary(scope) do
    scope in scopes
  end

  @doc """
  Returns `true` if the scope has all of the given authorization scopes.
  """
  @spec has_all_scopes?(t(), [String.t()]) :: boolean()
  def has_all_scopes?(%__MODULE__{scopes: scopes}, required_scopes)
      when is_list(required_scopes) do
    Enum.all?(required_scopes, &(&1 in scopes))
  end
end
