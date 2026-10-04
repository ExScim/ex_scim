defmodule ExScim.AuthorizationTest do
  use ExUnit.Case, async: false

  alias ExScim.Authorization
  alias ExScim.Authorization.DefaultPolicy
  alias ExScim.Operations.Bulk
  alias ExScim.Scope

  defmodule GroupsDeniedPolicy do
    @behaviour ExScim.Authorization.Adapter

    @impl true
    def authorize(_scope, :groups, _action), do: {:error, :groups_managed_elsewhere}
    def authorize(_scope, _resource, _action), do: :ok
  end

  @crud ["scim:read", "scim:create", "scim:update", "scim:delete"]
  @me ["scim:me:read", "scim:me:create", "scim:me:update", "scim:me:delete"]

  defp scope(scopes), do: %Scope{id: "client", scopes: scopes}

  setup do
    prev = Application.get_env(:ex_scim, :authorization_adapter)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:ex_scim, :authorization_adapter, prev),
        else: Application.delete_env(:ex_scim, :authorization_adapter)
    end)

    :ok
  end

  describe "DefaultPolicy.authorize/3" do
    for resource <- [:users, :groups], action <- [:read, :create, :update, :delete] do
      test "#{resource} #{action} requires scim:#{action}" do
        resource = unquote(resource)
        action = unquote(action)
        required = "scim:#{action}"

        assert DefaultPolicy.authorize(scope([required]), resource, action) == :ok

        assert DefaultPolicy.authorize(scope(@crud -- [required]), resource, action) ==
                 {:error, {:missing_scopes, [required]}}
      end
    end

    for action <- [:read, :create, :update, :delete] do
      test "me #{action} requires scim:me:#{action}" do
        action = unquote(action)
        required = "scim:me:#{action}"

        assert DefaultPolicy.authorize(scope([required]), :me, action) == :ok

        assert DefaultPolicy.authorize(scope(@crud), :me, action) ==
                 {:error, {:missing_scopes, [required]}}
      end
    end

    test "schemas and service provider config require scim:read" do
      for resource <- [:schemas, :service_provider_config] do
        assert DefaultPolicy.authorize(scope(["scim:read"]), resource, :read) == :ok

        assert DefaultPolicy.authorize(scope(@me), resource, :read) ==
                 {:error, {:missing_scopes, ["scim:read"]}}
      end
    end

    test "resource types require no scope" do
      assert DefaultPolicy.authorize(scope([]), :resource_types, :read) == :ok
    end

    test "writes to discovery resources are denied" do
      for resource <- [:schemas, :resource_types, :service_provider_config] do
        assert DefaultPolicy.authorize(scope(@crud), resource, :create) ==
                 {:error, :not_permitted}
      end
    end
  end

  describe "authorize/3" do
    test "uses DefaultPolicy when no adapter is configured" do
      Application.delete_env(:ex_scim, :authorization_adapter)

      assert Authorization.adapter() == DefaultPolicy
      assert Authorization.authorize(scope(["scim:read"]), :users, :read) == :ok
    end

    test "delegates to the configured adapter" do
      Application.put_env(:ex_scim, :authorization_adapter, GroupsDeniedPolicy)

      assert Authorization.authorize(scope([]), :users, :delete) == :ok

      assert Authorization.authorize(scope(@crud), :groups, :read) ==
               {:error, :groups_managed_elsewhere}
    end
  end

  describe "denial_detail/1" do
    test "lists missing scopes" do
      assert Authorization.denial_detail({:missing_scopes, ["a", "b"]}) ==
               "Missing required scope(s): a, b"
    end

    test "falls back to a generic message" do
      assert Authorization.denial_detail(:anything) ==
               "Operation is not permitted based on the supplied authorization"
    end
  end

  describe "bulk operations" do
    @bulk_schema "urn:ietf:params:scim:api:messages:2.0:BulkRequest"

    defp bulk(operations) do
      %{"schemas" => [@bulk_schema], "Operations" => operations}
    end

    defp delete_op(path, bulk_id),
      do: %{"method" => "DELETE", "path" => path, "bulkId" => bulk_id}

    test "deny each operation the default policy rejects" do
      Application.delete_env(:ex_scim, :authorization_adapter)

      {:ok, response} =
        Bulk.process_bulk_request(
          bulk([delete_op("/Users/missing", "u")]),
          scope(["scim:create"])
        )

      [op] = response["Operations"]
      assert op["status"] == "403"
      assert op["response"]["detail"] == "Missing required scope(s): scim:delete"
    end

    test "consult the configured adapter per resource" do
      Application.put_env(:ex_scim, :authorization_adapter, GroupsDeniedPolicy)

      {:ok, response} =
        Bulk.process_bulk_request(
          bulk([delete_op("/Users/missing", "u"), delete_op("/Groups/missing", "g")]),
          scope([])
        )

      statuses = Map.new(response["Operations"], &{&1["bulkId"], &1["status"]})
      assert statuses == %{"u" => "404", "g" => "403"}
    end
  end
end
