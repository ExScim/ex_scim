defmodule ExScimClient.Client do
  @moduledoc """
  Client configuration struct.

  Authentication is configurable via the `auth` field.

  `new/2` accepts either a bearer token string or an auth strategy tuple/atom:

    * `{:bearer, token}` - `Authorization: Bearer <token>`
    * `{:basic, username, password}` - `Authorization: Basic <base64>`
    * `{:header, name, value}` - an arbitrary authorization header
    * `:none` - no authorization header

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token123")
      iex> client.base_url
      "https://example.com/scim/v2"
      iex> client.bearer
      "token123"

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", {:basic, "user", "pass"})
      iex> client.auth
      {:basic, "user", "pass"}

  """

  @type auth ::
          {:bearer, String.t()}
          | {:basic, String.t(), String.t()}
          | {:header, String.t(), String.t()}
          | :none

  @type t :: %__MODULE__{
          base_url: String.t(),
          bearer: String.t() | nil,
          auth: auth() | nil,
          default_headers: list({String.t(), String.t()})
        }

  defstruct [
    :base_url,
    :bearer,
    auth: nil,
    default_headers: [
      {"content-type", "application/scim+json"},
      {"accept", "application/scim+json"}
    ]
  ]

  @doc """
  Creates a new client configuration.

  ## Parameters

    * `base_url` - Provider base URL
    * `auth` - a bearer token string, or an auth strategy (`{:bearer, token}`,
      `{:basic, username, password}`, `{:header, name, value}`, `:none`)

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "abc123")
      iex> %ExScimClient.Client{base_url: "https://example.com/scim/v2", bearer: "abc123"} = client

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", {:bearer, "abc123"})
      iex> client.auth
      {:bearer, "abc123"}

  """
  @spec new(String.t(), String.t() | auth()) :: t()
  def new(base_url, bearer) when is_binary(bearer) do
    %__MODULE__{base_url: base_url, bearer: bearer, auth: {:bearer, bearer}}
  end

  def new(base_url, {:bearer, _token} = auth) do
    %__MODULE__{base_url: base_url, auth: auth}
  end

  def new(base_url, {:basic, _username, _password} = auth) do
    %__MODULE__{base_url: base_url, auth: auth}
  end

  def new(base_url, {:header, _name, _value} = auth) do
    %__MODULE__{base_url: base_url, auth: auth}
  end

  def new(base_url, :none = auth) do
    %__MODULE__{base_url: base_url, auth: auth}
  end
end
