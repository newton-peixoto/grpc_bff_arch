defmodule App.Application do
  @moduledoc false
alias Repository.UserRepository

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UserRepository,
      {GRPC.Server.Supervisor, {App.Endpoint, 9000}}
    ]

    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
