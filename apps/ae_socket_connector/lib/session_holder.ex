defmodule SessionHolder do
  use GenServer
  require Logger

  @sync_call_timeout 10_000

  defstruct socket_connector_pid: nil,
            color: nil,
            network_id: nil,
            priv_key: nil,
            socket_connector_state: %SocketConnector{}

  def start_link(%{
        socket_connector: %SocketConnector{} = socket_connector_state,
        ae_url: ae_url,
        network_id: network_id,
        priv_key: priv_key,
        color: color,
        # pid name, of the session holder, which is maintined over re-connect/re-establish
        pid_name: name
      }) do
    GenServer.start_link(__MODULE__, {socket_connector_state, ae_url, network_id, priv_key, color}, name: name)
  end

  # this is here for tesing purposes
  def kill_connection(pid) do
    GenServer.cast(pid, {:kill_connection})
  end

  def close_connection(pid) do
    GenServer.cast(pid, {:close_connection})
  end

  def reestablish(pid, port \\ 1501) do
    GenServer.cast(pid, {:reestablish, port})
  end

  def reconnect(pid, port \\ 1502) do
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

  def sign_message(pid, to_sign) do
    GenServer.call(pid, {:sign_request, to_sign}, @sync_call_timeout)
  end

  # Server
  def init({%SocketConnector{} = socket_connector_state, ae_url, network_id, priv_key, color}) do
    {:ok, pid} = SocketConnector.start_link(socket_connector_state, ae_url, network_id, color, self())

    {:ok,
     %__MODULE__{
       socket_connector_pid: pid,
       socket_connector_state: socket_connector_state,
       network_id: network_id,
       priv_key: priv_key,
       color: color
     }}
  end

  defp kill_connection(pid, color) do
    Logger.debug("killing connector #{inspect(pid)}", ansi_color: color)
    Process.exit(pid, :normal)
  end

  def fetch_state(pid) do
    SocketConnector.request_state(pid)

    receive do
      {:"$gen_cast", {:state_tx_update, %SocketConnector{} = state}} -> state
    end
  end

  def handle_cast({:state_tx_update, %SocketConnector{} = socket_connector_state}, state) do
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:kill_connection}, state) do
    socket_connector_state = fetch_state(state.socket_connector_pid)
    kill_connection(state.socket_connector_pid, state.color)
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:close_connection}, state) do
    Logger.debug("closing connector #{inspect(state.socket_connector_pid)}", ansi_color: state.color)
    SocketConnector.close_connection(state.socket_connector_pid)

    socket_connector_state =
      receive do
        {:"$gen_cast", {:state_tx_update, %SocketConnector{} = state}} -> state
      end

    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:reconnect, port}, state) do
    Logger.debug("about to re-connect connection", ansi_color: state.color)

    socket_connector_state = state.socket_connector_state

    pending_round_and_update = socket_connector_state.pending_round_and_update
    round_and_updates = socket_connector_state.round_and_updates

    {round, %SocketConnector.Update{}} =
      case {!Enum.empty?(pending_round_and_update), !Enum.empty?(round_and_updates)} do
        {true, _} -> Enum.max(pending_round_and_update)
        {false, true} -> Enum.max(round_and_updates)
        {false, false} -> throw("cannot reconnect no saved state avaliable")
      end

    reconnect_tx =
      SocketConnector.create_reconnect_tx(
        socket_connector_state.channel_id,
        round,
        socket_connector_state.role,
        socket_connector_state.pub_key
      )

    signed_reconnect_tx = Signer.sign_aetx(reconnect_tx, state.network_id, state.priv_key)

    {:ok, pid} =
      SocketConnector.start_link(
        :reconnect,
        signed_reconnect_tx,
        state.socket_connector_state,
        port,
        state.color,
        self()
      )

    {:noreply, %__MODULE__{state | socket_connector_pid: pid}}
  end

  def handle_cast({:reestablish, port}, state) do
    Logger.debug("about to re-establish connection", ansi_color: state.color)

    {:ok, pid} =
      SocketConnector.start_link(
        :reestablish,
        state.socket_connector_state,
        port,
        state.color,
        self()
      )

    {:noreply, %__MODULE__{state | socket_connector_pid: pid}}
  end

  def handle_cast({:action, action}, state) do
    action.(state.socket_connector_pid)
    {:noreply, state}
  end

  def handle_call({:action_sync, action}, from, state) do
    action.(state.socket_connector_pid, from)
    {:noreply, state}
  end

  # used for general signing, sometimes for backchannel purposes
  def handle_call({:sign_request, to_sign}, _from, state) do
    sign_result =
      Signer.sign_transaction(to_sign, state.network_id, state.priv_key, fn _tx, _round_initiator, _state ->
        :ok
      end)

    {:reply, sign_result, state}
  end

  def handle_call(
        {:solo_close_transaction, round, nonce, ttl},
        _from,
        state
      ) do
    # We need the latest SocketConnector state.
    socket_connector_state = fetch_state(state.socket_connector_pid)

    %SocketConnector.Update{state_tx: state_tx, poi: poi} =
      Map.get(socket_connector_state.round_and_updates, round)

    case poi do
      nil ->
        Logger.error("You should have fetched poi at round #{inspect(round)}")

        contains_poi =
          Enum.reduce(socket_connector_state.round_and_updates, %{}, fn {round, %SocketConnector.Update{poi: poi}},
                                                                        acc ->
            case poi do
              nil -> acc
              _ -> Map.put(acc, round, poi)
            end
          end)

        Logger.error("Rounds with poi #{inspect(contains_poi)}")

      _ ->
        :poi_present_for_round
    end

    transaction =
      SocketConnector.create_solo_close_tx(
        socket_connector_state.pub_key,
        socket_connector_state.channel_id,
        state_tx,
        poi,
        nonce,
        ttl
      )

    {:reply, Signer.sign_aetx(transaction, state.network_id, state.priv_key),
     %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  # @spec suffix_name(name) :: name when name: atom()
  # def suffix_name(name) do
  #   String.to_atom(to_string(name) <> "_holder")
  # end
end
