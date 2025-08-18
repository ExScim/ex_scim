defmodule ExScim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Starts a worker by calling: ExScim.Worker.start_link(arg)
        # {ExScim.Worker, arg}
      ] ++ storage_adapter()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExScim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp storage_adapter() do
    case ExScim.Storage.adapter() do
      ExScim.Storage.EtsStorage -> [ExScim.Storage.EtsStorage]
      _ -> []
    end
  end
end
