defmodule SessionHolder do
  use GenServer
  require Logger

  @sync_call_timeout 10_000

  defstruct socket_connector_pid: nil,
            color: nil,
            network_id: nil,
            priv_key: nil,
            file_ref: nil,
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
      } = connect_map) do
    path = Map.get(log_config, :path, "data")
    create_folder(path)
    file_name_and_path = Path.join(path, (Map.get(log_config, :file, generate_filename(name))))
    Logger.info "File_name is #{inspect file_name_and_path}"
    case Map.get(connect_map, :channel_id, nil) do
      nil ->
        # new fresh connection
        GenServer.start_link(__MODULE__, {socket_connector_state, ae_url, network_id, priv_key, connection_callbacks, file_name_and_path, :open, color}, name: name)
      channel_id ->
        GenServer.start_link(__MODULE__, {socket_connector_state, ae_url, network_id, channel_id, priv_key, connection_callbacks, file_name_and_path, :reestablish, color}, name: name)

    end
  end

  defp create_folder(path) do
    case File.mkdir(path) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, error} -> throw "not possible to create log directory #{inspect error}"
    end
  end

  defp generate_filename(name) do
    (DateTime.utc_now |> DateTime.to_string()) <> "_channel_service_" <> String.replace(inspect(name), " ", "_") <> ".log"
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

  def leave(pid) do
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
    Logger.error("Starting session holder, #{inspect self()}")
    {:ok, ref} = :dets.open_file(String.to_atom(file_name), [type: :duplicate_bag])
    {:ok, pid} = SocketConnector.start_link(socket_connector_state, ae_url, network_id, connection_callbacks, color, self())

    {:ok,
     %__MODULE__{
       socket_connector_pid: pid,
       socket_connector_state: socket_connector_state,
       network_id: network_id,
       priv_key: priv_key,
       connection_callbacks: connection_callbacks,
       color: color,
      #  file: file_name,
       file_ref: ref
     }}
  end

  def init({socket_connector_state, _ae_url, network_id, channel_id, priv_key, connection_callbacks, file_name, :reestablish, color}) do
    Logger.error("Starting session holder in reestablish mode, #{inspect self()}")
    {:ok, ref} = :dets.open_file(String.to_atom(file_name), [type: :duplicate_bag])
    state =
      %__MODULE__{
        # socket_connector_pid: pid,
        socket_connector_state: socket_connector_state,
        network_id: network_id,
        priv_key: priv_key,
        connection_callbacks: connection_callbacks,
        color: color,
        # file: file_name,
        file_ref: ref
        }
    {pid, saved_socket_connector_state} = reestablish_(state, channel_id)
    {:ok, %__MODULE__{state | socket_connector_state: Map.merge(saved_socket_connector_state, socket_connector_state), socket_connector_pid: pid, connection_callbacks: connection_callbacks}}
  end

  defp kill_connection(pid, color) do
    Logger.debug("killing connector #{inspect(pid)}", ansi_color: color)
    Process.exit(pid, :normal)
  end

  # this is persent as a helper if you loose your channel id or password, then check this file.
  defp persist(socketconnector_state, file_ref) do
    dets_state = %{time: (DateTime.utc_now |> DateTime.to_string()), state: socketconnector_state}

    case socketconnector_state.channel_id do
      nil -> Logger.warn("Not persisting to disk, channel_id missing")
      _ ->
        case :dets.insert(file_ref, {socketconnector_state.channel_id, dets_state}) do
          :ok ->
            case :dets.sync(file_ref) do
              :ok -> :ok
                case socketconnector_state.fsm_id == nil do
                  true ->
                    Logger.warn("Persisted data not satisfing reestablish requirements, fsm_id: #{inspect socketconnector_state.fsm_id} channel_id #{inspect socketconnector_state.channel_id}")
                  false ->
                    Logger.info("Persisted data SATISFING reestablish requirements, fsm_id: #{inspect socketconnector_state.fsm_id} channel_id #{inspect socketconnector_state.channel_id}")
                end

              {:error, reason} -> Logger.error("Failed to persist state to disk, fsm_id: #{inspect dets_state.fsm_id} channel_id #{inspect dets_state.channel_id} reason #{inspect reason}")
            end
        end
    end
  end

  def fetch_state_and_persist(pid, file_ref) do
    SocketConnector.request_state(pid)
    receive do
      {:"$gen_cast", {:state_tx_update, socket_connector_state}} ->
        persist(socket_connector_state, file_ref)
        socket_connector_state
    end
  end

  defp get_most_recent(list, channel_id, key) do
    Logger.warn("Missing key #{inspect key}, fetching from old entry... #{inspect list}")
    case Enum.find(Enum.reverse(list), fn({_, entry}) -> Map.get(entry.state, key) != nil end) do
      nil ->
        Logger.error "Error could not find value for #{inspect key}"
        nil
      {^channel_id, dets_entry} ->
        case Map.get(dets_entry.state, key) do
          nil ->
            Logger.error "Cound find value for #{inspect key}"
            nil
          result ->
            Logger.error "Found value for #{inspect {key, result}}"
            result
        end
    end
  end

  def reestablish_(state, channel_id, port \\ 1500) do
    Logger.error("about to re-establish connection", ansi_color: state.color)

    # we used stored data as opposed to in mem data. This is to verify that reestablish is operation from a cold start.
    socket_connector_state =
      case :dets.lookup(state.file_ref, channel_id) do
        [] ->
          Logger.error "no saved state in dets, #{inspect state.file_ref}"
          throw "no saved state in dets"
        dets_state ->
          {^channel_id, saved_state} = List.last(dets_state)
          Logger.debug("re-establish located persisted state #{inspect saved_state.time} storage #{inspect state.file_ref} contains #{inspect Enum.count(dets_state)} entries", ansi_color: state.color)
          case {Map.get(saved_state, :channel_id, nil), Map.get(saved_state, :fsm_id, nil)} do
            {nil, nil} ->
              %{saved_state.state | channel_id: get_most_recent(dets_state, channel_id, :channel_id), fsm_id: get_most_recent(dets_state, channel_id, :fsm_id)}
            {nil, _} ->
              %{saved_state.state | channel_id: get_most_recent(dets_state, channel_id, :channel_id)}
            {_, nil} ->
              %{saved_state.state | fsm_id: get_most_recent(dets_state, channel_id, :fsm_id)}
            _ ->
              saved_state.state
          end
      end

    # ^state = :dets.lookup(state.file_ref, :connect)
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
    persist(socket_connector_state, state.file_ref)
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:kill_connection}, state) do
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file_ref)
    kill_connection(state.socket_connector_pid, state.color)
    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:close_connection}, state) do
    Logger.debug("closing connector #{inspect(state.socket_connector_pid)}", ansi_color: state.color)
    SocketConnector.close_connection(state.socket_connector_pid)

    socket_connector_state =
      receive do
        {:"$gen_cast", {:state_tx_update, socket_connector_state}} ->
          persist(socket_connector_state, state.file_ref)
          socket_connector_state
      end

    {:noreply, %__MODULE__{state | socket_connector_state: socket_connector_state}}
  end

  def handle_cast({:reestablish, port}, state) do
    {pid, socket_connector_state} = reestablish_(state, state.socket_connector_state.channel_id, port)
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
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file_ref)

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
    socket_connector_state = fetch_state_and_persist(state.socket_connector_pid, state.file_ref)

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
