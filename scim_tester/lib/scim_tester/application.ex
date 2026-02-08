defmodule ScimTester.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ScimTesterWeb.Telemetry,
      {Phoenix.PubSub, name: ScimTester.PubSub},
      # Start to serve requests, typically the last entry
      ScimTesterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ScimTester.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ScimTesterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
