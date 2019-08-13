defmodule ClientRunner do
  use GenServer
  require Logger

  # @sync_call_timeout 10_000

  defstruct pid_session_holder: nil,
            color: nil,
            job_list: nil

  # @jobs [{:SocketConnector, :initiate_transfer, [2]}]
  # @jobs [{fn pid -> SocketConnector.initiate_transfer(pid, 2) end}]

  def start_link(
        {_pub_key, _priv_key, %SocketConnector.WsConnection{}, _ae_url, _network_id, _role, _jobs, _color} =
          params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  # Server
  def init(
        {pub_key, priv_key, %SocketConnector.WsConnection{} = state_channel_configuration, ae_url,
         network_id, role, jobs, color}
      ) do
    {:ok, pid_session_holder} =
      SessionHolder.start_link(
        %SocketConnector{
          pub_key: pub_key,
          priv_key: priv_key,
          session: state_channel_configuration,
          role: role,
          connection_callbacks: %SocketConnector.ConnectionCallbacks{
            sign_approve: fn _x -> :ok end,
            channels_update: fn nonce -> nonce end
          }
        },
        ae_url,
        network_id,
        color
      )

    GenServer.cast(self(), {:process_job_lists})
    {:ok, %__MODULE__{pid_session_holder: pid_session_holder, job_list: jobs, color: [ansi_color: color]}}
  end

  def handle_cast({:process_job_lists}, state) do
    # [{mod, func, args} | rest] = state.job_list
    # apply(mod, func, args)
    # SessionHolder.run_action(state.pid_session_holder, )
    Process.sleep(5000)
    remaining_jobs =
      case Enum.count(state.job_list) do
        0 ->
          Logger.debug "End of sequence", state.color
          []
        remaining ->
          Logger.debug "Sequence remainin jobs #{inspect remaining}", state.color
          [{fun} | rest] = state.job_list
          SessionHolder.run_action(state.pid_session_holder, fun)
          GenServer.cast(self(), {:process_job_lists})
          rest
      end
    {:noreply, %__MODULE__{state | job_list: remaining_jobs}}
  end



  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"

  # TestAccounts.initiatorPubkey(),
  # TestAccounts.initiatorPrivkey(),
  # TestAccounts.responderPubkey(),
  # TestAccounts.responderPrivkey(),

  # def start_link(
  #       {_pub_key, _priv_key, %SocketConnector.WsConnection{}, _ae_url, _network_id, _color} =
  #         params
  #     ) do
  #   GenServer.start_link(__MODULE__, params)
  # end


  def start_helper() do

    jobs = [{fn pid -> SocketConnector.initiate_transfer(pid, 2) end}]
    initiator_pub = TestAccounts.initiatorPubkey()
    responder_pub = TestAccounts.responderPubkey()
    state_channel_configuration = %SocketConnector.WsConnection{
        initiator: initiator_pub,
        initiator_amount: 7_000_000_000_000,
        responder: responder_pub,
        responder_amount: 4_000_000_000_000
      }
    start_link({TestAccounts.initiatorPubkey(), TestAccounts.initiatorPrivkey(), state_channel_configuration, @ae_url, @network_id, :initiator, jobs, :yellow})
    start_link({TestAccounts.responderPubkey(), TestAccounts.responderPrivkey(), state_channel_configuration, @ae_url, @network_id, :responder, [], :blue})
  end
  #
  # def handle_cast({:connection_dropped, configuration}, state) do
  #   # TODO, remove delay
  #   # give to other fair chanse to disconnect
  #   Process.sleep(1000)
  #   reestablish(self())
  #   {:noreply, %__MODULE__{state | configuration: configuration}}
  # end
  #
  # def handle_cast({:reestablish}, state) do
  #   Logger.debug("about to reestablish connection", ansi_color: state.color)
  #
  #   {:ok, pid} =
  #     SocketConnector.start_link(:alice, state.configuration, :reestablish, state.color, self())
  #
  #   {:noreply, %__MODULE__{state | pid: pid}}
  # end
  #
  # def handle_cast({:action, action}, state) do
  #   action.(state.pid)
  #   {:noreply, state}
  # end
  #
  # def handle_call({:action_sync, action}, from, state) do
  #   action.(state.pid, from)
  #   {:noreply, state}
  # end
end
