defmodule BackendSession do
  @moduledoc """
  BackendSession keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer
  require Logger

  def keypair_responder(), do: Application.get_env(:ae_socket_connector, :accounts)[:responder]

  # @states [:sign_provide_hash, :perform_casino_pick, :sign_casino_pick, :sign_reveal]

  defstruct pid_session_holder: nil,
            pid_backend_manager: nil,
            identifier: nil,
            params: nil,
            port: nil,
            channel_params: nil,
            game: %{},
            responder_contract: nil,
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

  # def handle_cast(
  #       {:channels_update, _round, round_initiator, "channels.update"} = _message,
  #       %__MODULE__{expected_state: expected_state} = state
  #     )
  #     when round_initiator in [:self] and expected_state == :provide_hash do
  #   {responder_pub, _priv} = keypair_responder()
  #   {_role, _channel_config, _reestablish, initiator_keypair} = state.params
  #   {initiator_pub, _priv} = initiator_keypair.()

  #   Logger.info("providing hash")

  #   some_salt = ContractHelper.add_quotes("some_salt")
  #   coin = ContractHelper.add_quotes("heads")

  #   fun =
  #     &SocketConnector.call_contract_dry(
  #       &1,
  #       state.responder_contract,
  #       'compute_hash',
  #       [to_charlist(some_salt), to_charlist(coin)],
  #       &2
  #     )

  #   {:ok, {:bytes, [], hash}} = SessionHolder.run_action_sync(state.pid_session_holder, fun)

  #   fun1 =
  #     &SocketConnector.call_contract(
  #       &1,
  #       state.responder_contract,
  #       'provide_hash',
  #       [to_charlist(ContractHelper.to_sophia_bytes(hash))],
  #       # this is what we put at stake.
  #       10
  #     )

  #   SessionHolder.run_action(state.pid_session_holder, fun1)
  #   {:noreply, %__MODULE__{state | expected_state: :player_pick, game: %{hash: hash, coin: coin, salt: some_salt}}}
  # end

  # def handle_cast(
  #       {:channels_update, _round, round_initiator, "channels.update"} = _message,
  #       %__MODULE__{expected_state: expected_state} = state
  #     )
  #     when round_initiator in [:self] and expected_state == :player_pick do
  #   Logger.info("Waiting for player to make a guess")
  #   {:noreply, %__MODULE__{state | expected_state: :reveal}}
  # end

  # def handle_cast(
  #       {:channels_update, _round, round_initiator, "channels.update"} = _message,
  #       %__MODULE__{game: game, expected_state: expected_state} = state
  #     )
  #     when round_initiator in [:other] and expected_state == :reveal do
  #   Logger.info("Other player made a guess, settling funds")

  #   fun =
  #     &SocketConnector.call_contract(
  #       &1,
  #       state.responder_contract,
  #       'reveal',
  #       [to_charlist(game.salt), to_charlist(game.coin)]
  #     )

  #   SessionHolder.run_action(state.pid_session_holder, fun)
  #   {:noreply, %__MODULE__{state | expected_state: :provide_hash}}
  # end

  # def handle_cast({:channels_update, 5, round_initiator, "channels.update"} = _message, state)
  #     when round_initiator in [:self] do
  #   Logger.info("Game end, backend emptying contract")

  #   fun =
  #     &SocketConnector.call_contract(
  #       &1,
  #       state.responder_contract,
  #       'drain',
  #       []
  #     )

  #   SessionHolder.run_action(state.pid_session_holder, fun)

  #   {:noreply, state}
  # end

  # def handle_cast({:channels_update, 5, _round_initiator, "channels.update"} = _message, state) do
  #   Logger.info("Shutdown game has reached end after one one toss, check account balances")
  #   fun = &SocketConnector.shutdown(&1)
  #   SessionHolder.run_action(state.pid_session_holder, fun)
  #   {:noreply, state}
  # end

  # this is :sign_provide_hash
  def handle_cast(
        {{:sign_approve, _round, _round_initiator, method,
          [%{decoded_calldata: {"provide_hash", _params}}, %{"amount" => amount}], %{"type" => _type} = _human,
          _channel_id}, to_sign} = _message,
        state
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

        {:noreply, %__MODULE__{state | game: %{amount: amount}, expected_state: :perform_casino_pick}}

      false ->
        # not enough funds to play, TODO, message is not provided to other end?
        fun = &SocketConnector.abort(&1, method, 555, "not enough funds")
        SessionHolder.run_action(state.pid_session_holder, fun)

        {:noreply, %__MODULE__{state | game: %{amount: amount}, expected_state: :sign_provide_hash}}
    end
  end

  @coin_sides ["heads", "tails"]
  # this is :perform_casino_pick
  def handle_cast(
        {:channels_update, _round, round_initiator, "channels.update"} = _message,
        %__MODULE__{expected_state: :perform_casino_pick} = state
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
        {:noreply, %__MODULE__{state | expected_state: :sign_casino_pick}}
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
  def handle_cast(
        {{:sign_approve, _round, _round_initiator, method,
          [%{decoded_calldata: {"reveal", _params}}, %{"amount" => amount}], %{"type" => _type} = _human,
          _channel_id}, to_sign} = _message,
        state
      ) do
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)
    {:noreply, %__MODULE__{state | game: %{amount: amount}, expected_state: :sign_provide_hash}}
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

        # if timer elapsed, try and force progress, the same goes for if it's been quiet to long....
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
end
