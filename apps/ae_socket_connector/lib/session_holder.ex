defmodule SessionHolder do
  use GenServer
  require Logger

  @sync_call_timeout 10_000

  defstruct pid: nil,
            color: nil,
            configuration: %SocketConnector{},
            ae_url: ""

  def start_link(%SocketConnector{} = configuration, ae_url, network_id, color) do
    GenServer.start_link(__MODULE__, {configuration, ae_url, network_id, color})
  end

  def reestablish(pid) do
    GenServer.cast(pid, {:reestablish})
  end

  def run_action(pid, action) do
    GenServer.cast(pid, {:action, action})
  end

  def run_action_sync(pid, action) do
    GenServer.call(pid, {:action_sync, action}, @sync_call_timeout)
  end

  # Server
  def init({%SocketConnector{} = configuration, ae_url, network_id, color}) do
    {:ok, pid} =
      SocketConnector.start_link(:alice, configuration, ae_url, network_id, color, self())

    {:ok, %__MODULE__{pid: pid, configuration: configuration, color: color}}
  end

  def handle_cast({:connection_dropped, configuration}, state) do
    Logger.debug "Connection_dropped"
    {:noreply, %__MODULE__{state | configuration: configuration}}
  end

  def handle_cast({:reestablish}, state) do
    Logger.debug("about to reestablish connection", ansi_color: state.color)

    {:ok, pid} =
      SocketConnector.start_link(:alice, state.configuration, :reestablish, state.color, self())

    {:noreply, %__MODULE__{state | pid: pid}}
  end

  def handle_cast({:action, action}, state) do
    action.(state.pid)
    {:noreply, state}
  end

  def handle_call({:action_sync, action}, from, state) do
    action.(state.pid, from)
    {:noreply, state}
  end
end
