defmodule ClientWeb.ScimClientDemoLive do
  use ClientWeb, :live_view

  alias ExScimClient.Client, as: ScimClient
  alias ExScimClient.Filter
  alias ExScimClient.Resources.{Groups, ServiceProviderConfig, Users}
  alias Client.ScimTesting

  @user_attributes [
    {"userName", "userName"},
    {"displayName", "displayName"},
    {"name.givenName", "name.givenName"},
    {"name.familyName", "name.familyName"},
    {"emails.value", "emails.value"},
    {"active", "active"},
    {"title", "title"},
    {"userType", "userType"},
    {"externalId", "externalId"},
    {"id", "id"},
    {"meta.created", "meta.created"},
    {"meta.lastModified", "meta.lastModified"}
  ]

  @group_attributes [
    {"displayName", "displayName"},
    {"id", "id"},
    {"externalId", "externalId"},
    {"members.value", "members.value"},
    {"members.display", "members.display"},
    {"meta.created", "meta.created"},
    {"meta.lastModified", "meta.lastModified"}
  ]

  @filter_operators [
    {"eq", "equals"},
    {"ne", "not equal"},
    {"co", "contains"},
    {"sw", "starts with"},
    {"ew", "ends with"},
    {"gt", "greater than"},
    {"ge", "greater or equal"},
    {"lt", "less than"},
    {"le", "less or equal"},
    {"pr", "present"}
  ]

  @capability_display_items [
    {"patch", "PATCH Operations"},
    {"bulk", "Bulk Operations"},
    {"filter", "Filtering"},
    {"changePassword", "Change Password"},
    {"sort", "Sorting"},
    {"etag", "ETags"}
  ]

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
        search_start_index: 1
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

  def handle_event("update_config", params, socket) do
    base_url = Map.get(params, "base_url", socket.assigns.base_url)
    bearer_token = Map.get(params, "bearer_token", socket.assigns.bearer_token)
    {:noreply, apply_config(socket, base_url, bearer_token)}
  end

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
    test_atom = String.to_existing_atom(test_id)
    send(self(), {:retry_test, test_atom})

    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_atom, %{status: :running, result: nil, error: nil})
      end)

    {:noreply, socket}
  end

  def handle_event(
        "config_loaded",
        %{"base_url" => base_url, "bearer_token" => bearer_token},
        socket
      ) do
    {:noreply, apply_config(socket, base_url, bearer_token)}
  end

  def handle_event("connect", _params, socket) do
    socket =
      socket
      |> assign(capabilities_applied: false)
      |> maybe_fetch_capabilities(socket.assigns.client)

    {:noreply, socket}
  end

  def handle_event("toggle_test", %{"test-id" => test_id}, socket) do
    test_atom = String.to_existing_atom(test_id)
    enabled_tests = socket.assigns.enabled_tests

    enabled_tests =
      if MapSet.member?(enabled_tests, test_atom),
        do: ScimTesting.disable_test(test_atom, enabled_tests),
        else: ScimTesting.enable_test(test_atom, enabled_tests)

    {:noreply, assign(socket, enabled_tests: enabled_tests)}
  end

  def handle_event("toggle_all_tests", %{"action" => "enable"}, socket) do
    {:noreply, assign(socket, enabled_tests: ScimTesting.default_enabled_tests())}
  end

  def handle_event("toggle_all_tests", %{"action" => "disable"}, socket) do
    {:noreply, assign(socket, enabled_tests: MapSet.new())}
  end

  def handle_event("show_full_output", %{"test_id" => test_id, "type" => type}, socket) do
    test_atom = String.to_existing_atom(test_id)
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

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal_output: nil)}
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
      attribute: default_attr(socket.assigns.search_resource_type),
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
      content = Jason.encode!(resource, pretty: true)

      modal_output = %{
        test_id: :search_result,
        test_name: "#{socket.assigns.search_resource_type} Resource",
        type: "result",
        content: content
      }

      {:noreply, assign(socket, modal_output: modal_output)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:run_search, socket) do
    live_view_pid = self()
    client = socket.assigns.client
    resource_type = socket.assigns.search_resource_type
    filter_rows = socket.assigns.search_filter_rows
    combinator = socket.assigns.search_combinator
    page_size = socket.assigns.search_page_size
    start_index = socket.assigns.search_start_index

    Task.start(fn ->
      result =
        try do
          filter = build_filter(filter_rows, combinator)
          pagination = ExScimClient.Pagination.new(page_size, start_index)

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

    {:ok, task_pid} =
      Task.start(fn ->
        ScimTesting.run_all_tests(live_view_pid, socket.assigns.client, enabled_tests)
      end)

    socket = assign(socket, test_task_pid: task_pid)
    {:noreply, socket}
  end

  def handle_info({:retry_test, test_id}, socket) do
    live_view_pid = self()

    Task.start(fn ->
      ScimTesting.run_single_test(
        live_view_pid,
        socket.assigns.client,
        test_id,
        socket.assigns.created_user_id
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
    message =
      case reason do
        msg when is_binary(msg) -> msg
        other -> inspect(other)
      end

    {:noreply, assign(socket, capabilities: {:error, message})}
  end

  def test_definitions, do: ScimTesting.test_definitions()

  def capability_supported?(capabilities, key) do
    case capabilities do
      {:ok, body} -> get_in(body, [key, "supported"]) == true
      _ -> nil
    end
  end

  def capabilities_summary(capabilities) do
    Enum.map(@capability_display_items, fn {key, label} ->
      {label, capability_supported?(capabilities, key)}
    end)
  end

  def auth_schemes(capabilities) do
    case capabilities do
      {:ok, body} -> Map.get(body, "authenticationSchemes", [])
      _ -> []
    end
  end

  def test_unsupported_by_provider?(capabilities, test_id) do
    case capabilities do
      {:ok, body} ->
        disabled = ScimTesting.tests_disabled_by_capabilities(body)
        test_id in disabled

      _ ->
        false
    end
  end

  def filter_operators, do: @filter_operators

  def attribute_options("Users"), do: @user_attributes
  def attribute_options("Groups"), do: @group_attributes
  def attribute_options(_), do: @user_attributes

  def build_request_preview(assigns) do
    resource_path = if assigns.search_resource_type == "Users", do: "/Users", else: "/Groups"
    filter = build_filter(assigns.search_filter_rows, assigns.search_combinator)

    params =
      %{
        "count" => to_string(assigns.search_page_size),
        "startIndex" => to_string(assigns.search_start_index)
      }
      |> then(fn p ->
        if filter, do: Map.put(p, "filter", Filter.build(filter)), else: p
      end)

    query = URI.encode_query(params)
    path = assigns.base_url <> resource_path
    "GET #{path}?#{query}"
  end

  def get_primary_email(resource) do
    emails = Map.get(resource, "emails", [])
    primary = Enum.find(emails, List.first(emails), &Map.get(&1, "primary"))
    if primary, do: Map.get(primary, "value", "-"), else: "-"
  end

  attr :test_def, :map, required: true
  attr :test_result, :map, required: true
  attr :is_enabled, :boolean, required: true
  attr :client, :any
  attr :running, :boolean
  attr :current_test, :atom
  attr :capabilities, :any

  defp test_card(assigns) do
    ~H"""
    <div class={[
      "card bg-base-100 shadow-xl transition-all duration-200 hover:shadow-2xl border border-base-300 border-l-4",
      case @test_result.status do
        :pending -> "border-l-base-300"
        :running -> "border-l-primary"
        :success -> "border-l-success"
        :error -> "border-l-error"
      end,
      if(!@is_enabled, do: "opacity-50", else: "")
    ]}>
      <div class="card-body">
        <!-- Test Header -->
        <div class="flex items-start justify-between mb-4">
          <div class="flex items-center space-x-3">
            <input
              type="checkbox"
              class="checkbox checkbox-primary"
              checked={@is_enabled}
              phx-click="toggle_test"
              phx-value-test-id={@test_def.id}
              disabled={@running}
            />
            <div class={[
              "w-10 h-10 rounded-lg flex items-center justify-center text-lg",
              cond do
                @test_result.status == :running -> "bg-primary/20"
                @test_result.status == :success -> "bg-success/20"
                @test_result.status == :error -> "bg-error/20"
                is_nil(@client) -> "bg-base-200 opacity-50"
                @running -> "bg-warning/20"
                true -> "bg-base-300"
              end
            ]}>
              <.icon name={@test_def.icon} />
            </div>

            <div>
              <h3 class="card-title text-base">{@test_def.name}</h3>

              <p class="text-sm opacity-70">{@test_def.description}</p>

              <%= if not @is_enabled and test_unsupported_by_provider?(@capabilities, @test_def.id) do %>
                <p class="text-xs text-warning mt-0.5">
                  <.icon name="hero-exclamation-triangle" class="size-3 inline" />
                  Not supported by provider
                </p>
              <% end %>
            </div>
          </div>
          <!-- Status Badge -->
          <div class="flex items-center gap-1">
            <%= if @test_result.status in [:success, :error] and not @running do %>
              <button
                phx-click="retry_test"
                phx-value-test_id={@test_def.id}
                class="btn btn-ghost btn-xs btn-circle"
                title="Re-run this test"
              >
                <.icon name="hero-arrow-path" class="size-3.5" />
              </button>
            <% end %>

            <div class={["badge", badge_class(@test_result.status, @client, @running)]}>
              {badge_text(@test_result.status, @client, @running)}
            </div>
          </div>
        </div>
        <!-- Test Status -->
        <%= case @test_result.status do %>
          <% :running -> %>
            <div class="flex items-center space-x-2 text-primary">
              <span class="loading loading-spinner loading-xs"></span>
              <span class="text-sm font-medium">Executing...</span>
            </div>
          <% :success -> %>
            <div class="space-y-2">
              <div class="flex items-center space-x-2 text-success">
                <.icon name="hero-check-circle" class="size-4" />
                <span class="text-sm font-medium">Test passed</span>
              </div>

              <%= if @test_result.result do %>
                <details class="collapse bg-base-200">
                  <summary class="collapse-title text-xs cursor-pointer">View response data</summary>

                  <div class="collapse-content">
                    <div class="max-h-32 overflow-auto">
                      <pre class="text-xs whitespace-pre-wrap break-all"><%= truncate_output(@test_result.result) %></pre>
                    </div>

                    <button
                      phx-click="show_full_output"
                      phx-value-test_id={@test_def.id}
                      phx-value-type="result"
                      class="btn btn-xs btn-ghost mt-2"
                    >
                      View full output
                    </button>
                  </div>
                </details>
              <% end %>
            </div>
          <% :error -> %>
            <div class="space-y-2">
              <div class="flex items-center space-x-2 text-error">
                <.icon name="hero-x-circle" class="size-4" />
                <span class="text-sm font-medium">Test failed</span>
              </div>

              <%= if @test_result.error do %>
                <div class="alert alert-error">
                  <div class="flex-1 min-w-0">
                    <div class="max-h-24 overflow-auto">
                      <p class="text-xs font-mono whitespace-pre-wrap break-all">
                        {truncate_output(@test_result.error)}
                      </p>
                    </div>

                    <button
                      phx-click="show_full_output"
                      phx-value-test_id={@test_def.id}
                      phx-value-type="error"
                      class="btn btn-xs btn-ghost mt-2"
                    >
                      View full output
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% :pending -> %>
            <%= cond do %>
              <% is_nil(@client) -> %>
                <div class="flex items-center space-x-2 opacity-50">
                  <.icon name="hero-exclamation-triangle" class="size-4" />
                  <span class="text-sm">Configuration required</span>
                </div>
              <% @running -> %>
                <div class="flex items-center space-x-2 text-warning">
                  <span class="loading loading-dots loading-xs"></span>
                  <span class="text-sm">Waiting in queue</span>
                </div>
              <% true -> %>
                <div class="flex items-center space-x-2 opacity-70">
                  <div class="w-4 h-4 border border-base-300 rounded-full"></div>
                  <span class="text-sm">Ready to run</span>
                </div>
            <% end %>
        <% end %>
        <!-- Active Test Indicator -->
        <%= if @current_test == @test_def.id do %>
          <div class="mt-3 alert alert-info">
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 bg-primary rounded-full animate-pulse"></div>
              <span class="text-xs font-medium">Currently executing</span>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp badge_class(status, client, running) do
    cond do
      status == :running -> "badge-primary"
      status == :success -> "badge-success"
      status == :error -> "badge-error"
      is_nil(client) -> "badge-neutral opacity-50"
      running -> "badge-warning"
      true -> "badge-neutral"
    end
  end

  defp badge_text(status, client, running) do
    cond do
      status == :running -> "Running"
      status == :success -> "Passed"
      status == :error -> "Failed"
      is_nil(client) -> "Not Ready"
      running -> "Waiting"
      true -> "Ready"
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

  defp apply_config(socket, base_url, bearer_token) do
    {normalized_base_url, client} = create_scim_client(base_url, bearer_token)

    assign(socket,
      base_url: normalized_base_url,
      bearer_token: bearer_token,
      client: client,
      capabilities: nil,
      capabilities_applied: false
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

  defp create_scim_client("", _bearer_token), do: {"", nil}
  defp create_scim_client(_base_url, ""), do: {"", nil}

  defp create_scim_client(base_url, bearer_token) do
    normalized_base_url = normalize_base_url(base_url)
    client = ScimClient.new(normalized_base_url, bearer_token)
    {normalized_base_url, client}
  end

  defp normalize_base_url(base_url) do
    base_url = String.trim_trailing(base_url, "/")

    if String.ends_with?(base_url, "/scim/v2") do
      base_url
    else
      base_url <> "/scim/v2"
    end
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

  defp default_attr("Users"), do: "userName"
  defp default_attr("Groups"), do: "displayName"
  defp default_attr(_), do: "userName"

  defp maybe_put_param(row, params, param_key, row_key) do
    case Map.fetch(params, param_key) do
      {:ok, val} -> Map.put(row, row_key, val)
      :error -> row
    end
  end

  defp build_filter(rows, combinator) do
    valid_rows =
      Enum.filter(rows, fn row ->
        row.attribute != "" and row.operator != "" and
          (row.operator == "pr" or (row.value != nil and row.value != ""))
      end)

    case valid_rows do
      [] ->
        nil

      [single] ->
        build_single_filter(single)

      [first | rest] ->
        combine_fn = if combinator == "or", do: &Filter.or1/2, else: &Filter.and1/2

        Enum.reduce(rest, build_single_filter(first), fn row, acc ->
          combine_fn.(acc, build_single_filter(row))
        end)
    end
  end

  defp build_single_filter(%{attribute: attr, operator: op, value: val}) do
    filter = Filter.new()

    case op do
      "eq" -> Filter.equals(filter, attr, val)
      "ne" -> Filter.not_equal(filter, attr, val)
      "co" -> Filter.contains(filter, attr, val)
      "sw" -> Filter.starts_with(filter, attr, val)
      "ew" -> Filter.ends_with(filter, attr, val)
      "gt" -> Filter.greater_than(filter, attr, val)
      "ge" -> Filter.greater_or_equal(filter, attr, val)
      "lt" -> Filter.less_than(filter, attr, val)
      "le" -> Filter.less_or_equal(filter, attr, val)
      "pr" -> Filter.present(filter, attr, nil)
    end
  end

  defp log_icon(%{level: :start} = assigns) do
    ~H"""
    <.icon name="hero-rocket-launch-solid" class={@class} />
    """
  end

  defp log_icon(%{level: :running} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="size-4"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M5 13a7 7 0 1 0 14 0a7 7 0 0 0 -14 0" /><path d="M14.5 10.5l-2.5 2.5" /><path d="M17 8l1 -1" /><path d="M14 3h-4" />
    </svg>
    """
  end

  defp log_icon(%{level: :success} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="size-4"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M9 11l3 3l8 -8" /><path d="M20 12v6a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2h9" />
    </svg>
    """
  end

  defp log_icon(%{level: :error} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="size-4"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 5a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14" /><path d="M12 8v4" /><path d="M12 16h.01" />
    </svg>
    """
  end

  defp log_icon(%{level: :warning} = assigns) do
    ~H"""
    <.icon name="hero-stop" class={@class} />
    """
  end

  defp log_color(:start), do: "text-primary"
  defp log_color(:running), do: "text-info"
  defp log_color(:success), do: "text-success"
  defp log_color(:error), do: "text-error"
  defp log_color(:warning), do: "text-warning"

  @max_output_length 500

  def truncate_output(data) do
    output = inspect(data, pretty: true, limit: 50, width: 60)

    if String.length(output) > @max_output_length do
      String.slice(output, 0, @max_output_length) <> "\n..."
    else
      output
    end
  end
end
