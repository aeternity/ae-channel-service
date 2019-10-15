defmodule SessionHolder do
  use GenServer
  require Logger

  @sync_call_timeout 10_000

  defstruct pid: nil,
            color: nil,
            configuration: %SocketConnector{}

  def start_link(%{
        socket_connector: %SocketConnector{} = configuration,
        ae_url: ae_url,
        network_id: network_id,
        color: color,
        # pid name, of the session holder, which is maintined over re-connect/re-establish
        pid_name: name
      }) do
    GenServer.start_link(__MODULE__, {configuration, ae_url, network_id, color}, name: name)
  end

  # this is here for tesing purposes
  def kill_connection(pid) do
    GenServer.cast(pid, {:kill_connection})
  end

  def close_connection(pid) do
    GenServer.cast(pid, {:close_connection})
  end

  def reestablish(pid, port \\ 12342) do
    GenServer.cast(pid, {:reestablish, port})
  end

  def reconnect(pid, port \\ 12345) do
    GenServer.cast(pid, {:reconnect, port})
  end

  def stop_helper(pid) do
    run_action(pid, fn pid -> SocketConnector.leave(pid) end)
  end

  def run_action(pid, action) do
    GenServer.cast(pid, {:action, action})
  end

  def run_action_sync(pid, action) do
    GenServer.call(pid, {:action_sync, action}, @sync_call_timeout)
  end

  def backchannel_sign_request(pid, to_sign) do
    GenServer.call(pid, {:sign_request, to_sign}, @sync_call_timeout)
  end

  # Server
  def init({%SocketConnector{} = configuration, ae_url, network_id, color}) do
    {:ok, pid} = SocketConnector.start_link(configuration, ae_url, network_id, color, self())

    {:ok, %__MODULE__{pid: pid, configuration: configuration, color: color}}
  end

  def handle_cast({:state_tx_update, %SocketConnector{} = configuration}, state) do
    {:noreply, %__MODULE__{state | configuration: configuration}}
  end

  defp kill_connection(pid, color) do
    Logger.debug("killing connector #{inspect(pid)}", ansi_color: color)
    Process.exit(pid, :normal)
  end

  def handle_cast({:kill_connection}, state) do
    kill_connection(state.pid, state.color)
    {:noreply, state}
  end

  def handle_cast({:close_connection}, state) do
    Logger.debug("closing connector #{inspect(state.pid)}", ansi_color: state.color)
    SocketConnector.close_connection(state.pid)
    {:noreply, state}
  end

  def handle_cast({:reconnect, port}, state) do
    Logger.debug("about to re-connect connection", ansi_color: state.color)

    {:ok, pid} = SocketConnector.start_link(:reconnect, state.configuration, port, state.color, self())

    {:noreply, %__MODULE__{state | pid: pid}}
  end

  def handle_cast({:reestablish, port}, state) do
    Logger.debug("about to re-establish connection", ansi_color: state.color)

    {:ok, pid} =
      SocketConnector.start_link(
        :reestablish,
        state.configuration,
        port,
        state.color,
        self()
      )

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

  # TODO this allows backchannel signing, either way. Should we should uppdate round in the state?
  def handle_call({:sign_request, to_sign}, _from, state) do
    sign_result =
      Signer.sign_transaction(to_sign, state.configuration, fn _tx, _round_initiator, _state ->
        :ok
      end)

    {:reply, sign_result, state}
  end

  # @spec suffix_name(name) :: name when name: atom()
  # def suffix_name(name) do
  #   String.to_atom(to_string(name) <> "_holder")
  # end
end
