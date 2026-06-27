defmodule ScimTesterWeb.ScimLive do
  use ScimTesterWeb, :live_view

  alias ExScimClient.Resources.{Groups, Schemas, ServiceProviderConfig, Users}
  alias ScimTester.Connection
  alias ScimTester.DataGenConfig
  alias ScimTester.FilterBuilder
  alias ScimTester.ScimTesting
  alias ScimTester.SearchAttributes

  alias ScimTesterWeb.ScimComponents
  alias ScimTesterWeb.SearchComponents
  alias ScimTesterWeb.TestRunnerComponents

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        base_url: "",
        bearer_token: "",
        client: nil,
        test_results: ScimTesting.init_test_results(),
        current_test: nil,
        running: false,
        test_task_pid: nil,
        progress: 0,
        logs: [],
        created_user_id: nil,
        enabled_tests: ScimTesting.default_enabled_tests(),
        capabilities: nil,
        capabilities_applied: false,
        modal_output: nil,
        search_resource_type: "Users",
        search_filter_rows: [],
        search_combinator: "and",
        search_next_row_id: 1,
        search_results: nil,
        search_error: nil,
        search_loading: false,
        search_page_size: 50,
        search_start_index: 1,
        schemas: nil,
        schemas_loading: false,
        enabled_schemas: SearchAttributes.default_enabled_schemas(),
        data_gen_config: DataGenConfig.default(),
        settings_open: false
      )

    send(self(), :load_saved_config)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    page_title =
      case socket.assigns.live_action do
        :tests -> "Tests"
        :search -> "Search"
      end

    {:noreply, assign(socket, page_title: page_title)}
  end

  # --- Connection / configuration ---

  def handle_event("update_config", params, socket) do
    base_url = Map.get(params, "base_url", socket.assigns.base_url)
    bearer_token = Map.get(params, "bearer_token", socket.assigns.bearer_token)
    {:noreply, apply_config(socket, base_url, bearer_token)}
  end

  def handle_event(
        "config_loaded",
        %{"base_url" => base_url, "bearer_token" => bearer_token} = params,
        socket
      ) do
    data_gen_config =
      params
      |> Map.get("data_gen_config")
      |> DataGenConfig.from_map()

    socket =
      socket
      |> apply_config(base_url, bearer_token)
      |> assign(data_gen_config: data_gen_config)

    {:noreply, socket}
  end

  def handle_event("connect", _params, socket) do
    client = socket.assigns.client

    socket =
      socket
      |> assign(capabilities_applied: false)
      |> maybe_fetch_capabilities(client)
      |> maybe_fetch_schemas(client)

    {:noreply, socket}
  end

  # --- Test runner ---

  def handle_event("start_tests", _params, socket) do
    case validate_configuration(socket) do
      :ok ->
        send(self(), :run_tests)

        socket =
          assign(socket,
            running: true,
            progress: 0,
            test_results: ScimTesting.init_test_results(),
            logs: [],
            created_user_id: nil
          )

        {:noreply, socket}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("stop_tests", _params, socket) do
    if socket.assigns.test_task_pid do
      Process.exit(socket.assigns.test_task_pid, :kill)
    end

    test_results =
      socket.assigns.test_results
      |> Enum.map(fn {test_id, result} ->
        if result.status == :running do
          {test_id, %{status: :pending, result: nil, error: nil}}
        else
          {test_id, result}
        end
      end)
      |> Map.new()

    socket =
      socket
      |> assign(
        running: false,
        current_test: nil,
        test_task_pid: nil,
        test_results: test_results,
        progress: 0
      )
      |> update(:logs, fn logs ->
        [
          %{timestamp: DateTime.utc_now(), message: "Tests stopped by user", level: :warning}
          | logs
        ]
      end)

    {:noreply, put_flash(socket, :info, "Tests stopped")}
  end

  def handle_event("retry_test", %{"test_id" => test_id}, socket) do
    case existing_test_atom(test_id) do
      nil ->
        {:noreply, socket}

      test_atom ->
        send(self(), {:retry_test, test_atom})

        socket =
          update(socket, :test_results, fn results ->
            Map.put(results, test_atom, %{status: :running, result: nil, error: nil})
          end)

        {:noreply, socket}
    end
  end

  def handle_event("toggle_test", %{"test-id" => test_id}, socket) do
    case existing_test_atom(test_id) do
      nil ->
        {:noreply, socket}

      test_atom ->
        enabled_tests = socket.assigns.enabled_tests

        enabled_tests =
          if MapSet.member?(enabled_tests, test_atom),
            do: ScimTesting.disable_test(test_atom, enabled_tests),
            else: ScimTesting.enable_test(test_atom, enabled_tests)

        {:noreply, assign(socket, enabled_tests: enabled_tests)}
    end
  end

  def handle_event("toggle_all_tests", %{"action" => "enable"}, socket) do
    {:noreply, assign(socket, enabled_tests: ScimTesting.default_enabled_tests())}
  end

  def handle_event("toggle_all_tests", %{"action" => "disable"}, socket) do
    {:noreply, assign(socket, enabled_tests: MapSet.new())}
  end

  def handle_event("show_full_output", %{"test_id" => test_id, "type" => type}, socket) do
    case existing_test_atom(test_id) do
      nil ->
        {:noreply, socket}

      test_atom ->
        test_result = Map.get(socket.assigns.test_results, test_atom)
        test_def = Enum.find(ScimTesting.test_definitions(), &(&1.id == test_atom))

        content =
          case type do
            "error" -> inspect(test_result.error, pretty: true, limit: :infinity, width: 80)
            "result" -> inspect(test_result.result, pretty: true, limit: :infinity, width: 80)
          end

        modal_output = %{
          test_id: test_atom,
          test_name: test_def.name,
          type: type,
          content: content
        }

        {:noreply, assign(socket, modal_output: modal_output)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal_output: nil)}
  end

  # --- Data generation settings ---

  def handle_event("open_settings", _params, socket) do
    {:noreply, assign(socket, settings_open: true)}
  end

  def handle_event("close_settings", _params, socket) do
    {:noreply, assign(socket, settings_open: false)}
  end

  def handle_event("update_data_gen", params, socket) do
    config = DataGenConfig.apply_params(socket.assigns.data_gen_config, params)

    socket =
      socket
      |> assign(data_gen_config: config)
      |> push_event("save_data_gen_config", DataGenConfig.to_map(config))

    {:noreply, socket}
  end

  def handle_event("reset_data_gen", _params, socket) do
    config = DataGenConfig.default()

    socket =
      socket
      |> assign(data_gen_config: config)
      |> push_event("save_data_gen_config", DataGenConfig.to_map(config))

    {:noreply, socket}
  end

  # --- Search composer ---

  def handle_event("toggle_schema", %{"schema-id" => schema_id}, socket) do
    enabled_schemas = socket.assigns.enabled_schemas

    enabled_schemas =
      if MapSet.member?(enabled_schemas, schema_id),
        do: MapSet.delete(enabled_schemas, schema_id),
        else: MapSet.put(enabled_schemas, schema_id)

    {:noreply,
     assign(socket,
       enabled_schemas: enabled_schemas,
       search_filter_rows: [],
       search_next_row_id: 1
     )}
  end

  def handle_event("search_resource_type", %{"resource_type" => type}, socket) do
    {:noreply,
     assign(socket,
       search_resource_type: type,
       search_filter_rows: [],
       search_next_row_id: 1,
       search_results: nil,
       search_error: nil
     )}
  end

  def handle_event("update_filter_row", %{"row-id" => row_id_str} = params, socket) do
    row_id = String.to_integer(row_id_str)

    socket =
      update(socket, :search_filter_rows, fn rows ->
        Enum.map(rows, fn row ->
          if row.id == row_id do
            row
            |> maybe_put_param(params, "attribute", :attribute)
            |> maybe_put_param(params, "operator", :operator)
            |> maybe_put_param(params, "value", :value)
          else
            row
          end
        end)
      end)

    {:noreply, socket}
  end

  def handle_event("add_filter_row", _params, socket) do
    new_row = %{
      id: socket.assigns.search_next_row_id,
      attribute:
        SearchAttributes.default_attribute(
          socket.assigns.search_resource_type,
          socket.assigns.schemas,
          socket.assigns.enabled_schemas
        ),
      operator: "eq",
      value: ""
    }

    socket =
      socket
      |> update(:search_filter_rows, fn rows -> rows ++ [new_row] end)
      |> update(:search_next_row_id, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_event("remove_filter_row", %{"row-id" => row_id_str}, socket) do
    row_id = String.to_integer(row_id_str)
    remaining = Enum.reject(socket.assigns.search_filter_rows, &(&1.id == row_id))
    {:noreply, assign(socket, search_filter_rows: remaining)}
  end

  def handle_event("search_combinator", %{"combinator" => combinator}, socket) do
    {:noreply, assign(socket, search_combinator: combinator)}
  end

  def handle_event("search_page_size", %{"page_size" => size_str}, socket) do
    socket = assign(socket, search_page_size: String.to_integer(size_str), search_start_index: 1)
    send(self(), :run_search)
    {:noreply, assign(socket, search_loading: true, search_error: nil)}
  end

  def handle_event("search_page", %{"start_index" => idx_str}, socket) do
    socket = assign(socket, search_start_index: String.to_integer(idx_str))
    send(self(), :run_search)
    {:noreply, assign(socket, search_loading: true, search_error: nil)}
  end

  def handle_event("execute_search", _params, socket) do
    if is_nil(socket.assigns.client) do
      {:noreply, put_flash(socket, :error, "Please connect to a SCIM provider first")}
    else
      send(self(), :run_search)
      {:noreply, assign(socket, search_loading: true, search_error: nil, search_start_index: 1)}
    end
  end

  def handle_event("show_resource", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    resources = get_in(socket.assigns.search_results, ["Resources"]) || []
    resource = Enum.at(resources, index)

    if resource do
      modal_output = %{
        test_id: :search_result,
        test_name: "#{socket.assigns.search_resource_type} Resource",
        type: "result",
        content: Jason.encode!(resource, pretty: true)
      }

      {:noreply, assign(socket, modal_output: modal_output)}
    else
      {:noreply, socket}
    end
  end

  # --- Async results ---

  def handle_info(:run_search, socket) do
    live_view_pid = self()
    client = socket.assigns.client
    resource_type = socket.assigns.search_resource_type

    filter =
      FilterBuilder.build(socket.assigns.search_filter_rows, socket.assigns.search_combinator)

    pagination =
      ExScimClient.Pagination.new(
        socket.assigns.search_page_size,
        socket.assigns.search_start_index
      )

    Task.start(fn ->
      result =
        try do
          opts =
            [pagination: pagination]
            |> then(fn opts ->
              if filter, do: Keyword.put(opts, :filter, filter), else: opts
            end)

          case resource_type do
            "Users" -> Users.list(client, opts)
            "Groups" -> Groups.list(client, opts)
          end
        rescue
          error -> {:error, "Request failed: #{Exception.message(error)}"}
        catch
          :exit, reason -> {:error, "Request terminated: #{inspect(reason)}"}
        end

      send(live_view_pid, {:search_completed, result})
    end)

    {:noreply, socket}
  end

  def handle_info({:search_completed, {:ok, results}}, socket) do
    {:noreply, assign(socket, search_results: results, search_loading: false, search_error: nil)}
  end

  def handle_info({:search_completed, {:error, reason}}, socket) do
    message = if is_binary(reason), do: reason, else: inspect(reason)
    {:noreply, assign(socket, search_results: nil, search_loading: false, search_error: message)}
  end

  def handle_info(:run_tests, socket) do
    live_view_pid = self()
    enabled_tests = socket.assigns.enabled_tests
    user_schema = get_user_schema(socket.assigns.schemas)
    data_config = socket.assigns.data_gen_config

    {:ok, task_pid} =
      Task.start(fn ->
        ScimTesting.run_all_tests(
          live_view_pid,
          socket.assigns.client,
          enabled_tests,
          user_schema,
          data_config
        )
      end)

    {:noreply, assign(socket, test_task_pid: task_pid)}
  end

  def handle_info({:retry_test, test_id}, socket) do
    live_view_pid = self()
    user_schema = get_user_schema(socket.assigns.schemas)
    data_config = socket.assigns.data_gen_config

    Task.start(fn ->
      ScimTesting.run_single_test(
        live_view_pid,
        socket.assigns.client,
        test_id,
        socket.assigns.created_user_id,
        user_schema,
        data_config
      )
    end)

    {:noreply, socket}
  end

  def handle_info({:test_started, test_id}, socket) do
    socket = assign(socket, current_test: test_id)

    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_id, %{status: :running, result: nil, error: nil})
      end)

    {:noreply, socket}
  end

  def handle_info({:test_completed, test_id, result}, socket) do
    {:noreply, finish_test(socket, test_id, %{status: :success, result: result, error: nil})}
  end

  def handle_info({:test_failed, test_id, error}, socket) do
    {:noreply, finish_test(socket, test_id, %{status: :error, result: nil, error: error})}
  end

  def handle_info({:user_created, user_id}, socket) do
    {:noreply, assign(socket, created_user_id: user_id)}
  end

  def handle_info({:log_message, message, level}, socket) do
    socket =
      update(socket, :logs, fn logs ->
        [%{timestamp: DateTime.utc_now(), message: message, level: level} | logs]
      end)

    {:noreply, socket}
  end

  def handle_info({:tests_completed}, socket) do
    socket =
      assign(socket,
        running: false,
        current_test: nil,
        progress: 100,
        test_task_pid: nil
      )

    {:noreply, socket}
  end

  def handle_info(:load_saved_config, socket) do
    {:noreply, push_event(socket, "load_saved_config", %{})}
  end

  def handle_info({:capabilities_fetched, {:ok, body}}, socket) do
    socket = assign(socket, capabilities: {:ok, body})

    socket =
      if socket.assigns.capabilities_applied do
        socket
      else
        enabled = ScimTesting.enabled_tests_for_capabilities(body)
        assign(socket, enabled_tests: enabled, capabilities_applied: true)
      end

    {:noreply, socket}
  end

  def handle_info({:capabilities_fetched, {:error, reason}}, socket) do
    message = if is_binary(reason), do: reason, else: inspect(reason)
    {:noreply, assign(socket, capabilities: {:error, message})}
  end

  def handle_info({:schemas_fetched, {:ok, schemas_map}}, socket) do
    enabled_schemas =
      if Map.has_key?(schemas_map, SearchAttributes.enterprise_user_schema_id()) do
        MapSet.put(socket.assigns.enabled_schemas, SearchAttributes.enterprise_user_schema_id())
      else
        socket.assigns.enabled_schemas
      end

    {:noreply,
     assign(socket,
       schemas: schemas_map,
       schemas_loading: false,
       enabled_schemas: enabled_schemas
     )}
  end

  def handle_info({:schemas_fetched, {:error, _reason}}, socket) do
    {:noreply, assign(socket, schemas: nil, schemas_loading: false)}
  end

  # --- Private helpers ---

  defp apply_config(socket, base_url, bearer_token) do
    {normalized_base_url, client} = Connection.build(base_url, bearer_token)

    assign(socket,
      base_url: normalized_base_url,
      bearer_token: bearer_token,
      client: client,
      capabilities: nil,
      capabilities_applied: false,
      schemas: nil,
      schemas_loading: false,
      enabled_schemas: SearchAttributes.default_enabled_schemas()
    )
  end

  defp maybe_fetch_capabilities(socket, nil) do
    assign(socket, capabilities: nil)
  end

  defp maybe_fetch_capabilities(socket, client) do
    live_view_pid = self()

    Task.start(fn ->
      result =
        try do
          ServiceProviderConfig.get(client)
        rescue
          error -> {:error, "Connection failed: #{inspect(error)}"}
        catch
          :exit, reason -> {:error, "Connection terminated: #{inspect(reason)}"}
        end

      send(live_view_pid, {:capabilities_fetched, result})
    end)

    assign(socket, capabilities: :loading)
  end

  defp maybe_fetch_schemas(socket, nil) do
    assign(socket, schemas: nil, schemas_loading: false)
  end

  defp maybe_fetch_schemas(socket, client) do
    live_view_pid = self()

    Task.start(fn ->
      fetchers = [
        fn -> Schemas.user_schema(client) end,
        fn -> Schemas.group_schema(client) end,
        fn -> Schemas.enterprise_user_schema(client) end
      ]

      results =
        Enum.reduce(fetchers, %{}, fn fetch_fn, acc ->
          try do
            case fetch_fn.() do
              {:ok, schema} ->
                schema_id = Map.get(schema, "id")
                if schema_id, do: Map.put(acc, schema_id, schema), else: acc

              {:error, _} ->
                acc
            end
          rescue
            _ -> acc
          catch
            :exit, _ -> acc
          end
        end)

      if map_size(results) > 0 do
        send(live_view_pid, {:schemas_fetched, {:ok, results}})
      else
        send(live_view_pid, {:schemas_fetched, {:error, :no_schemas}})
      end
    end)

    assign(socket, schemas_loading: true)
  end

  defp validate_configuration(socket) do
    cond do
      MapSet.size(socket.assigns.enabled_tests) == 0 ->
        {:error, "Please select at least one test to run"}

      socket.assigns.base_url == "" ->
        {:error, "Please configure a valid BASE_URL (e.g., https://your-scim-server.com)"}

      socket.assigns.bearer_token == "" ->
        {:error, "Please configure a valid BEARER_TOKEN"}

      socket.assigns.client == nil ->
        {:error, "SCIM client configuration failed"}

      true ->
        :ok
    end
  end

  defp finish_test(socket, test_id, result_map) do
    socket
    |> update(:test_results, fn results -> Map.put(results, test_id, result_map) end)
    |> update(:progress, fn progress -> min(progress + 10, 100) end)
    |> then(fn s ->
      if s.assigns.current_test == test_id, do: assign(s, current_test: nil), else: s
    end)
  end

  defp get_user_schema(nil), do: nil
  defp get_user_schema(schemas), do: Map.get(schemas, SearchAttributes.user_schema_id())

  defp maybe_put_param(row, params, param_key, row_key) do
    case Map.fetch(params, param_key) do
      {:ok, val} -> Map.put(row, row_key, val)
      :error -> row
    end
  end

  defp existing_test_atom(test_id) do
    Enum.find_value(ScimTesting.test_definitions(), fn test_def ->
      if Atom.to_string(test_def.id) == test_id, do: test_def.id
    end)
  end
end
