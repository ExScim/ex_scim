defmodule ScimTester.ScimTesting do
  @moduledoc """
  Context module for SCIM integration testing.

  Provides functions for running SCIM API tests, generating test data,
  and managing test execution lifecycle.
  """

  alias ExScimClient.Resources.Users
  alias ExScimClient.Me
  alias ExScimClient.Resources.Bulk
  alias ExScimClient.Resources.Schemas
  alias ExScimClient.Resources.ResourceTypes

  @first_names ["John", "Jane", "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"]
  @last_names ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
  @job_titles [
    "Software Engineer",
    "Product Manager",
    "Data Analyst",
    "Designer",
    "Developer",
    "Consultant",
    "Architect",
    "Manager"
  ]

  @test_definitions [
    %{
      id: :create_user,
      name: "Create User",
      icon: "hero-beaker",
      description: "Create a new user account",
      depends_on: []
    },
    %{
      id: :get_user,
      name: "Get User",
      icon: "hero-beaker",
      description: "Fetch user details",
      depends_on: [:create_user]
    },
    %{
      id: :update_user,
      name: "Update User",
      icon: "hero-beaker",
      description: "Modify user information",
      depends_on: [:create_user]
    },
    %{
      id: :patch_user,
      name: "Patch User",
      icon: "hero-beaker",
      description: "Apply partial user updates",
      depends_on: [:create_user]
    },
    %{
      id: :list_users,
      name: "List Users",
      icon: "hero-beaker",
      description: "Browse all users",
      depends_on: []
    },
    %{
      id: :delete_user,
      name: "Delete User",
      icon: "hero-beaker",
      description: "Remove the test user",
      depends_on: [:create_user]
    },
    %{
      id: :me_operations,
      name: "User Profile",
      icon: "hero-beaker",
      description: "Check current user information",
      depends_on: []
    },
    %{
      id: :schema_operations,
      name: "Schema Info",
      icon: "hero-beaker",
      description: "Get data structure details",
      depends_on: []
    },
    %{
      id: :resource_types,
      name: "Resource Types",
      icon: "hero-beaker",
      description: "List available resource types",
      depends_on: []
    },
    %{
      id: :bulk_operations,
      name: "Bulk Operations",
      icon: "hero-beaker",
      description: "Process multiple operations at once",
      depends_on: []
    }
  ]

  @doc """
  Returns the list of available test definitions.
  """
  def test_definitions, do: @test_definitions

  @doc """
  Initializes test results map with all tests in pending state.
  """
  def init_test_results do
    Enum.reduce(@test_definitions, %{}, fn test, acc ->
      Map.put(acc, test.id, %{status: :pending, result: nil, error: nil})
    end)
  end

  @doc """
  Returns the default enabled tests set (all tests).
  """
  def default_enabled_tests do
    @test_definitions |> Enum.map(& &1.id) |> MapSet.new()
  end

  @doc """
  Returns all test IDs that depend on the given test (direct and transitive).
  """
  def dependents_of(test_id) do
    direct =
      @test_definitions
      |> Enum.filter(fn t -> test_id in t.depends_on end)
      |> Enum.map(& &1.id)

    transitive = Enum.flat_map(direct, &dependents_of/1)

    Enum.uniq(direct ++ transitive)
  end

  @capability_test_map %{
    "patch" => [:patch_user],
    "bulk" => [:bulk_operations]
  }

  @doc """
  Returns the capability-to-test mapping.
  """
  def capability_test_map, do: @capability_test_map

  @doc """
  Given a capabilities map (from ServiceProviderConfig), returns the list of
  test IDs whose required capability is not supported by the provider.

  Returns an empty list if capabilities is nil.
  """
  def tests_disabled_by_capabilities(nil), do: []

  def tests_disabled_by_capabilities(capabilities) when is_map(capabilities) do
    Enum.flat_map(@capability_test_map, fn {capability_key, test_ids} ->
      supported = get_in(capabilities, [capability_key, "supported"])

      if supported == true do
        []
      else
        test_ids
      end
    end)
  end

  @doc """
  Returns a MapSet of enabled tests after removing tests unsupported by the
  provider's capabilities, including their transitive dependents.
  """
  def enabled_tests_for_capabilities(capabilities) do
    disabled = tests_disabled_by_capabilities(capabilities)
    all_disabled = Enum.flat_map(disabled, fn test_id -> [test_id | dependents_of(test_id)] end)
    all_disabled_set = MapSet.new(all_disabled)
    MapSet.difference(default_enabled_tests(), all_disabled_set)
  end

  @doc """
  Returns all dependencies of the given test (direct and transitive).
  """
  def dependencies_of(test_id) do
    test = Enum.find(@test_definitions, &(&1.id == test_id))

    case test do
      nil ->
        []

      %{depends_on: depends_on} ->
        transitive = Enum.flat_map(depends_on, &dependencies_of/1)
        Enum.uniq(depends_on ++ transitive)
    end
  end

  @doc """
  Enables a test and all its dependencies in the enabled tests set.
  """
  def enable_test(test_id, enabled_tests) do
    to_enable = MapSet.new([test_id | dependencies_of(test_id)])
    MapSet.union(enabled_tests, to_enable)
  end

  @doc """
  Disables a test and all its dependents in the enabled tests set.
  """
  def disable_test(test_id, enabled_tests) do
    to_disable = MapSet.new([test_id | dependents_of(test_id)])
    MapSet.difference(enabled_tests, to_disable)
  end

  @doc """
  Runs all SCIM tests in sequence.

  This function orchestrates the entire test suite, sending progress messages
  to the provided process ID. Only tests in the enabled_tests set will be executed.
  """
  def run_all_tests(pid, client, enabled_tests) do
    send(pid, {:log_message, "Starting SCIM Integration Tests", :start})

    # Only run create_user if enabled
    user_id =
      if MapSet.member?(enabled_tests, :create_user) do
        case run_single_test(pid, client, :create_user, nil) do
          {:ok, id} -> id
          _ -> nil
        end
      else
        nil
      end

    if user_id, do: send(pid, {:user_created, user_id})

    # User-dependent tests (only if enabled AND user_id exists)
    Enum.each([:get_user, :update_user, :patch_user], fn test ->
      if MapSet.member?(enabled_tests, test) and user_id do
        run_single_test(pid, client, test, user_id)
      end
    end)

    # Independent tests (only if enabled)
    Enum.each(
      [:list_users, :me_operations, :schema_operations, :resource_types, :bulk_operations],
      fn test ->
        if MapSet.member?(enabled_tests, test) do
          run_single_test(pid, client, test, user_id)
        end
      end
    )

    # Delete user last (only if enabled AND user_id exists)
    if MapSet.member?(enabled_tests, :delete_user) and user_id do
      run_single_test(pid, client, :delete_user, user_id)
    end

    send(pid, {:tests_completed})
  end

  @doc """
  Runs a single test and reports progress to the provided process ID.
  """
  def run_single_test(pid, client, test_id, user_id) do
    send(pid, {:test_started, test_id})
    send(pid, {:log_message, "Running #{test_id}...", :running})

    # Validate client first
    case validate_client(client) do
      :ok ->
        result = execute_test_safely(test_id, client, user_id)
        handle_test_result(pid, test_id, result)

      {:error, reason} ->
        send(pid, {:test_failed, test_id, reason})
        send(pid, {:log_message, "#{test_id} failed: #{reason}", :error})
        {:error, reason}
    end
  end

  defp validate_client(nil),
    do: {:error, "SCIM client not configured - please set BASE_URL and BEARER_TOKEN"}

  defp validate_client(_client), do: :ok

  defp execute_test_safely(test_id, client, user_id) do
    try do
      case test_id do
        :create_user -> test_create_user(client)
        :get_user -> test_get_user(client, user_id)
        :update_user -> test_update_user(client, user_id)
        :patch_user -> test_patch_user(client, user_id)
        :list_users -> test_list_users(client)
        :delete_user -> test_delete_user(client, user_id)
        :me_operations -> test_me_operations(client)
        :schema_operations -> test_schema_operations(client)
        :resource_types -> test_resource_type_operations(client)
        :bulk_operations -> test_bulk_operations(client)
      end
    rescue
      error -> {:error, "Connection failed: #{inspect(error)}"}
    catch
      :exit, reason -> {:error, "Connection terminated: #{inspect(reason)}"}
      error -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp handle_test_result(pid, test_id, result) do
    case result do
      {:ok, data} ->
        send(pid, {:test_completed, test_id, data})
        send(pid, {:log_message, "#{test_id} completed successfully", :success})
        {:ok, data}

      {:error, reason} ->
        report_failure(pid, test_id, format_error(reason))

      other ->
        report_failure(pid, test_id, "Unexpected response format: #{inspect(other)}")
    end
  end

  defp report_failure(pid, test_id, error_message) do
    send(pid, {:test_failed, test_id, error_message})
    send(pid, {:log_message, "#{test_id} failed: #{error_message}", :error})
    {:error, error_message}
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp test_create_user(client) do
    user_data = generate_random_user()

    case Users.create(client, user_data) do
      {:ok, %{"id" => user_id} = _response} -> {:ok, user_id}
      error -> error
    end
  end

  defp test_get_user(client, user_id) do
    Users.get(client, user_id)
  end

  defp test_update_user(client, user_id) do
    case Users.get(client, user_id) do
      {:ok, existing_user} ->
        updated_data = generate_random_user_update(existing_user)
        Users.update(client, user_id, updated_data)

      error ->
        error
    end
  end

  defp test_patch_user(client, user_id) do
    patch_operations = [
      %{
        "op" => "replace",
        "path" => "title",
        "value" => "Senior #{generate_random_job_title()}"
      }
    ]

    Users.patch(client, user_id, patch_operations)
  end

  defp test_list_users(client) do
    Users.list(client)
  end

  defp test_delete_user(client, user_id) do
    Users.delete(client, user_id)
  end

  defp test_me_operations(client) do
    Me.get(client)
  end

  defp test_schema_operations(client) do
    Schemas.list(client)
  end

  defp test_resource_type_operations(client) do
    ResourceTypes.list(client)
  end

  defp test_bulk_operations(client) do
    user1_data = generate_random_user()
    user2_data = generate_random_user()

    bulk_operations = [
      %{
        "method" => "POST",
        "path" => "/Users",
        "bulkId" => "bulk_user_1",
        "data" => user1_data
      },
      %{
        "method" => "POST",
        "path" => "/Users",
        "bulkId" => "bulk_user_2",
        "data" => user2_data
      }
    ]

    bulk_request = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
      "Operations" => bulk_operations
    }

    Bulk.execute(client, bulk_request)
  end

  # Data generation functions

  defp generate_random_user do
    random_id = generate_random_string(8)
    first_name = Enum.random(@first_names)
    last_name = Enum.random(@last_names)

    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => "test_user_#{random_id}",
      "name" => %{
        "givenName" => first_name,
        "familyName" => last_name
      },
      "displayName" => "#{first_name} #{last_name}",
      "emails" => [
        %{
          "value" =>
            "#{String.downcase(first_name)}.#{String.downcase(last_name)}#{random_id}@example.com",
          "type" => "work",
          "primary" => true
        }
      ],
      "active" => true,
      "title" => generate_random_job_title()
    }
  end

  defp generate_random_user_update(existing_user) do
    random_id = generate_random_string(6)
    first_name = Enum.random(["Updated", "Modified", "Changed", "New"])
    last_name = Enum.random(["User", "Person", "Individual", "Account"])
    display_name = "#{first_name} #{last_name} #{random_id}"
    title = "Updated #{generate_random_job_title()}"

    existing_user
    |> put_in(["name", "givenName"], first_name)
    |> put_in(["name", "familyName"], last_name)
    |> Map.put("displayName", display_name)
    |> Map.put("title", title)
  end

  defp generate_random_job_title do
    Enum.random(@job_titles)
  end

  defp generate_random_string(length) do
    chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    chars_list = String.graphemes(chars)

    1..length
    |> Enum.map(fn _ -> Enum.random(chars_list) end)
    |> Enum.join("")
  end
end
