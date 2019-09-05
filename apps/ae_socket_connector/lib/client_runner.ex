defmodule ClientRunner do
  use GenServer
  require Logger

  defstruct pid_session_holder: nil,
            color: nil,
            job_list: nil

  def joblist(),
    do: [
      # &withdraw_after_reconnect/3,
      # &withdraw_after_reestablish/3,
      # &backchannel_jobs/3,
      # &close_solo/3,
      &close_mutual/3
      # &reconnect_jobs/3,
      # &contract_jobs/3,
      # keep this last, this is not returnning as expected
      # &reestablish_jobs/3
    ]

  def start_link(
        {_pub_key, _priv_key, %SocketConnector.WsConnection{}, _ae_url, _network_id, _role, _jobs,
         _color, _name} = params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  def connection_callback(callback_pid, color) do
    %SocketConnector.ConnectionCallbacks{
      # auto approval is the suggested response. Typically if initiated by us and matches with our request we should approve.
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
          "callback received round is: #{inspect(round)} round_initiator is: #{
            inspect(round_initiator)
          } method is #{inspect(method)}}",
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
        {pub_key, priv_key, %SocketConnector.WsConnection{} = state_channel_configuration, ae_url,
         network_id, role, jobs, color, name}
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

  def contract_jobs({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
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
      ),
      sequence_finish_job(runner_pid, initiator)
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
           end, :empty},
          sequence_finish_job(runner_pid, responder)
        ]

    {jobs_initiator, jobs_responder}
  end

  def reestablish_jobs({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      {:sync,
       fn pid, from ->
         SocketConnector.query_funds(pid, from)
       end, :empty},
      {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.reestablish(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder =
      empty_jobs(1..2) ++
        [
          {:local,
           fn client_runner, pid_session_holder ->
             SessionHolder.reestablish(pid_session_holder)
             GenServer.cast(client_runner, {:process_job_lists})
           end, :empty},
          {:sync,
           fn pid, from ->
             SocketConnector.query_funds(pid, from)
           end, :empty},
          assert_funds_job(
            {intiator_account, 6_999_999_999_997},
            {responder_account, 4_000_000_000_003}
          ),
          sequence_finish_job(runner_pid, responder)
        ]

    {jobs_initiator, jobs_responder}
  end

  def pause_job(delay) do
    {:local,
     fn client_runner, _pid_session_holder ->
       spawn(fn ->
         Process.sleep(delay)
         GenServer.cast(client_runner, {:process_job_lists})
       end)
     end, :empty}
  end

  def reconnect_jobs({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    jobs_initiator = [
      assert_funds_job(
        {intiator_account, 6_999_999_999_999},
        {responder_account, 4_000_000_000_001}
      ),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_997},
        {responder_account, 4_000_000_000_003}
      ),
      sequence_finish_job(runner_pid, initiator)
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
          pause_job(3000),
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
          ),
          sequence_finish_job(runner_pid, responder)
        ]

    {jobs_initiator, jobs_responder}
  end

  def close_solo_job() do
    # special cased since this doesn't end up in an update.
    close_solo = fn pid -> SocketConnector.close_solo(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, close_solo)
       GenServer.cast(client_runner, {:process_job_lists})
     end, :empty}
  end

  def close_mutual_job() do
    # special cased since this doesn't end up in an update.
    shutdown = fn pid -> SocketConnector.shutdown(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, shutdown)
       GenServer.cast(client_runner, {:process_job_lists})
     end, :empty}
  end

  def close_solo({initiator, _intiator_account}, {responder, _responder_account}, runner_pid) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      close_solo_job(),
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder = [
      sequence_finish_job(runner_pid, responder)
    ]

    {jobs_initiator, jobs_responder}
  end

  def close_mutual({initiator, _intiator_account}, {responder, _responder_account}, runner_pid) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
      # {:async, fn pid -> SocketConnector.shutdown(pid) end, :empty},
      close_mutual_job(),
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder = [
      sequence_finish_job(runner_pid, responder)
    ]

    {jobs_initiator, jobs_responder}
  end

  def sequence_finish_job(runner_pid, name) do
    {:local,
     fn _client_runner, _pid_session_holder ->
       Logger.info("Sending termination for #{inspect(name)}")
       send(runner_pid, {:test_finished, name})
     end, :empty}
  end

  # https://github.com/aeternity/protocol/blob/master/node/api/channels_api_usage.md#example
  def backchannel_jobs({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    jobs_initiator = [
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.close_connection(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      pause_job(10000),
      {:local,
       fn client_runner, pid_session_holder ->
         SessionHolder.reconnect(pid_session_holder)
         GenServer.cast(client_runner, {:process_job_lists})
       end, :empty},
      assert_funds_job(
        {intiator_account, 7_000_000_000_003},
        {responder_account, 3_999_999_999_997}
      ),
      pause_job(5000),
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      assert_funds_job(
        {intiator_account, 6_999_999_999_998},
        {responder_account, 4_000_000_000_002}
      ),
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder = [
      pause_job(3000),
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
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      sequence_finish_job(runner_pid, responder)
    ]

    {jobs_initiator, jobs_responder}
  end

  def gen_name(name, suffix) do
    String.to_atom(to_string(name) <> Integer.to_string(suffix))
  end

  # elimiation overlap yields issues, need to be investigated
  @grace_period_ms 2000

  def start_helper(ae_url, network_id) do
    Enum.each(Enum.zip(joblist(), 1..Enum.count(joblist())), fn {fun, suffix} ->
      start_helper(ae_url, network_id, gen_name(:alice, suffix), gen_name(:bob, suffix), fun)
      Process.sleep(@grace_period_ms)
    end)
  end

  def await_finish([]) do
    Logger.debug("Scenario reached end")
  end

  def await_finish(expected_messages) do
    receive do
      {:test_finished, name} ->
        reduced_list = List.delete(expected_messages, name)

        Logger.debug(
          "Received message from runner: #{inspect(name)} remaining: #{inspect(reduced_list)}"
        )

        await_finish(reduced_list)
    end
  end

  def start_helper(ae_url, network_id, name_initator, name_responder, job_builder) do
    initiator_pub = TestAccounts.initiatorPubkeyEncoded()
    responder_pub = TestAccounts.responderPubkeyEncoded()

    Logger.debug("executing test: #{inspect(job_builder)}")

    {jobs_initiator, jobs_responder} =
      job_builder.({name_initator, initiator_pub}, {name_responder, responder_pub}, self())

    state_channel_configuration = %SocketConnector.WsConnection{
      initiator: initiator_pub,
      initiator_amount: 7_000_000_000_000,
      responder: responder_pub,
      responder_amount: 4_000_000_000_000
    }

    start_link(
      {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey(),
       state_channel_configuration, ae_url, network_id, :initiator, jobs_initiator, :yellow,
       name_initator}
    )

    start_link(
      {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey(),
       state_channel_configuration, ae_url, network_id, :responder, jobs_responder, :blue,
       name_responder}
    )

    await_finish([name_initator, name_responder])
  end
end
