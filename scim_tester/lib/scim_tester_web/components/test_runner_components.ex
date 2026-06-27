defmodule ScimTesterWeb.TestRunnerComponents do
  @moduledoc """
  Function components for the test-runner page: the sidebar summary, the status
  panel with start/stop controls, the test card grid, and the live log feed.
  """

  use ScimTesterWeb, :html

  alias ScimTester.Capabilities
  alias ScimTester.ScimTesting

  @max_output_length 500

  attr(:enabled_tests, :any, required: true)
  attr(:test_results, :map, required: true)
  attr(:progress, :integer, required: true)

  def test_summary(assigns) do
    ~H"""
    <div class="mt-6 card bg-base-100 shadow-xl border border-base-300">
      <div class="card-body">
        <h3 class="card-title">Test Summary</h3>

        <.list>
          <:item title="Selected">
            <span class="font-semibold">
              {MapSet.size(@enabled_tests)} / {length(ScimTesting.test_definitions())}
            </span>
          </:item>

          <:item title="Passed">
            <span class="text-success font-semibold">
              {count_status(@test_results, :success)}
            </span>
          </:item>

          <:item title="Failed">
            <span class="text-error font-semibold">
              {count_status(@test_results, :error)}
            </span>
          </:item>

          <:item title="Running">
            <span class="text-primary font-semibold">
              {count_status(@test_results, :running)}
            </span>
          </:item>
        </.list>
        <!-- Progress Bar -->
        <div class="mt-4">
          <div class="flex justify-between text-sm mb-2">
            <span>Progress</span> <span>{@progress}%</span>
          </div>

          <progress class="progress progress-primary w-full" value={@progress} max="100"></progress>
        </div>
      </div>
    </div>
    """
  end

  attr(:running, :boolean, required: true)
  attr(:client, :any, required: true)
  attr(:progress, :integer, required: true)
  attr(:enabled_tests, :any, required: true)

  def test_status(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl border border-base-300 mb-8">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="flex flex-col">
              <h2 class="text-xl font-bold">Test Status</h2>

              <div class="flex items-center space-x-2 mt-1">
                <%= if @running do %>
                  <span class="loading loading-spinner loading-sm text-primary"></span>
                  <span class="text-primary font-medium">Running Tests</span>
                <% else %>
                  <%= if @client do %>
                    <div class="w-3 h-3 bg-success rounded-full"></div>
                    <span class="text-success font-medium">Ready to Run</span>
                  <% else %>
                    <div class="w-3 h-3 bg-warning rounded-full"></div>
                    <span class="text-warning font-medium">Configuration Required</span>
                  <% end %>
                <% end %>
              </div>
            </div>

            <%= if @progress > 0 do %>
              <div class="text-right">
                <div class="text-2xl font-bold text-success">{@progress}%</div>

                <div class="text-sm opacity-70">Complete</div>
              </div>
            <% end %>
          </div>
          <!-- Start Button -->
          <div class="flex-none">
            <%= if @running do %>
              <.button phx-click="stop_tests" class="btn btn-error">
                <.icon name="hero-stop-solid" class="size-5 mr-2" /> Stop Tests
              </.button>
            <% else %>
              <.button
                phx-click="start_tests"
                disabled={is_nil(@client) or MapSet.size(@enabled_tests) == 0}
                class="btn btn-primary"
              >
                <.icon name="hero-play-solid" class="size-5 mr-2" /> Start Tests
              </.button>
            <% end %>
          </div>
        </div>

        <%= if @progress > 0 and @progress < 100 do %>
          <progress class="progress progress-primary w-full mt-4" value={@progress} max="100">
          </progress>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:test_results, :map, required: true)
  attr(:enabled_tests, :any, required: true)
  attr(:client, :any, required: true)
  attr(:running, :boolean, required: true)
  attr(:current_test, :atom, default: nil)
  attr(:capabilities, :any, default: nil)

  def test_grid(assigns) do
    ~H"""
    <!-- Test Grid Header -->
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold">Test Cases</h2>

      <div class="flex items-center space-x-2">
        <button
          phx-click="toggle_all_tests"
          phx-value-action="enable"
          disabled={@running}
          class={["btn btn-sm", if(@running, do: "btn-disabled", else: "btn-outline")]}
        >
          Select All
        </button>
        <button
          phx-click="toggle_all_tests"
          phx-value-action="disable"
          disabled={@running}
          class={["btn btn-sm", if(@running, do: "btn-disabled", else: "btn-outline")]}
        >
          Deselect All
        </button>
      </div>
    </div>
    <!-- Warning when no tests selected -->
    <%= if MapSet.size(@enabled_tests) == 0 do %>
      <div class="alert alert-warning mb-4">
        <.icon name="hero-exclamation-triangle" class="size-5" />
        <span>No tests selected. Please select at least one test to run.</span>
      </div>
    <% end %>
    <!-- Test Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
      <%= for test_def <- ScimTesting.test_definitions() do %>
        <.test_card
          test_def={test_def}
          test_result={
            Map.get(@test_results, test_def.id, %{status: :pending, result: nil, error: nil})
          }
          is_enabled={MapSet.member?(@enabled_tests, test_def.id)}
          client={@client}
          running={@running}
          current_test={@current_test}
          capabilities={@capabilities}
        />
      <% end %>
    </div>
    """
  end

  attr(:logs, :list, required: true)

  def live_logs(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl border border-base-300">
      <div class="card-body">
        <div class="flex items-center justify-between mb-4">
          <h3 class="card-title">Live Test Logs</h3>

          <%= if length(@logs) > 0 do %>
            <div class="badge badge-neutral">{length(@logs)} entries</div>
          <% end %>
        </div>

        <%= if length(@logs) == 0 do %>
          <div class="text-center py-8 opacity-50">
            <.icon name="hero-document-text" class="size-12 mx-auto mb-4" />
            <p class="text-sm">No logs yet. Start tests to see updates.</p>
          </div>
        <% else %>
          <div class="space-y-2 max-h-96 overflow-y-auto">
            <%= for log <- Enum.reverse(@logs) do %>
              <div class="flex items-center space-x-3 py-2 px-3 rounded-lg bg-base-200 hover:bg-base-300 transition-colors">
                <div class="text-xs opacity-70 font-mono flex-shrink-0">
                  {Calendar.strftime(log.timestamp, "%H:%M:%S")}
                </div>

                <div class={["flex-shrink-0", log_color(log.level)]}>
                  <.log_icon level={log.level} class="size-4 block" />
                </div>

                <div class={["flex-1 text-sm font-mono", log_color(log.level)]}>
                  {log.message}
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:test_def, :map, required: true)
  attr(:test_result, :map, required: true)
  attr(:is_enabled, :boolean, required: true)
  attr(:client, :any)
  attr(:running, :boolean)
  attr(:current_test, :atom)
  attr(:capabilities, :any)

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

              <%= if not @is_enabled and Capabilities.test_unsupported_by_provider?(@capabilities, @test_def.id) do %>
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

  defp count_status(test_results, status) do
    Enum.count(test_results, fn {_, result} -> result.status == status end)
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

  defp truncate_output(data) do
    output = inspect(data, pretty: true, limit: 50, width: 60)

    if String.length(output) > @max_output_length do
      String.slice(output, 0, @max_output_length) <> "\n..."
    else
      output
    end
  end
end
