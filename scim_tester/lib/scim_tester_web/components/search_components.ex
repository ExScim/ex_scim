defmodule ScimTesterWeb.SearchComponents do
  @moduledoc """
  Function components for the search page: the sidebar stats, the query composer
  (filter rows, combinators, request preview), and the results table with
  pagination.
  """

  use ScimTesterWeb, :html

  alias ExScimClient.Filter
  alias ScimTester.FilterBuilder
  alias ScimTester.SearchAttributes

  attr(:search_results, :map, required: true)

  def search_stats(assigns) do
    ~H"""
    <div class="mt-6 card bg-base-100 shadow-xl border border-base-300">
      <div class="card-body">
        <h3 class="card-title">Search Stats</h3>

        <.list>
          <:item title="Total Results">
            <span class="font-semibold">{Map.get(@search_results, "totalResults", 0)}</span>
          </:item>

          <:item title="Per Page">
            <span class="font-semibold">{Map.get(@search_results, "itemsPerPage", "-")}</span>
          </:item>

          <:item title="Start Index">
            <span class="font-semibold">{Map.get(@search_results, "startIndex", "-")}</span>
          </:item>

          <:item title="Returned">
            <span class="font-semibold">{length(Map.get(@search_results, "Resources", []))}</span>
          </:item>
        </.list>
      </div>
    </div>
    """
  end

  attr(:client, :any, required: true)
  attr(:base_url, :string, required: true)
  attr(:search_resource_type, :string, required: true)
  attr(:schemas, :any, required: true)
  attr(:schemas_loading, :boolean, required: true)
  attr(:enabled_schemas, :any, required: true)
  attr(:capabilities, :any, required: true)
  attr(:search_filter_rows, :list, required: true)
  attr(:search_combinator, :string, required: true)
  attr(:search_loading, :boolean, required: true)
  attr(:search_page_size, :integer, required: true)
  attr(:search_start_index, :integer, required: true)

  def search_composer(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl border border-base-300 mb-8">
      <div class="card-body">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold">Search & Query Composer</h2>

          <select
            phx-change="search_resource_type"
            name="resource_type"
            class="select select-bordered select-sm"
          >
            <option value="Users" selected={@search_resource_type == "Users"}>Users</option>
            <option value="Groups" selected={@search_resource_type == "Groups"}>Groups</option>
          </select>
        </div>

        <%= if @search_resource_type == "Users" do %>
          <div class="flex items-center gap-3 mb-2">
            <%= if @schemas_loading do %>
              <span class="loading loading-spinner loading-xs opacity-50"></span>
              <span class="text-xs opacity-50">Loading schemas...</span>
            <% else %>
              <%= if @schemas && Map.has_key?(@schemas, SearchAttributes.enterprise_user_schema_id()) do %>
                <label class="flex items-center gap-1.5 cursor-pointer">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-xs checkbox-primary"
                    checked={
                      MapSet.member?(@enabled_schemas, SearchAttributes.enterprise_user_schema_id())
                    }
                    phx-click="toggle_schema"
                    phx-value-schema-id={SearchAttributes.enterprise_user_schema_id()}
                  />
                  <span class="text-xs">Enterprise User</span>
                </label>
              <% end %>

              <%= if is_nil(@schemas) && match?({:ok, _}, @capabilities) do %>
                <div class="flex items-center gap-1">
                  <.icon name="hero-exclamation-triangle" class="size-3 text-warning" />
                  <span class="text-xs text-warning">Schema fetch failed, using defaults</span>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>

        <%= if is_nil(@client) do %>
          <div class="text-center py-12 opacity-50">
            <.icon name="hero-magnifying-glass" class="size-16 mx-auto mb-4 opacity-30" />
            <p class="text-sm">Connect to a SCIM provider to start building queries.</p>
          </div>
        <% else %>
          <!-- Filter Rows -->
          <div class="space-y-3 mb-4">
            <%= for {row, idx} <- Enum.with_index(@search_filter_rows) do %>
              <.filter_row
                row={row}
                idx={idx}
                search_resource_type={@search_resource_type}
                schemas={@schemas}
                enabled_schemas={@enabled_schemas}
                search_combinator={@search_combinator}
              />
            <% end %>
          </div>
          <!-- Add Row + Execute -->
          <div class="flex items-center justify-between mb-4">
            <button phx-click="add_filter_row" class="btn btn-outline btn-sm">
              <.icon name="hero-plus" class="size-4" /> Add Filter
            </button>

            <button
              phx-click="execute_search"
              disabled={@search_loading}
              class={["btn btn-primary btn-sm", if(@search_loading, do: "btn-disabled", else: "")]}
            >
              <%= if @search_loading do %>
                <span class="loading loading-spinner loading-xs"></span> Searching...
              <% else %>
                <.icon name="hero-magnifying-glass" class="size-4" /> Search
              <% end %>
            </button>
          </div>
          <!-- Request Preview -->
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-xs opacity-70 mb-1">Request Preview</div>
            <code class="text-sm font-mono text-primary break-all">
              {build_request_preview(assigns)}
            </code>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:row, :map, required: true)
  attr(:idx, :integer, required: true)
  attr(:search_resource_type, :string, required: true)
  attr(:schemas, :any, required: true)
  attr(:enabled_schemas, :any, required: true)
  attr(:search_combinator, :string, required: true)

  defp filter_row(assigns) do
    ~H"""
    <%= if @idx > 0 do %>
      <div class="flex justify-center">
        <select
          id={"filter-combinator-#{@row.id}"}
          phx-change="search_combinator"
          name="combinator"
          class="select select-bordered select-xs"
        >
          <option value="and" selected={@search_combinator == "and"}>AND</option>
          <option value="or" selected={@search_combinator == "or"}>OR</option>
        </select>
      </div>
    <% end %>

    <form id={"filter-row-form-#{@row.id}"} phx-change="update_filter_row">
      <input type="hidden" name="row-id" value={@row.id} />
      <div class="flex items-center gap-2 bg-base-200 rounded-lg p-3">
        <select
          id={"filter-attr-#{@row.id}"}
          name="attribute"
          class="select select-bordered select-sm flex-1"
        >
          <%= for {group_label, attrs} <- SearchAttributes.options(@search_resource_type, @schemas, @enabled_schemas) do %>
            <optgroup label={group_label}>
              <%= for {value, label} <- attrs do %>
                <option value={value} selected={@row.attribute == value}>{label}</option>
              <% end %>
            </optgroup>
          <% end %>
        </select>

        <select
          id={"filter-op-#{@row.id}"}
          name="operator"
          class="select select-bordered select-sm w-36"
        >
          <%= for {value, label} <- FilterBuilder.operators() do %>
            <option value={value} selected={@row.operator == value}>{label}</option>
          <% end %>
        </select>

        <%= if @row.operator != "pr" do %>
          <input
            id={"filter-val-#{@row.id}"}
            type="text"
            phx-debounce="300"
            name="value"
            value={@row.value}
            placeholder="Value"
            class="input input-bordered input-sm flex-1"
          />
        <% end %>

        <button
          type="button"
          phx-click="remove_filter_row"
          phx-value-row-id={@row.id}
          class="btn btn-ghost btn-sm btn-circle"
          title="Remove filter"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </form>
    """
  end

  attr(:search_results, :map, required: true)
  attr(:search_resource_type, :string, required: true)
  attr(:search_page_size, :integer, required: true)
  attr(:search_start_index, :integer, required: true)

  def search_results(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl border border-base-300">
      <div class="card-body">
        <div class="flex items-center justify-between mb-4">
          <h3 class="card-title">Results</h3>
          <div class="flex items-center gap-2">
            <span class="badge badge-neutral">
              {Map.get(@search_results, "totalResults", 0)} total
            </span>
          </div>
        </div>

        <%= if @search_resource_type == "Users" do %>
          <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
              <thead>
                <tr>
                  <th>userName</th>
                  <th>displayName</th>
                  <th>email</th>
                  <th>active</th>
                  <th>id</th>
                </tr>
              </thead>
              <tbody>
                <%= for {resource, idx} <- Enum.with_index(Map.get(@search_results, "Resources", [])) do %>
                  <tr class="hover cursor-pointer" phx-click="show_resource" phx-value-index={idx}>
                    <td>{Map.get(resource, "userName", "-")}</td>
                    <td>{Map.get(resource, "displayName", "-")}</td>
                    <td>{get_primary_email(resource)}</td>
                    <td>
                      <%= if Map.get(resource, "active") do %>
                        <span class="badge badge-success badge-xs">Yes</span>
                      <% else %>
                        <span class="badge badge-error badge-xs">No</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-xs opacity-70">{Map.get(resource, "id", "-")}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
              <thead>
                <tr>
                  <th>displayName</th>
                  <th>members</th>
                  <th>id</th>
                </tr>
              </thead>
              <tbody>
                <%= for {resource, idx} <- Enum.with_index(Map.get(@search_results, "Resources", [])) do %>
                  <tr class="hover cursor-pointer" phx-click="show_resource" phx-value-index={idx}>
                    <td>{Map.get(resource, "displayName", "-")}</td>
                    <td>{length(Map.get(resource, "members", []))}</td>
                    <td class="font-mono text-xs opacity-70">{Map.get(resource, "id", "-")}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
        <!-- Pagination -->
        <div class="flex items-center justify-between mt-4">
          <div class="flex items-center gap-2">
            <span class="text-sm opacity-70">Per page:</span>
            <select
              phx-change="search_page_size"
              name="page_size"
              class="select select-bordered select-xs"
            >
              <%= for size <- [10, 25, 50, 100] do %>
                <option value={size} selected={@search_page_size == size}>{size}</option>
              <% end %>
            </select>
          </div>

          <div class="join">
            <button
              class="join-item btn btn-sm"
              disabled={@search_start_index <= 1}
              phx-click="search_page"
              phx-value-start_index={max(@search_start_index - @search_page_size, 1)}
            >
              <.icon name="hero-chevron-left" class="size-4" />
            </button>
            <button class="join-item btn btn-sm btn-disabled">
              {div(@search_start_index - 1, @search_page_size) + 1}
            </button>
            <button
              class="join-item btn btn-sm"
              disabled={
                @search_start_index + @search_page_size >
                  Map.get(@search_results, "totalResults", 0)
              }
              phx-click="search_page"
              phx-value-start_index={@search_start_index + @search_page_size}
            >
              <.icon name="hero-chevron-right" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp build_request_preview(assigns) do
    resource_path = if assigns.search_resource_type == "Users", do: "/Users", else: "/Groups"
    filter = FilterBuilder.build(assigns.search_filter_rows, assigns.search_combinator)

    params =
      %{
        "count" => to_string(assigns.search_page_size),
        "startIndex" => to_string(assigns.search_start_index)
      }
      |> then(fn p ->
        if filter, do: Map.put(p, "filter", Filter.build(filter)), else: p
      end)

    "GET #{assigns.base_url <> resource_path}?#{URI.encode_query(params)}"
  end

  defp get_primary_email(resource) do
    emails = Map.get(resource, "emails", [])
    primary = Enum.find(emails, List.first(emails), &Map.get(&1, "primary"))
    if primary, do: Map.get(primary, "value", "-"), else: "-"
  end
end
