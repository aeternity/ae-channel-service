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

  def connection_callback(callback_pid, color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, human ->
        Logger.debug(
          "Sign request for round: #{inspect(round)}, initated by: #{inspect(round_initiator)}. auto_approval: #{
            inspect(auto_approval)
          }, containing: #{inspect(human)}",
          ansi_color: color
        )

        auto_approval
      end,
      channels_update: fn round_initiator, round, method ->
        Logger.debug(
          "callback received round is: #{inspect(round)} round_initiator is: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        case round_initiator do
          :self ->
            GenServer.cast(callback_pid, {:process_job_lists})

          :other ->
            GenServer.cast(callback_pid, {:process_job_lists})

          :transient ->
            # connect/reconnect allow grace period before resuming
            spawn(fn ->
              Process.sleep(500)
              GenServer.cast(callback_pid, {:process_job_lists})
            end)
        end
      end
    }
  end

  # Server
  def init(
        {pub_key, priv_key, %SocketConnector.WsConnection{} = state_channel_configuration, ae_url, network_id,
         role, jobs, color, name}
      ) do
    {:ok, pid_session_holder} =
      SessionHolder.start_link(%{
        socket_connector: %SocketConnector{
          pub_key: pub_key,
          priv_key: priv_key,
          session: state_channel_configuration,
          role: role,
          connection_callbacks: connection_callback(self(), color)
        },
        ae_url: ae_url,
        network_id: network_id,
        color: color,
        pid_name: name
      })

    {:ok,
     %__MODULE__{
       pid_session_holder: pid_session_holder,
       job_list: jobs,
       color: [ansi_color: color]
     }}
  end

  # TODO time to move this module to ex unit
  def expected(response, {account1, value1}, {account2, value2}) do
    expect =
      Enum.sort([
        %{"account" => account1, "balance" => value1},
        %{"account" => account2, "balance" => value2}
      ])

    Logger.debug("expected #{inspect(Enum.sort(expect))} got #{inspect(response)}")
    ^expect = Enum.sort(response)
  end

  def assert_funds_job({account1, value1}, {account2, value2}) do
    {:sync,
     fn pid, from ->
       SocketConnector.query_funds(pid, from)
     end,
     fn result ->
       expected(result, {account1, value1}, {account2, value2})
     end}
  end

  def handle_cast({:process_job_lists}, state) do
    remaining_jobs =
      case Enum.count(state.job_list) do
        0 ->
          Logger.debug("End of sequence", state.color)
          []

        remaining ->
          Logger.debug("Sequence remainin jobs #{inspect(remaining)}", state.color)
          [{mode, fun, assert_fun} | rest] = state.job_list

          case mode do
            :async ->
              SessionHolder.run_action(state.pid_session_holder, fun)

            :sync ->
              response = SessionHolder.run_action_sync(state.pid_session_holder, fun)

              case assert_fun do
                :empty -> :empty
                _ -> assert_fun.(response)
              end

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
       end, :empty}
    end)
  end

  def contract_jobs({_initiator, intiator_account}, {_responder, responder_account}) do
    initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}
    # responder_contract = {TestAccounts.responderPubkeyEncoded(), "contracts/TicTacToe.aes"}

    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_997},
        {responder_account, 4_000_000_000_003}
      ),
      {:async, fn pid -> SocketConnector.new_contract(pid, initiator_contract) end, :empty},
      {:async,
       fn pid ->
         SocketConnector.call_contract(
           pid,
           initiator_contract,
           'make_move',
           ['11', '1']
         )
       end, :empty},
      {:sync,
       fn pid, from ->
         SocketConnector.get_contract_reponse(
           pid,
           initiator_contract,
           'make_move',
           from
         )
       end, :empty},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end, :empty},
      # hard coded to put 10 coins in the created contract
      assert_funds_job(
        {intiator_account, 6_999_999_999_984},
        {responder_account, 4_000_000_000_006}
      ),
      {:async,
       fn pid ->
         SocketConnector.withdraw(pid, 1_000_000)
       end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_998_999_984},
        {responder_account, 4_000_000_000_006}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 4) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_998_999_980},
        {responder_account, 4_000_000_000_010}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      {:async,
       fn pid ->
         SocketConnector.deposit(pid, 500_000)
       end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_499_975},
        {responder_account, 4_000_000_000_015}
      )
    ]

    jobs_responder =
      empty_jobs(1..8) ++
        [
          {:async,
           fn pid ->
             SocketConnector.call_contract(
               pid,
               initiator_contract,
               'make_move',
               ['11', '2']
             )
           end, :empty},
          {:sync,
           fn pid, from ->
             SocketConnector.get_contract_reponse(
               pid,
               initiator_contract,
               'make_move',
               from
             )
           end, :empty}
        ]

    {jobs_initiator, jobs_responder}
  end

  def reestablish_jobs({_initiator, intiator_account}, {_responder, responder_account}) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end, :empty},
      {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
      {:local, fn _client_runner, pid_session_holder -> SessionHolder.reestablish(pid_session_holder) end, :empty}
    ]

    jobs_responder =
      empty_jobs(1..2) ++
        [
          {:local,
           fn _client_runner, pid_session_holder ->
             SessionHolder.reestablish(pid_session_holder)
           end, :empty},
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end, :empty},
          assert_funds_job(
            {intiator_account, 6_999_999_999_997},
            {responder_account, 4_000_000_000_003}
          )
        ]

    {jobs_initiator, jobs_responder}
  end

  def reconnect_jobs({_initiator, intiator_account}, {_responder, responder_account}) do
    jobs_initiator = [
      assert_funds_job(
        {intiator_account, 6_999_999_999_999},
        {responder_account, 4_000_000_000_001}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_997},
        {responder_account, 4_000_000_000_003}
      )
    ]

    jobs_responder =
      empty_jobs(1..1) ++
        [
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end, :empty},
          {:local,
           fn client_runner, pid_session_holder ->
             SessionHolder.close_connection(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          {:local,
           fn client_runner, _pid_session_holder ->
             Process.sleep(3000)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          {:local,
           fn client_runner, pid_session_holder ->
             SessionHolder.reconnect(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          assert_funds_job(
            {intiator_account, 6_999_999_999_997},
            {responder_account, 4_000_000_000_003}
          ),
          {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
          assert_funds_job(
            {intiator_account, 6_999_999_999_999},
            {responder_account, 4_000_000_000_001}
          )
        ]

    {jobs_initiator, jobs_responder}
  end

  def close_solo(_initiator, _responder) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      {:async, fn pid -> SocketConnector.close_solo(pid) end, :empty}
    ]

    jobs_responder = []

    {jobs_initiator, jobs_responder}
  end

  # https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md#example
  def backchannel_jobs({initiator, intiator_account}, {_responder, responder_account}) do
    jobs_initiator = [
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.close_connection(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(10000)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.reconnect(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      assert_funds_job(
        {intiator_account, 7_000_000_000_003},
        {responder_account, 3_999_999_999_997}
      ),
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(5000)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_998},
        {responder_account, 4_000_000_000_002}
      )
    ]

    jobs_responder = [
      {:local,
       fn client_runner, _pid_session_holder ->
         Process.sleep(3000)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_999},
        {responder_account, 4_000_000_000_001}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end, :empty},
      {:async,
       fn pid ->
         SocketConnector.initiate_transfer(pid, 4, fn to_sign ->
           SessionHolder.backchannel_sign_request(initiator, to_sign)
           # GenServer.call(initiator, {:sign_request, to_sign})
         end)
       end, :empty},
      assert_funds_job(
        {intiator_account, 7_000_000_000_003},
        {responder_account, 3_999_999_999_997}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty}
    ]

    {jobs_initiator, jobs_responder}
  end

  def joblist(),
    do: [
      &backchannel_jobs/2,
      &close_solo/2,
      &reconnect_jobs/2,
      &contract_jobs/2,
      &reestablish_jobs/2
    ]

  def gen_name(name, suffix) do
    String.to_atom(to_string(name) <> Integer.to_string(suffix))
  end

  # to give the FSM a fair chance to pair together the peers. We are using same two accouts for every connection
  @grace_period_ms 5000

  def start_helper(ae_url, network_id) do
    Enum.each(Enum.zip(joblist(), 1..Enum.count(joblist())), fn {fun, suffix} ->
      start_helper(ae_url, network_id, gen_name(:alice, suffix), gen_name(:bob, suffix), fun)
      Process.sleep(@grace_period_ms)
    end)
  end

  def start_helper(ae_url, network_id, name_initator, name_responder, job_builder) do
    initiator_pub = TestAccounts.initiatorPubkeyEncoded()
    responder_pub = TestAccounts.responderPubkeyEncoded()

    {jobs_initiator, jobs_responder} =
      job_builder.({name_initator, initiator_pub}, {name_responder, responder_pub})

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
