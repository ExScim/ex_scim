defmodule ScimTesterWeb.ScimComponents do
  @moduledoc """
  Shared function components for the SCIM tester UI: the connection panel
  (config form + capability discovery) and the full-output and settings modals.
  """

  use ScimTesterWeb, :html

  alias ScimTester.Capabilities

  attr(:base_url, :string, required: true)
  attr(:bearer_token, :string, required: true)
  attr(:client, :any, required: true)
  attr(:running, :boolean, required: true)
  attr(:capabilities, :any, required: true)

  def connection_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl border border-base-300">
      <div class="card-body">
        <h2 class="card-title mb-4">Connection</h2>

        <form
          phx-change="update_config"
          phx-debounce="500"
          class="space-y-4"
          autocomplete="off"
          phx-hook="ConfigPersistence"
          id="config-form"
        >
          <.input
            type="url"
            name="base_url"
            id="base_url"
            value={@base_url}
            label="Base URL"
            placeholder="https://api.example.com/scim/v2"
            disabled={@running}
            autocomplete="on"
          />
          <.input
            type="text"
            name="bearer_token"
            id="bearer_token"
            value={@bearer_token}
            label="Bearer Token"
            placeholder="Enter your bearer token"
            disabled={@running}
            autocomplete="on"
          />
        </form>

        <div class="mt-4 flex gap-2">
          <button
            phx-click="connect"
            disabled={is_nil(@client) or @running or @capabilities == :loading}
            class={[
              "btn flex-1",
              if(is_nil(@client) or @running or @capabilities == :loading,
                do: "btn-disabled",
                else: "btn-primary"
              )
            ]}
          >
            <%= if @capabilities == :loading do %>
              <span class="loading loading-spinner loading-xs"></span> Connecting...
            <% else %>
              <.icon name="hero-signal" class="size-4" /> {if match?({:ok, _}, @capabilities),
                do: "Reconnect",
                else: "Connect"}
            <% end %>
          </button>
          <button
            phx-click="open_settings"
            class="btn btn-ghost btn-square"
            title="Data generation settings"
          >
            <.icon name="hero-adjustments-horizontal" class="size-5" />
          </button>
        </div>

        <%= if @capabilities do %>
          <div class="divider my-2"></div>

          <%= case @capabilities do %>
            <% :loading -> %>
              <div class="flex items-center space-x-2 text-sm opacity-70">
                <span class="loading loading-spinner loading-xs"></span>
                <span>Discovering capabilities...</span>
              </div>
            <% {:ok, _body} -> %>
              <span class="text-sm font-semibold mb-2">Provider Capabilities</span>
              <div class="space-y-1">
                <%= for {label, supported} <- Capabilities.summary(@capabilities) do %>
                  <div class="flex items-center justify-between text-xs">
                    <span class="opacity-80">{label}</span>
                    <%= if supported do %>
                      <span class="badge badge-success badge-xs">Yes</span>
                    <% else %>
                      <span class="badge badge-error badge-xs">No</span>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%= if length(Capabilities.auth_schemes(@capabilities)) > 0 do %>
                <div class="mt-2">
                  <span class="text-xs opacity-70">Auth Schemes</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for scheme <- Capabilities.auth_schemes(@capabilities) do %>
                      <span class="badge badge-outline badge-xs">
                        {Map.get(scheme, "name", "Unknown")}
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% {:error, _reason} -> %>
              <div class="flex items-center space-x-2 text-warning text-xs">
                <.icon name="hero-exclamation-triangle" class="size-3" />
                <span>Could not fetch capabilities</span>
              </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:modal_output, :any, required: true)

  def output_modal(assigns) do
    ~H"""
    <%= if @modal_output do %>
      <div class="modal modal-open" phx-window-keydown="close_modal" phx-key="Escape">
        <div class="modal-box max-w-4xl max-h-[80vh] flex flex-col">
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-bold text-lg">
              {if @modal_output.type == "error", do: "Error Details", else: "Response Data"}
              <span class="text-sm font-normal opacity-70 ml-2">({@modal_output.test_name})</span>
            </h3>
            <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost">✕</button>
          </div>

          <div class="flex-1 overflow-auto bg-base-200 rounded-lg p-4">
            <pre class="text-xs whitespace-pre-wrap break-all"><%= @modal_output.content %></pre>
          </div>

          <div class="modal-action"><button phx-click="close_modal" class="btn">Close</button></div>
        </div>

        <div class="modal-backdrop" phx-click="close_modal"></div>
      </div>
    <% end %>
    """
  end

  attr(:settings_open, :boolean, required: true)
  attr(:data_gen_config, :map, required: true)

  def settings_modal(assigns) do
    ~H"""
    <%= if @settings_open do %>
      <div class="modal modal-open" phx-window-keydown="close_settings" phx-key="Escape">
        <div class="modal-box max-w-lg">
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-bold text-lg">
              <.icon name="hero-adjustments-horizontal" class="size-5 inline mr-1" />
              Data Generation Settings
            </h3>
            <button phx-click="close_settings" class="btn btn-sm btn-circle btn-ghost">✕</button>
          </div>

          <form phx-change="update_data_gen" phx-debounce="300" id="data-gen-form">
            <!-- Mode Selector -->
            <div class="mb-4">
              <label class="label">
                <span class="label-text font-semibold">Generation Mode</span>
              </label>
              <div class="flex flex-col gap-2">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="mode"
                    value="default"
                    class="radio radio-primary radio-sm"
                    checked={@data_gen_config.mode == :default}
                  />
                  <div>
                    <span class="text-sm font-medium">Default</span>
                    <span class="text-xs opacity-70 block">Fixed lists, example.com domain</span>
                  </div>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="mode"
                    value="custom"
                    class="radio radio-primary radio-sm"
                    checked={@data_gen_config.mode == :custom}
                  />
                  <div>
                    <span class="text-sm font-medium">Custom Lists</span>
                    <span class="text-xs opacity-70 block">Your own names, titles, and domain</span>
                  </div>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="mode"
                    value="random"
                    class="radio radio-primary radio-sm"
                    checked={@data_gen_config.mode == :random}
                  />
                  <div>
                    <span class="text-sm font-medium">Realistic Random</span>
                    <span class="text-xs opacity-70 block">
                      Algorithmically generated plausible names
                    </span>
                  </div>
                </label>
              </div>
            </div>

            <div class="divider my-2"></div>
            
    <!-- Domain fields (always visible) -->
            <div class="space-y-3 mb-4">
              <div>
                <label class="label"><span class="label-text text-sm">Email Domain</span></label>
                <input
                  type="text"
                  name="email_domain"
                  value={@data_gen_config.email_domain}
                  placeholder="example.com"
                  class="input input-bordered input-sm w-full"
                />
              </div>
              <div>
                <label class="label"><span class="label-text text-sm">URL Domain</span></label>
                <input
                  type="text"
                  name="url_domain"
                  value={@data_gen_config.url_domain}
                  placeholder="example.com"
                  class="input input-bordered input-sm w-full"
                />
              </div>
            </div>
            <!-- Custom list fields (shown only for custom mode) -->
            <%= if @data_gen_config.mode == :custom do %>
              <div class="space-y-3 mb-4">
                <div>
                  <label class="label">
                    <span class="label-text text-sm">First Names</span>
                    <span class="label-text-alt text-xs opacity-60">comma-separated</span>
                  </label>
                  <textarea
                    name="first_names"
                    rows="2"
                    placeholder="John, Jane, Alice, Bob"
                    class="textarea textarea-bordered textarea-sm w-full"
                  ><%= Enum.join(@data_gen_config.first_names, ", ") %></textarea>
                </div>
                <div>
                  <label class="label">
                    <span class="label-text text-sm">Last Names</span>
                    <span class="label-text-alt text-xs opacity-60">comma-separated</span>
                  </label>
                  <textarea
                    name="last_names"
                    rows="2"
                    placeholder="Smith, Johnson, Williams, Brown"
                    class="textarea textarea-bordered textarea-sm w-full"
                  ><%= Enum.join(@data_gen_config.last_names, ", ") %></textarea>
                </div>
                <div>
                  <label class="label">
                    <span class="label-text text-sm">Job Titles</span>
                    <span class="label-text-alt text-xs opacity-60">comma-separated</span>
                  </label>
                  <textarea
                    name="job_titles"
                    rows="2"
                    placeholder="Software Engineer, Product Manager, Designer"
                    class="textarea textarea-bordered textarea-sm w-full"
                  ><%= Enum.join(@data_gen_config.job_titles, ", ") %></textarea>
                </div>
              </div>
            <% end %>
          </form>

          <div class="modal-action">
            <button phx-click="reset_data_gen" class="btn btn-ghost btn-sm">Reset to Defaults</button>
            <button phx-click="close_settings" class="btn btn-primary btn-sm">Done</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_settings"></div>
      </div>
    <% end %>
    """
  end
end
