defmodule ScimTester.Connection do
  @moduledoc """
  Builds a SCIM client from user-supplied connection details.

  Normalizes the base URL (ensuring a trailing `/scim/v2`) and returns the
  normalized URL alongside the client. Returns `{"", nil}` when either the base
  URL or bearer token is missing.
  """

  alias ExScimClient.Client

  @doc """
  Returns `{normalized_base_url, client}` for the given base URL and bearer token.
  """
  def build("", _bearer_token), do: {"", nil}
  def build(_base_url, ""), do: {"", nil}

  def build(base_url, bearer_token) do
    normalized = normalize_base_url(base_url)
    {normalized, Client.new(normalized, bearer_token)}
  end

  defp normalize_base_url(base_url) do
    base_url = String.trim_trailing(base_url, "/")

    if String.ends_with?(base_url, "/scim/v2") do
      base_url
    else
      base_url <> "/scim/v2"
    end
  end
end
