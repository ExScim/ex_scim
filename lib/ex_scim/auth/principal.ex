defmodule ExScim.Auth.Principal do
  @moduledoc """
  Represents an authenticated SCIM principal (user or client).
  """

  @enforce_keys [:id, :scopes]
  defstruct [
    # Internal ID or client ID
    :id,
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
          username: String.t() | nil,
          display_name: String.t() | nil,
          scopes: [String.t()],
          metadata: map()
        }

  @doc """
  Creates a new Principal from a map or keyword list.

  Raises `ArgumentError` if required keys `:id` or `:scopes` are missing.

  ## Examples

      iex> Principal.new(%{id: "user_1", scopes: ["scim:read"]})
      %Principal{id: "user_1", scopes: ["scim:read"], metadata: %{}}

      iex> Principal.new(id: "client_1", scopes: ["scim:read", "scim:write"], metadata: %{grant_type: "client_credentials"})
      %Principal{id: "client_1", scopes: ["scim:read", "scim:write"], metadata: %{grant_type: "client_credentials"}}
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(%{id: id, scopes: scopes} = attrs) when is_binary(id) and is_list(scopes) do
    %__MODULE__{
      id: id,
      scopes: scopes,
      username: Map.get(attrs, :username),
      display_name: Map.get(attrs, :display_name),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  def new(attrs) when is_map(attrs) do
    raise ArgumentError,
          "Principal requires :id (string) and :scopes (list), got: #{inspect(Map.keys(attrs))}"
  end

  @doc """
  Returns `true` if the principal has the given scope.
  """
  @spec has_scope?(t(), String.t()) :: boolean()
  def has_scope?(%__MODULE__{scopes: scopes}, scope) when is_binary(scope) do
    scope in scopes
  end

  @doc """
  Returns `true` if the principal has all of the given scopes.
  """
  @spec has_all_scopes?(t(), [String.t()]) :: boolean()
  def has_all_scopes?(%__MODULE__{scopes: scopes}, required_scopes) when is_list(required_scopes) do
    Enum.all?(required_scopes, &(&1 in scopes))
  end
end
