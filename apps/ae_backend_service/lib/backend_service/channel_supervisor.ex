defmodule ChannelSupervisor do
  use Supervisor
  require Logger

  def start_link(arg) do
    name = ChannelSupervisor.Supervisor
    Supervisor.start_link(__MODULE__, arg, name: name)
  end

  def init(_arg) do
    supervise([worker(BackendSession, [], restart: :transient)], strategy: :simple_one_for_one)
  end
end
