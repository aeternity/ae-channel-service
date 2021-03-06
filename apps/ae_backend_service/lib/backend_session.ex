defmodule BackendSession do
  use GenServer
  require Logger

  def keypair_responder(), do: Application.get_env(:ae_socket_connector, :accounts)[:responder]

  def blocks_reaction_time() do
    {blocks_reaction_time, ""} =
      Integer.parse(Application.get_env(:ae_backend_service, :game)[:force_progress_height])

    blocks_reaction_time
  end

  def mine_rate() do
    {mine_rate, ""} = Integer.parse(Application.get_env(:ae_backend_service, :game)[:mine_rate])
    mine_rate
  end

  # @states [:sign_provide_hash, :perform_casino_pick, :sign_casino_pick, :sign_reveal]

  defstruct pid_session_holder: nil,
            pid_backend_manager: nil,
            identifier: nil,
            params: nil,
            port: nil,
            channel_params: nil,
            game: %{},
            responder_contract: nil,
            fp_timer: nil,
            expected_state: nil

  # Client

  def start_link({params, {_pid_manager, _identifier} = manager_data}) do
    GenServer.start_link(__MODULE__, {params, manager_data})
  end

  defp log_callback({type, message}) do
    Logger.info(
      "backend session: #{inspect({type, message})} pid is: #{inspect(self())}",
      ansi_color: Map.get(message, :color, nil)
    )
  end

  # Server
  def init({params, {pid_manager, identifier}}) do
    Logger.info("Starting backend session #{inspect({params, identifier})} pid is #{inspect(self())}")

    GenServer.cast(self(), {:resume_init, params})
    {:ok, %__MODULE__{pid_backend_manager: pid_manager, identifier: identifier, params: params}}
  end

  def handle_cast({:resume_init, {role, channel_config, _reestablish, initiator_keypair}}, state) do
    {_channel_id, port} =
      reestablish = BackendServiceManager.get_channel_id(state.pid_backend_manager, state.identifier)

    {:ok, pid} =
      SessionHolderHelper.start_session_holder(
        role,
        channel_config,
        reestablish,
        initiator_keypair,
        fn -> keypair_responder() end,
        SessionHolderHelper.connection_callback(self(), :blue, &log_callback/1)
      )

    responder_contract =
      {TestAccounts.responderPubkeyEncoded(), "contracts/coin_toss.aes",
       %{abi_version: 3, vm_version: 5, backend: :fate}}

    {initiator_id, _initiator_priv_key} = initiator_keypair.()
    {responder_id, _repsonder_priv_key} = keypair_responder()

    channel_params = channel_config.(initiator_id, responder_id).custom_param_fun.(:responder, "irrelevant")

    {:noreply,
     %__MODULE__{
       state
       | pid_session_holder: pid,
         port: port,
         channel_params: channel_params,
         responder_contract: responder_contract
     }}
  end

  def handle_cast({:connection_update, {:disconnected, "Invalid fsm id"} = update}, state) do
    Logger.warn("Backend disconnected, not attempting reestablish #{inspect(update)}")
    BackendServiceManager.remove_channel_id(state.pid_backend_manager, state.identifier)
    {:stop, :update, state}
  end

  # this message arrives if channel times out.
  # {:channels_update, %{color: :blue, method: "channels.conflict", round: 2, round_initiator: :self}}
  # [:other, :transient]

  # this will only happen once!
  def handle_cast({:channels_update, 1, round_initiator, "channels.update"} = _message, state)
      when round_initiator in [:other] do
    {responder_pub, _priv} = keypair_responder()
    {_role, _channel_config, _reestablish, initiator_keypair} = state.params
    {initiator_pub, _priv} = initiator_keypair.()

    fun =
      &SocketConnector.new_contract(
        &1,
        state.responder_contract,
        [
          to_charlist(initiator_pub),
          to_charlist(responder_pub),
          # reaction time
          to_charlist(Application.get_env(:ae_backend_service, :game)[:force_progress_height])
        ]
      )

    SessionHolder.run_action(state.pid_session_holder, fun)
    {:noreply, %__MODULE__{state | expected_state: :sign_provide_hash}}
  end

  # this is :sign_provide_hash
  def handle_cast(
        {{:sign_approve, _round, _round_initiator, method,
          [%{decoded_calldata: {"provide_hash", _params}}, %{"amount" => amount}], %{"type" => _type} = _human,
          _channel_id}, to_sign} = _message,
        %__MODULE__{fp_timer: fp_timer} = state
      ) do
    # check whether there is coverage enough in the channel, if not abort.
    fun = &SocketConnector.query_funds(&1, &2)
    funds = SessionHolder.run_action_sync(state.pid_session_holder, fun)

    {channel_reserve, ""} = Integer.parse(state.channel_params[:channel_reserve])
    fund_check = for %{"balance" => balance} = entry <- funds, balance - channel_reserve >= amount, do: entry

    case Enum.count(fund_check) == 2 do
      true ->
        signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
        fun = &SocketConnector.send_signed_message(&1, method, signed)
        SessionHolder.run_action(state.pid_session_holder, fun)

        {:noreply,
         %__MODULE__{
           state
           | game: %{amount: amount},
             expected_state: :perform_casino_pick,
             fp_timer: postpone_timer(fp_timer)
         }}

      false ->
        # not enough funds to play, TODO, message is not provided to other end?
        fun = &SocketConnector.abort(&1, method, 555, "not enough funds")
        SessionHolder.run_action(state.pid_session_holder, fun)

        {:noreply,
         %__MODULE__{
           state
           | game: %{amount: amount},
             expected_state: :sign_provide_hash,
             fp_timer: postpone_timer(fp_timer)
         }}
    end
  end

  @coin_sides ["heads", "tails"]
  # this is :perform_casino_pick
  def handle_cast(
        {:channels_update, _round, round_initiator, "channels.update"} = _message,
        %__MODULE__{expected_state: :perform_casino_pick, fp_timer: fp_timer} = state
      )
      when round_initiator in [:other] do
    coin_side =
      case Application.get_env(:ae_backend_service, :game)[:toss_mode] do
        manual when manual in @coin_sides ->
          Logger.info("Picking side manually: #{inspect(manual)}")
          manual

        _ ->
          Logger.info("Picking side randomly")
          Enum.random(@coin_sides)
      end

    pick = ContractHelper.add_quotes(coin_side)

    fun1 =
      &SocketConnector.call_contract(
        &1,
        state.responder_contract,
        'casino_pick',
        [to_charlist(pick)],
        # this is what we put at stake.
        state.game.amount
      )

    case Application.get_env(:ae_backend_service, :game)[:game_mode] do
      "malicious" ->
        # give the client a chance to show of force progress
        {:noreply, state}

      _ ->
        SessionHolder.run_action(state.pid_session_holder, fun1)

        {:noreply,
         %__MODULE__{
           state
           | expected_state: :sign_casino_pick,
             fp_timer: postpone_timer(fp_timer)
         }}
    end
  end

  # :sign_casino_pick (self) also ChannelCreateTx
  def handle_cast(
        {{:sign_approve, _round, round_initiator, method, _updates, %{"type" => type} = human, _channel_id},
         to_sign} = _message,
        state
      )
      # when type in ["ChannelOffchainTx", "ChannelCreateTx", "ChannelCloseMutualTx"] or
      when type in ["ChannelCreateTx"] or
             round_initiator == :self do
    Logger.info("Backened sign request #{inspect({method, human})}")
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)
    {:noreply, %__MODULE__{state | expected_state: :sign_reveal}}
  end

  # this is :sign_reveal
  # fp timer should be then stopped, as the winner is then known
  def handle_cast(
        {{:sign_approve, _round, _round_initiator, method,
          [%{decoded_calldata: {"reveal", _params}}, %{"amount" => amount}], %{"type" => _type} = _human,
          _channel_id}, to_sign} = _message,
        %{fp_timer: fp_timer} = state
      ) do
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)
    Process.cancel_timer(fp_timer)
    {:noreply, %__MODULE__{state | game: %{amount: amount}, fp_timer: nil, expected_state: :sign_provide_hash}}
  end

  # :ChannelCloseMutualTx
  def handle_cast(
        {{:sign_approve, _round, round_initiator, method, _updates, %{"type" => type} = _human, _channel_id},
         to_sign} = _message,
        %__MODULE__{expected_state: expected_state} = state
      )
      when type in ["ChannelCloseMutualTx"] or
             round_initiator == :self do
    case expected_state do
      :sign_provide_hash ->
        signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
        fun = &SocketConnector.send_signed_message(&1, method, signed)
        SessionHolder.run_action(state.pid_session_holder, fun)

      _ ->
        Logger.error("Other end missusing protocol")
        # don't do anything a timer is set, once it fires it will try and force progress.
    end

    {:noreply, %__MODULE__{state | expected_state: :sign_reveal}}
  end

  def handle_cast(
        {{:sign_approve, _round, _round_initiator, _method, _updates, human, _channel_id}, _to_sign} = message,
        state
      ) do
    Logger.error("Backened sign request something FISHY ongoing #{inspect({message, human})}")
    {:noreply, state}
  end

  def handle_cast({:on_chain, "can_slash"}, state) do
    fun = &SocketConnector.slash(&1)
    SessionHolder.run_action(state.pid_session_holder, fun)
  end

  def handle_cast({:on_chain, "solo_closing"}, state) do
    fun = &SocketConnector.settle(&1)
    SessionHolder.run_action(state.pid_session_holder, fun)
  end

  def handle_cast({:on_chain, "consumed_forced_progress"} = msg, state) do
    Logger.warn("Force progress transaction succeeded, contract state is now reset #{inspect(msg)}")
    {:noreply, state}
  end

  # {:channels_info, "died", "ch_pcLtoFWASVUzSqQkWJ8rbZnA34TxetnAGqw2mv4RVuywAhtT9"}

  def handle_cast({:channels_info, "died", channel_id}, state) do
    # BackendServiceManager.set_channel_id(state.pid_backend_manager, state.identifier, {channel_id, state.port})
    Logger.error("Connection is down, #{inspect(channel_id)}")
    {:noreply, state}
  end

  # once this occured we should be able to reconnect.
  # if we don't update the channel id somewhere here,
  # channel_id will be known as nil by BackendServiceManager
  def handle_cast({:channels_info, method, channel_id}, state)
      when method in ["funding_signed", "funding_created"] do
    BackendServiceManager.set_channel_id(
      state.pid_backend_manager,
      state.identifier,
      {channel_id, state.port}
    )

    {:noreply, state}
  end

  # This can end up in an never successfull connection (endless loop), beware, TODO exponential backoff?
  # TODO this is also valid disconnect reasons that should terminate this process in a normal fashion (preventing supervision restarts)
  def handle_cast({:connection_update, {:disconnected, _reason} = update}, state) do
    Logger.warn("Backend disconnected, attempting reestablish #{inspect(update)}")
    Process.send_after(self(), :resume_init, 5000)
    {:noreply, state}
  end

  def handle_cast({:connection_update, {_status, _reason} = _update}, state) do
    {:noreply, state}
  end

  def handle_cast(message, state) do
    Logger.warn("unprocessed message received in backend #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info(:resume_init, state) do
    GenServer.cast(self(), {:resume_init, state.params})
    {:noreply, state}
  end

  # TODO there also should be invalid force_progress handling, but for now, no signs of invalid fp found so far...
  def handle_info(:force_progress, %__MODULE__{fp_timer: fp_timer} = state) do
    fp_call_function = 'casino_dispute_no_reveal'
    dry_run = &SocketConnector.call_contract_dry(&1, state.responder_contract, fp_call_function, [], &2)

    Logger.warn(
      "Force progress time! Checking for force progress availability... Client waited too long, or didnt follow the happy flow - dry-running dispute function..."
    )

    case SessionHolder.run_action_sync(state.pid_session_holder, dry_run) do
      # retry, as the call failed, timer should be reset again
      {:error, _} ->
        Logger.error(
          "Dry run call of #{inspect(fp_call_function)} failed... Retrying force-progressing in #{
            inspect(blocks_reaction_time() * mine_rate())
          } ms"
        )

        {:noreply, %{state | fp_timer: postpone_timer(fp_timer)}}

      # call is available and valid, gladly doing force progress
      {:ok, _} ->
        Logger.warn("Dry run call succeed, force progressing is available, backend force progress initiated...")
        fun = &SocketConnector.force_progress(&1, state.responder_contract, fp_call_function, [])
        SessionHolder.run_action(state.pid_session_holder, fun)
        {:noreply, state}
    end
  end

  def postpone_timer(timer) when is_nil(timer) do
    Process.send_after(self(), :force_progress, blocks_reaction_time() * mine_rate())
  end

  def postpone_timer(timer) do
    Process.cancel_timer(timer)
    Process.send_after(self(), :force_progress, blocks_reaction_time() * mine_rate())
  end
end
