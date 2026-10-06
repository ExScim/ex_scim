defmodule ExScimPhoenix.CustomAuthorizationTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias ExScim.Scope
  alias ExScimPhoenix.Test.TestStorage

  @endpoint ExScimPhoenix.Test.Endpoint

  @search_schema "urn:ietf:params:scim:api:messages:2.0:SearchRequest"
  @bulk_schema "urn:ietf:params:scim:api:messages:2.0:BulkRequest"

  # Grants the scope names an identity platform issues, unrelated to `scim:*`.
  defmodule IdpAuth do
    @behaviour ExScim.Auth.AuthProvider.Adapter

    @impl true
    def validate_bearer("users-reader"),
      do: {:ok, %Scope{id: "users-reader", scopes: ["directory.users.read"]}}

    def validate_bearer("directory-reader"),
      do:
        {:ok,
         %Scope{
           id: "directory-reader",
           scopes: ["directory.users.read", "directory.groups.read"]
         }}

    def validate_bearer(_), do: {:error, :token_not_found}

    @impl true
    def validate_basic(_, _), do: {:error, :invalid_credentials}
  end

  defmodule IdpPolicy do
    @behaviour ExScim.Authorization.Adapter

    @impl true
    def authorize(scope, resource, :read) when resource in [:users, :groups],
      do: require_scope(scope, "directory.#{resource}.read")

    def authorize(scope, resource, _action) when resource in [:users, :groups],
      do: require_scope(scope, "directory.#{resource}.write")

    def authorize(_scope, resource, :read)
        when resource in [:schemas, :resource_types, :service_provider_config],
        do: :ok

    def authorize(_scope, _resource, _action), do: {:error, :not_permitted}

    defp require_scope(scope, required) do
      if Scope.has_scope?(scope, required),
        do: :ok,
        else: {:error, {:missing_scopes, [required]}}
    end
  end

  setup do
    {:ok, _} = TestStorage.start_link()

    prev =
      for key <- [:storage_strategy, :auth_provider_adapter, :authorization_adapter],
          do: {key, Application.get_env(:ex_scim, key)}

    Application.put_env(:ex_scim, :storage_strategy, TestStorage)
    Application.put_env(:ex_scim, :auth_provider_adapter, IdpAuth)
    Application.put_env(:ex_scim, :authorization_adapter, IdpPolicy)

    on_exit(fn ->
      for {key, value} <- prev, do: restore(key, value)
      TestStorage.stop()
    end)

    :ok
  end

  test "resource endpoints follow the policy per resource" do
    assert json_response(get(auth_conn("users-reader"), "/Users"), 200)

    body = json_response(get(auth_conn("users-reader"), "/Groups"), 403)
    assert body["detail"] == "Missing required scope(s): directory.groups.read"
  end

  test "resource-specific search follows the policy per resource" do
    assert json_response(post(auth_conn("users-reader"), "/Users/.search", search()), 200)
    assert json_response(post(auth_conn("users-reader"), "/Groups/.search", search()), 403)
  end

  test "cross-resource search requires read access to every resource" do
    assert json_response(post(auth_conn("users-reader"), "/.search", search()), 403)
    assert json_response(post(auth_conn("directory-reader"), "/.search", search()), 200)
  end

  test "discovery endpoints can be opened without scim scopes" do
    for path <- ["/ServiceProviderConfig", "/Schemas", "/ResourceTypes"] do
      assert json_response(get(auth_conn("users-reader"), path), 200)
    end
  end

  test "/Me is denied when the policy does not grant it" do
    assert json_response(get(auth_conn("users-reader"), "/Me"), 403)
  end

  test "bulk operations follow the policy" do
    request = %{
      "schemas" => [@bulk_schema],
      "Operations" => [%{"method" => "DELETE", "path" => "/Users/missing", "bulkId" => "1"}]
    }

    body = json_response(post(auth_conn("directory-reader"), "/Bulk", request), 200)
    [op] = body["Operations"]

    assert op["status"] == "403"
    assert op["response"]["detail"] == "Missing required scope(s): directory.users.write"
  end

  defp search, do: %{"schemas" => [@search_schema]}

  defp auth_conn(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/scim+json")
    |> put_req_header("accept", "application/scim+json")
  end

  defp restore(key, nil), do: Application.delete_env(:ex_scim, key)
  defp restore(key, value), do: Application.put_env(:ex_scim, key, value)
end
