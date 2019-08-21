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

  def kill_connection(pid) do
    GenServer.cast(pid, {:kill_connection})
  end

  def reestablish(pid) do
    GenServer.cast(pid, {:reestablish})
  end

  def reconnect(pid) do
    GenServer.cast(pid, {:reconnect})
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

  def handle_cast({:state_tx_update, %SocketConnector{} = configuration}, state) do
    {:noreply, %__MODULE__{state | configuration: configuration}}
  end

  def handle_cast({:kill_connection}, state) do
    Logger.debug("Killing connector #{inspect(state.pid)}")
    Process.exit(state.pid, :normal)
    {:noreply, state}
  end

  def handle_cast({:reconnect}, state) do
    Logger.debug("about to re-connect connection", ansi_color: state.color)

    {:ok, pid} =
      SocketConnector.start_link(:alice, state.configuration, :reconnect, state.color, self())

    {:noreply, %__MODULE__{state | pid: pid}}
  end

  def handle_cast({:reestablish}, state) do
    Logger.debug("about to re-establish connection", ansi_color: state.color)

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
