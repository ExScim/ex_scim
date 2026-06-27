defmodule ScimTester.Capabilities do
  @moduledoc """
  Interprets a provider's `ServiceProviderConfig` response.

  Capabilities are carried through the LiveView as `:loading`, `{:ok, body}`, or
  `{:error, reason}`; these helpers tolerate any of those shapes.
  """

  alias ScimTester.ScimTesting

  @display_items [
    {"patch", "PATCH Operations"},
    {"bulk", "Bulk Operations"},
    {"filter", "Filtering"},
    {"changePassword", "Change Password"},
    {"sort", "Sorting"},
    {"etag", "ETags"}
  ]

  @doc """
  Returns `true`/`false` when the capability is known, or `nil` when capabilities
  are unavailable.
  """
  def supported?(capabilities, key) do
    case capabilities do
      {:ok, body} -> get_in(body, [key, "supported"]) == true
      _ -> nil
    end
  end

  @doc "Returns `{label, supported?}` pairs for the headline capabilities."
  def summary(capabilities) do
    Enum.map(@display_items, fn {key, label} ->
      {label, supported?(capabilities, key)}
    end)
  end

  @doc "Returns the provider's advertised authentication schemes."
  def auth_schemes(capabilities) do
    case capabilities do
      {:ok, body} -> Map.get(body, "authenticationSchemes", [])
      _ -> []
    end
  end

  @doc "Whether the given test is disabled by the provider's advertised capabilities."
  def test_unsupported_by_provider?(capabilities, test_id) do
    case capabilities do
      {:ok, body} -> test_id in ScimTesting.tests_disabled_by_capabilities(body)
      _ -> false
    end
  end
end
