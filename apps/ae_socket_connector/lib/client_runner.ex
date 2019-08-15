defmodule ClientRunner do
  use GenServer
  require Logger

  defstruct pid_session_holder: nil,
            color: nil,
            job_list: nil

  def start_link(
        {_pub_key, _priv_key, %SocketConnector.WsConnection{}, _ae_url, _network_id, _role, _jobs,
         _color} = params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  # Server
  def init(
        {pub_key, priv_key, %SocketConnector.WsConnection{} = state_channel_configuration, ae_url,
         network_id, role, jobs, color}
      ) do
    current_pid = self()

    {:ok, pid_session_holder} =
      SessionHolder.start_link(
        %SocketConnector{
          pub_key: pub_key,
          priv_key: priv_key,
          session: state_channel_configuration,
          role: role,
          connection_callbacks: %SocketConnector.ConnectionCallbacks{
            sign_approve: fn _x -> :ok end,
            channels_update: fn (round_initiator, nonce) ->
              Logger.debug("callback received round is: #{inspect(nonce)} round_initiator is: #{inspect round_initiator}}", ansi_color: color)
              case round_initiator do
                n when n == :self or n == :init ->
                  GenServer.cast(current_pid, {:process_job_lists})
                :other ->
                  GenServer.cast(current_pid, {:process_job_lists})
              end
            end
          }
        },
        ae_url,
        network_id,
        color
      )

    {:ok,
     %__MODULE__{
       pid_session_holder: pid_session_holder,
       job_list: jobs,
       color: [ansi_color: color]
     }}
  end

  def handle_cast({:process_job_lists}, state) do
    remaining_jobs =
      case Enum.count(state.job_list) do
        0 ->
          Logger.debug("End of sequence", state.color)
          []

        remaining ->
          Logger.debug("Sequence remainin jobs #{inspect(remaining)}", state.color)
          [{mode, fun} | rest] = state.job_list

          case mode do
            :async ->
              SessionHolder.run_action(state.pid_session_holder, fun)

            :sync ->
              response = SessionHolder.run_action_sync(state.pid_session_holder, fun)
              Logger.debug("sync response is: #{inspect(response)}", state.color)
              GenServer.cast(self(), {:process_job_lists})

            :local ->
              fun.()
          end

          rest
      end

    {:noreply, %__MODULE__{state | job_list: remaining_jobs}}
  end

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"

  def start_helper() do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 4) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end}
    ]

    empty_jobs = Enum.map(1..4, fn(count) -> {:local, fn -> Logger.debug("doing nothing #{inspect count}", ansi_color: :white) end} end)
    jobs_responder = empty_jobs ++ jobs_initiator

    initiator_pub = TestAccounts.initiatorPubkey()
    responder_pub = TestAccounts.responderPubkey()

    state_channel_configuration = %SocketConnector.WsConnection{
      initiator: initiator_pub,
      initiator_amount: 7_000_000_000_000,
      responder: responder_pub,
      responder_amount: 4_000_000_000_000
    }

    start_link(
      {TestAccounts.initiatorPubkey(), TestAccounts.initiatorPrivkey(),
       state_channel_configuration, @ae_url, @network_id, :initiator, jobs_initiator, :yellow}
    )

    start_link(
      {TestAccounts.responderPubkey(), TestAccounts.responderPrivkey(),
       state_channel_configuration, @ae_url, @network_id, :responder, jobs_responder, :blue}
    )
  end
end
