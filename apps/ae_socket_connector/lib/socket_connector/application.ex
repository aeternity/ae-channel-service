defmodule SocketConnector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: SocketConnector.Worker.start_link(arg)
      # {SocketConnector.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SocketConnector.Supervisor]

    Application.get_env(:ae_socket_connector, :node)[:deps_path]
    |> Path.join("*/ebin")
    |> Path.wildcard()
    |> Enum.each(fn path -> Code.append_path(path) end)

    Supervisor.start_link(children, opts)
  end
end
