defmodule SessionHolder do
  use GenServer
  require Logger

  @sync_call_timeout 10_000

  defstruct socket_connector_pid: nil,
            color: nil,
            network_id: nil,
            priv_key: nil,
            file: nil,
            socket_connector_state: nil,
            connection_callbacks: nil

  def start_link(%{
        socket_connector: socket_connector_state,
        log_config: log_config,
        ae_url: ae_url,
        network_id: network_id,
        priv_key: priv_key,
        connection_callbacks: connection_callbacks,
        color: color,
        # pid name, of the session holder, which is maintined over re-connect/re-establish
        pid_name: name
      }) do
    log_path = Map.get(log_config, :log_path, "log")
    create_log_folder(log_path)
    file_name_and_path = log_path <> "/" <> (Map.get(log_config, :log_file, generate_filename(name)))
    case !File.exists?(file_name_and_path) do
      true ->
        GenServer.start_link(__MODULE__, {socket_connector_state, ae_url, network_id, priv_key, connection_callbacks, file_name_and_path, :open, color}, name: name)
      false ->
        GenServer.start_link(__MODULE__, {socket_connector_state, ae_url, network_id, priv_key, connection_callbacks, file_name_and_path, :reestablish, color}, name: name)
    end
  end

  defp create_log_folder(path) do
    case File.mkdir(path) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, error} -> throw "not possible to create log directory #{inspect error}"
    end
  end

  defp generate_filename(name) do
    (DateTime.utc_now |> DateTime.to_string()) <> "_channel_service_" <> String.replace(to_string(name), " ", "_") <> ".log"
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

  def solo_close_transaction(pid, round, nonce, ttl) do
    GenServer.call(pid, {:solo_close_transaction, round, nonce, ttl})
  end

  def verify_poi(pid, to_sign, poi) do
    GenServer.call(pid, {:verify_poi, to_sign, poi})
  end

  # Server
  def init({socket_connector_state, ae_url, network_id, priv_key, connection_callbacks, file_name, :open, color}) do
    :dets.open_file(String.to_atom(file_name), [type: :duplicate_bag])
    {:ok, pid} = SocketConnector.start_link(socket_connector_state, ae_url, network_id, connection_callbacks, color, self())

    {:ok,
     %__MODULE__{
       socket_connector_pid: pid,
       socket_connector_state: socket_connector_state,
       network_id: network_id,
       priv_key: priv_key,
       connection_callbacks: connection_callbacks,
       color: color,
       file: file_name
     }}
  end

  def init({socket_connector_state, _ae_url, network_id, priv_key, connection_callbacks, file_name, :reestablish, color}) do
    :dets.open_file(String.to_atom(file_name), [type: :duplicate_bag])
    state =
      %__MODULE__{
        # socket_connector_pid: pid,
        socket_connector_state: socket_connector_state,
        network_id: network_id,
        priv_key: priv_key,
        connection_callbacks: connection_callbacks,
        color: color,
        file: file_name
        }
    {pid, saved_socket_connector_state} = reestablish_(state)
    {:ok, %__MODULE__{state | socket_connector_state: Map.merge(saved_socket_connector_state, socket_connector_state), socket_connector_pid: pid, connection_callbacks: connection_callbacks}}
  end

  defp kill_connection(pid, color) do
    Logger.debug("killing connector #{inspect(pid)}", ansi_color: color)
    Process.exit(pid, :normal)
  end

  # this is persent as a helper if you loose your channel id or password, then check this file.
  defp persist(state, file) do
    dets_state = %{time: (DateTime.utc_now |> DateTime.to_string()), state: state}
    case :dets.insert(String.to_atom(file), {:connect, dets_state}) do
      :ok ->
        case (state.channel_id == nil or state.fsm_id == nil) do
          true ->
            Logger.warn("Persisted data not satisfing reestablish requirements, fsm_id: #{inspect state.fsm_id} channel_id #{inspect state.channel_id}")
          false ->
            :ok
        end
        :ok
      error -> throw "logging failed to presist, without persistence reestablish can fail #{inspect error}"
    end
  end

  def fetch_state_and_persist(pid, file) do
    SocketConnector.request_state(pid)
    receive do
      {:"$gen_cast", {:state_tx_update, socket_connector_state}} ->
        persist(socket_connector_state, file)
        socket_connector_state
    end
  end

  def reestablish_(state, port \\ 1500) do
    Logger.debug("about to re-establish connection", ansi_color: state.color)

    # we used stored data as opposed to in mem data. This is to verify that reestablish is operation from a cold start.
    socket_connector_state =
      case :dets.lookup(String.to_atom(state.file), :connect) do
        [] ->
          throw "no saved state in dets"
        dets_state ->
          {:connect, saved_state} = List.last(dets_state)
          Logger.debug("re-establish located persisted state #{inspect saved_state.time} storage #{inspect state.file} contains #{inspect Enum.count(dets_state)} entries", ansi_color: state.color)
          saved_state.state
      end

    # ^state = :dets.lookup(state.file, :connect)
    merged_socket_connector_state = Map.merge(state.socket_connector_state, socket_connector_state)

    {:ok, pid} =
      SocketConnector.start_link(
        :reestablish,
        merged_socket_connector_state,
        port,
        state.connection_callbacks,
        state.color,
        self()
      )
    {pid, merged_socket_connector_state}
  end

  def handle_cast({:state_tx_update, socket_connector_state}, state) do
    persist(socket_connector_state, state.file)
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:kill_connection}, state) do
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file)
    kill_connection(state.socket_connector_pid, state.color)
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:close_connection}, state) do
    Logger.debug("closing connector #{inspect(state.socket_connector_pid)}", ansi_color: state.color)
    SocketConnector.close_connection(state.socket_connector_pid)

    socket_connector_state =
      receive do
        {:"$gen_cast", {:state_tx_update, socket_connector_state}} ->
          persist(socket_connector_state, state.file)
          socket_connector_state
      end

    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:reestablish, port}, state) do
    {pid, socket_connector_state} = reestablish_(state, port)
    {:noreply, %__MODULE__{state | socket_connector_pid: pid, socket_connector_state: socket_connector_state}}
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
      Signer.sign_transaction(to_sign, state.network_id, state.priv_key)

    {:reply, sign_result, state}
  end

  def handle_call({:verify_poi, to_sign, poi}, _from, state) do
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file)

    {_round, %SocketConnector.Update{state_tx: state_tx}} = Enum.max(socket_connector_state.round_and_updates)

    %SocketConnector.WsConnection{initiator_id: initiator_id, responder_id: responder_id} =
      socket_connector_state.session.basic_configuration

    valid = Validator.match_poi_aetx({poi, [initiator_id, responder_id], []}, to_sign, state_tx)
    {:reply, valid, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_call(
        {:solo_close_transaction, round, nonce, ttl},
        _from,
        state
      ) do
    # We need the latest SocketConnector state.
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file)

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
