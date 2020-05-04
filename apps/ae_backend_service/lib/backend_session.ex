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

  defstruct pid_session_holder: nil,
            pid_backend_manager: nil,
            identifier: nil,
            params: nil,
            port: nil

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

    {:noreply, %__MODULE__{state | pid_session_holder: pid, port: port}}
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
    responder_contract =
      {TestAccounts.initiatorPubkeyEncoded(), "contracts/tictactoe.aes",
       %{abi_version: 3, vm_version: 5, backend: :fate}}

    fun = &SocketConnector.new_contract(&1, responder_contract, 10)
    SessionHolder.run_action(state.pid_session_holder, fun)
    {:noreply, state}
  end

  # TODO backend just happily signs
  def handle_cast(
        {{:sign_approve, _round, _round_initiator, method, updates, _human, _channel_id}, to_sign} = _message,
        state
      ) do
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)
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
end
