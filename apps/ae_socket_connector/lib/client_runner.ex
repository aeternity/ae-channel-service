defmodule ClientRunner do
  use GenServer
  require Logger

  defstruct pid_session_holder: nil,
            color: nil,
            job_list: nil

  def start_link(
        {_pub_key, _priv_key, %SocketConnector.WsConnection{}, _ae_url, _network_id, _role, _jobs, _color, _name} =
          params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  # Server
  def init(
        {pub_key, priv_key, %SocketConnector.WsConnection{} = state_channel_configuration, ae_url, network_id,
         role, jobs, color, name}
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
            sign_approve: fn round_initiator, round, auto_approval, human ->
              Logger.debug(
                "Sign request for round: #{inspect(round)}, initated by: #{inspect(round_initiator)}. auto_approval: #{
                  inspect(auto_approval)
                }, containing: #{inspect(human)}",
                ansi_color: color
              )

              auto_approval
            end,
            channels_update: fn round_initiator, nonce, method ->
              Logger.debug(
                "callback received round is: #{inspect(nonce)} round_initiator is: #{inspect(round_initiator)} method is #{
                  inspect(method)
                }}",
                ansi_color: color
              )

              case round_initiator do
                :self ->
                  GenServer.cast(current_pid, {:process_job_lists})

                :other ->
                  GenServer.cast(current_pid, {:process_job_lists})

                :transient ->
                  # connect/reconnect allow grace period before resuming
                  spawn(fn ->
                    Process.sleep(500)
                    GenServer.cast(current_pid, {:process_job_lists})
                  end)
              end
            end
          }
        },
        ae_url,
        network_id,
        color,
        name
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
              # Logger.error("sync response is: #{inspect(response)}")
              GenServer.cast(self(), {:process_job_lists})

            :local ->
              fun.(self(), state.pid_session_holder)
          end

          rest
      end

    {:noreply, %__MODULE__{state | job_list: remaining_jobs}}
  end

  def empty_jobs(interval) do
    Enum.map(interval, fn count ->
      {:local,
       fn _client_runner, _pid_session_holder ->
         Logger.debug("doing nothing #{inspect(count)}", ansi_color: :white)
       end}
    end)
  end

  def contract_jobs(_intiator, _responder) do
    initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}
    # responder_contract = {TestAccounts.responderPubkeyEncoded(), "contracts/TicTacToe.aes"}

    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.new_contract(pid, initiator_contract) end},
      {:async,
       fn pid ->
         SocketConnector.call_contract(
           pid,
           initiator_contract,
           'make_move',
           ['11', '1']
         )
       end},
      {:sync,
       fn pid, from ->
         SocketConnector.get_contract_reponse(
           pid,
           initiator_contract,
           'make_move',
           from
         )
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end},
      {:async,
       fn pid ->
         SocketConnector.withdraw(pid, 1_000_000)
       end},
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

    jobs_responder =
      empty_jobs(1..7) ++
        [
          {:async,
           fn pid ->
             SocketConnector.call_contract(
               pid,
               initiator_contract,
               'make_move',
               ['11', '2']
             )
           end},
          {:sync,
           fn pid, from ->
             SocketConnector.get_contract_reponse(
               pid,
               initiator_contract,
               'make_move',
               from
             )
           end}
        ]

    {jobs_initiator, jobs_responder}
  end

  def reestablish_jobs(_initiator, _responder) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.leave(pid) end},
      {:local, fn _client_runner, pid_session_holder -> SessionHolder.reestablish(pid_session_holder) end}
    ]

    jobs_responder =
      empty_jobs(1..2) ++
        [
          {:local,
           fn _client_runner, pid_session_holder ->
             SessionHolder.reestablish(pid_session_holder)
           end},
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end}
        ]

    {jobs_initiator, jobs_responder}
  end

  def reconnect_jobs(_intiator, _responder) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end}
    ]

    jobs_responder =
      empty_jobs(1..1) ++
        [
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end},
          {:local,
           fn client_runner, pid_session_holder ->
             SessionHolder.close_connection(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end},
          {:local,
           fn client_runner, _pid_session_holder ->
             Process.sleep(3000)
             GenServer.cast(client_runner, {:process_job_lists})
           end},
          {:local,
           fn client_runner, pid_session_holder ->
             SessionHolder.reconnect(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end},
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end},
          {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end}
        ]

    {jobs_initiator, jobs_responder}
  end

  def close_solo(_initiator, _responder) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end},
      {:async, fn pid -> SocketConnector.close_solo(pid) end}
    ]

    jobs_responder = []

    {jobs_initiator, jobs_responder}
  end

  # https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md#example
  def backchannel_jobs(initiator, _responder) do
    jobs_initiator = [
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.close_connection(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end},
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(10000)
         GenServer.cast(client_runner, {:process_job_lists})
       end},
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.reconnect(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(5000)
         GenServer.cast(client_runner, {:process_job_lists})
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end}
    ]

    jobs_responder = [
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(3000)
         GenServer.cast(client_runner, {:process_job_lists})
       end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end},
      {:async,
       fn pid ->
         SocketConnector.initiate_transfer(pid, 4, fn to_sign ->
           SessionHolder.backchannel_sign_request(initiator, to_sign)
           # GenServer.call(initiator, {:sign_request, to_sign})
         end)
       end},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end}
    ]

    {jobs_initiator, jobs_responder}
  end

  def start_helper(ae_url, network_id) do
    # start_helper(ae_url, network_id, :alice, :bob, &backchannel_jobs/2)
    # start_helper(ae_url, network_id, :alice, :bob, &close_solo/2)
    # start_helper(ae_url, network_id, :alice2, :bob2, &reconnect_jobs/2)
    start_helper(ae_url, network_id, :alice2, :bob2, &contract_jobs/2)
    # start_helper(ae_url, network_id, :alice2, :bob2, &reestablish_jobs/2)
  end

  def start_helper(ae_url, network_id, name_initator, name_responder, job_builder) do
    {jobs_initiator, jobs_responder} = job_builder.(name_initator, name_responder)

    initiator_pub = TestAccounts.initiatorPubkeyEncoded()
    responder_pub = TestAccounts.responderPubkeyEncoded()

    state_channel_configuration = %SocketConnector.WsConnection{
      initiator: initiator_pub,
      initiator_amount: 7_000_000_000_000,
      responder: responder_pub,
      responder_amount: 4_000_000_000_000
    }

    start_link(
      {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey(), state_channel_configuration, ae_url,
       network_id, :initiator, jobs_initiator, :yellow, name_initator}
    )

    start_link(
      {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey(), state_channel_configuration, ae_url,
       network_id, :responder, jobs_responder, :blue, name_responder}
    )
  end
end
