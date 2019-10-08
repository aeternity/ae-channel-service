defmodule ClientRunner do
  use GenServer
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"


  # @ae_url "wss://testnet.demo.aeternity.io/channel"
  # @network_id "ae_uat"

  import ClientRunnerHelper
  # TODO :local always? produces a cast, could we move this to :local runner

  defmacro ae_url, do: @ae_url
  defmacro network_id, do: @network_id

  defstruct pid_session_holder: nil,
            color: nil,
            job_list: nil,
            match_list: nil,
            fuzzy_counter: 0

  # socket_holder_name: nil,
  # runner_pid: nil

  def start_channel_helper(),
    do: ClientRunner.start_helper(@ae_url, @network_id)

  def joblist(),
    do: [
      &hello_fsm_v3/3,
      &hello_fsm_v2/3,
      &withdraw_after_reconnect_v2/3,
      # &withdraw_after_reestablish/3,
      &backchannel_jobs_v2/3,
      &close_solo_v2/3,
      &close_mutual_v2/3,
      &reconnect_jobs_v2/3,
      &contract_jobs_v2/3
      # &reestablish_jobs/3,
      # &query_after_reconnect/3,
      # # TODO missing "get state"
      # # This is unfinished, info callback needs to be refined and configurable minimg height.
      # &teardown_on_channel_creation/3
    ]

  def start_link(
        {_pub_key, _priv_key, _state_channel_configuration, _ae_url, _network_id, _role, _jobs, _color, _name} =
          params
      ) do
    GenServer.start_link(__MODULE__, params)
  end

  # example
  # %{
  # {:initiator, %{message: {:channels_update, 1, :transient, "channels.update"}, next: {:run_job}, fuzzy: 3}},
  # }

  def hello_fsm_v2({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
    do: [
      # opening channel
      {:responder, %{message: {:channels_info, 0, :transient, "channel_open"}}},
      {:initiator, %{message: {:channels_info, 0, :transient, "channel_accept"}}},
      {:initiator, %{message: {:sign_approve, 1}}},
      {:responder, %{message: {:channels_info, 0, :transient, "funding_created"}}},
      {:responder, %{message: {:sign_approve, 1}}},
      {:initiator, %{message: {:channels_info, 0, :transient, "funding_signed"}}},
      {:responder, %{message: {:channels_info, 0, :transient, "own_funding_locked"}}},
      {:initiator, %{message: {:channels_info, 0, :transient, "own_funding_locked"}}},
      {:initiator, %{message: {:channels_info, 0, :transient, "funding_locked"}}},
      {:responder, %{message: {:channels_info, 0, :transient, "funding_locked"}}},
      {:initiator, %{message: {:channels_info, 0, :transient, "open"}}},
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
         fuzzy: 3
       }},
      {:responder, %{message: {:channels_info, 0, :transient, "open"}}},
      {:responder, %{message: {:channels_update, 1, :transient, "channels.update"}}},
      # end of opening sequence
      # leaving
      {:responder,
       %{
         message: {:channels_update, 1, :transient, "channels.leave"},
         fuzzy: 0,
         next: sequence_finish_job(runner_pid, responder)
       }},
      {:initiator, %{message: {:channels_update, 1, :transient, "channels.leave"}, fuzzy: 0}},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "died"},
         fuzzy: 0,
         next: sequence_finish_job(runner_pid, initiator)
       }}
    ]

  def hello_fsm_v3({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
         fuzzy: 10
       }},
      {:responder,
       %{
         message: {:channels_update, 1, :transient, "channels.leave"},
         fuzzy: 20,
         next: sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "died"},
         fuzzy: 20,
         next: sequence_finish_job(runner_pid, initiator)
       }}
    ]

  def withdraw_after_reconnect_v2({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.close_connection(pid_session_holder)
              resume_runner(client_runner)
            end, :empty},
         fuzzy: 10
       }},
      {:initiator, %{next: pause_job(1000)}},
      {:initiator,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder)
              resume_runner(client_runner)
            end, :empty},
         fuzzy: 0
       }},
      {:initiator,
       %{
         next:
           {:async,
            fn pid ->
              SocketConnector.withdraw(pid, 1_000_000)
            end, :empty},
         fuzzy: 0
       }},
      {:responder,
       %{
         message: {:channels_update, 2, :transient, "channels.update"},
         fuzzy: 20,
         next: sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         message: {:channels_update, 2, :transient, "channels.update"},
         fuzzy: 20,
         next: sequence_finish_job(runner_pid, initiator)
       }}
    ]

  def backchannel_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.close_connection(pid_session_holder)
              resume_runner(client_runner)
            end, :empty},
         fuzzy: 20
       }},
      {:responder,
       %{
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_999},
             {responder_account, 4_000_000_000_001}
           )
       }},
      {:responder,
       %{message: {:channels_update, 1, :transient, "channels.update"}, next: pause_job(3000), fuzzy: 10}},
      # this updates should fail, since other end is gone.
      {:responder,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty}
       }},
      {:responder,
       %{
         message: {:channels_update, 2, :self, "channels.conflict"},
         fuzzy: 2,
         next:
           {:async,
            fn pid ->
              SocketConnector.initiate_transfer(pid, 4, fn to_sign ->
                SessionHolder.backchannel_sign_request(initiator, to_sign)
              end)
            end, :empty}
       }},
      {:responder,
       %{
         next:
           assert_funds_job(
             {intiator_account, 7_000_000_000_003},
             {responder_account, 3_999_999_999_997}
           )
       }},
      {:responder,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty}
       }},
      {:initiator, %{next: pause_job(10000)}},
      {:initiator,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder)
              resume_runner(client_runner)
            end, :empty}
       }},
      {:initiator,
       %{
         next:
           assert_funds_job(
             {intiator_account, 7_000_000_000_003},
             {responder_account, 3_999_999_999_997}
           )
       }},
      {:initiator,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty}
       }},
      {:initiator,
       %{
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_998},
             {responder_account, 4_000_000_000_002}
           )
       }},
      {:responder,
       %{
         next: sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         next: sequence_finish_job(runner_pid, initiator)
       }}
    ]

  def connection_callback(callback_pid, color) do
    %SocketConnector.ConnectionCallbacks{
      sign_approve: fn round_initiator, round, auto_approval, human ->
        Logger.debug(
          "sign_approve received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)}. auto_approval: #{
            inspect(auto_approval)
          }, containing: #{inspect(human)}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:sign_approve, round}})
        auto_approval
      end,
      channels_info: fn round_initiator, round, method ->
        Logger.debug(
          "channels_info received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:channels_info, round, round_initiator, method}})
      end,
      channels_update: fn round_initiator, round, method ->
        Logger.debug(
          "channels_update received round is: #{inspect(round)}, initated by: #{inspect(round_initiator)} method is #{
            inspect(method)
          }}",
          ansi_color: color
        )

        GenServer.cast(callback_pid, {:match_jobs, {:channels_update, round, round_initiator, method}})
      end
    }
  end

  def seperate_jobs(job_list) do
    {filter_jobs(job_list, :initiator), filter_jobs(job_list, :responder)}
  end

  def filter_jobs(job_list, role) do
    Enum.reduce(job_list, [], fn {runner, event}, acc ->
      case runner == role do
        true -> acc ++ [event]
        false -> acc
      end
    end)
  end

  # Server
  def init({pub_key, priv_key, state_channel_configuration, ae_url, network_id, role, jobs, color, name}) do
    {:ok, pid_session_holder} =
      SessionHolder.start_link(%{
        socket_connector: %SocketConnector{
          pub_key: pub_key,
          priv_key: priv_key,
          session: state_channel_configuration,
          role: role,
          connection_callbacks: connection_callback(self(), color)
          # connection_callbacks: connection_callback(self(), color)
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
       #  match_list: Enum.filter(match_list(), fn (entry) -> elem(entry, 0) == role end),
       match_list: jobs,
       #  Enum.reduce(match_list.(), [], fn {runner, event}, acc ->
       #    case runner == role do
       #      true -> acc ++ [event]
       #      false -> acc
       #    end
       #  end),
       #  runner_pid: runner_pid,
       #  socket_holder_name: name,
       color: [ansi_color: color]
     }}
  end

  def run_next(match) do
    case Map.get(match, :next, false) do
      false ->
        :ok

      job ->
        # Logger.debug("running next", state.color)
        GenServer.cast(self(), {:process_job_lists, job})
    end
  end

  # {:responder, :channels_info, 0, :transient, "channel_open"}
  def handle_cast({:match_jobs, message}, state) do
    case state.match_list do
      [%{message: expected} = match | rest] ->
        Logger.error(
          "expected #{inspect(expected)} received #{inspect(message)}",
          state.color
        )

        case expected == message do
          true ->
            run_next(match)
            {:noreply, %__MODULE__{state | match_list: rest, fuzzy_counter: 0}}

          false ->
            case Map.get(match, :fuzzy, 0) do
              0 ->
                throw("message not matching")

              value ->
                case state.fuzzy_counter >= value do
                  true ->
                    throw(
                      "message has not arrived, waited for #{inspect(state.fuzzy_counter)} max wait #{
                        inspect(value)
                      }"
                    )

                  false ->
                    Logger.debug(
                      "adding to counter... #{inspect(state.fuzzy_counter)} max wait #{inspect(value)}",
                      state.color
                    )

                    {:noreply, %__MODULE__{state | fuzzy_counter: state.fuzzy_counter + 1}}
                end
            end
        end

      [%{next: _next} = match | rest] ->
        run_next(match)
        {:noreply, %__MODULE__{state | match_list: rest, fuzzy_counter: 0}}

      [] ->
        Logger.debug("list empty", state.color)
        # Logger.info("Sending termination for #{inspect(state.socket_holder_name)}")
        # send(state.runner_pid, {:test_finished, state.socket_holder_name})
        {:noreply, state}
    end
  end

  def handle_cast({:process_job_lists, next}, state) do
    {mode, fun, assert_fun} = next

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
        GenServer.cast(self(), {:match_jobs, {}})

      :local ->
        fun.(self(), state.pid_session_holder)
    end

    {:noreply, state}
  end

  def contract_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    # initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "../../contracts/TicTacToe.aes"}
    # correct path if started in shell...
    initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}

    [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
         fuzzy: 10
       }},
      {:initiator,
       %{
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_997},
             {responder_account, 4_000_000_000_003}
           )
       }},
      {:initiator, %{next: {:async, fn pid -> SocketConnector.new_contract(pid, initiator_contract) end, :empty}}},
      {:initiator,
       %{
         fuzzy: 10,
         message: {:channels_update, 3, :self, "channels.update"},
         next:
           {:async,
            fn pid ->
              SocketConnector.call_contract(
                pid,
                initiator_contract,
                'make_move',
                ['11', '1']
              )
            end, :empty}
       }},
      {:initiator,
       %{
         fuzzy: 10,
         message: {:channels_update, 4, :self, "channels.update"},
         next:
           {:sync,
            fn pid, from ->
              SocketConnector.get_contract_reponse(
                pid,
                initiator_contract,
                'make_move',
                from
              )
            end, :empty}
       }},
      {:initiator,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 3) end, :empty}
       }},
      {:initiator,
       %{
         fuzzy: 10,
         message: {:channels_update, 5, :self, "channels.update"},
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_984},
             {responder_account, 4_000_000_000_006}
           )
       }},
      {:initiator,
       %{
         next:
           {:async,
            fn pid ->
              SocketConnector.withdraw(pid, 1_000_000)
            end, :empty}
       }},
      {:initiator,
       %{
         fuzzy: 10,
         #  TODO bug somewhere, why do we go for transient here?
         message: {:channels_update, 6, :transient, "channels.update"},
         next:
           assert_funds_job(
             {intiator_account, 6_999_998_999_984},
             {responder_account, 4_000_000_000_006}
           )
       }},
      {:initiator,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 9) end, :empty}
       }},
      {:initiator,
       %{
         message: {:channels_update, 7, :self, "channels.update"},
         fuzzy: 10,
         next:
           {:async,
            fn pid ->
              SocketConnector.deposit(pid, 500_000)
            end, :empty}
       }},
      {:initiator,
       %{
         #  TODO bug somewhere, why do we go for transient here?
         message: {:channels_update, 8, :transient, "channels.update"},
         fuzzy: 10,
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_499_975},
             {responder_account, 4_000_000_000_015}
           )
       }},
      {:responder,
       %{
         fuzzy: 50,
         message: {:channels_update, 8, :transient, "channels.update"},
         next:
           {:async,
            fn pid ->
              SocketConnector.call_contract(
                pid,
                initiator_contract,
                'make_move',
                ['11', '2']
              )
            end, :empty}
       }},
       {:responder,
       %{
         fuzzy: 10,
         message: {:channels_update, 9, :self, "channels.update"},
         next:
           {:sync,
            fn pid, from ->
              SocketConnector.get_contract_reponse(
                pid,
                initiator_contract,
                'make_move',
                from
              )
            end, :empty}
       }},
       {:responder,
       %{
         next: sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         next: sequence_finish_job(runner_pid, initiator)
       }}
    ]
  end

  def reconnect_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_999},
             {responder_account, 4_000_000_000_001}
           ),
         fuzzy: 10
       }},
      {:initiator,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty}
       }},
      {:initiator,
       %{
         message: {:channels_update, 3, :other, "channels.update"},
         fuzzy: 10,
         next: sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_update, 2, :other, "channels.update"},
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_997},
             {responder_account, 4_000_000_000_003}
           ),
         fuzzy: 10
       }},
      {:responder,
       %{
         #  message: {:channels_update, 1, :transient, "channels.update"},
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.close_connection(pid_session_holder)
              resume_runner(client_runner)
            end, :empty},
         fuzzy: 10
       }},
      {:responder, %{next: pause_job(1000)}},
      {:responder,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder)
              resume_runner(client_runner)
            end, :empty},
         fuzzy: 0
       }},
      {:responder,
       %{
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_997},
             {responder_account, 4_000_000_000_003}
           ),
         fuzzy: 10
       }},
      {:responder,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty}
       }},
      {:responder,
       %{
         next:
           assert_funds_job(
             {intiator_account, 6_999_999_999_999},
             {responder_account, 4_000_000_000_001}
           ),
         fuzzy: 10
       }},
      {:responder,
       %{
         next: sequence_finish_job(runner_pid, responder)
       }}
    ]

  def close_solo_job() do
    # special cased since this doesn't end up in an update.
    close_solo = fn pid -> SocketConnector.close_solo(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, close_solo)

       spawn(fn ->
         Process.sleep(2000)
         resume_runner(client_runner)
       end)
     end, :empty}
  end

  def close_mutual_job() do
    # special cased since this doesn't end up in an update.
    shutdown = fn pid -> SocketConnector.shutdown(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, shutdown)

       spawn(fn ->
         Process.sleep(2000)
         resume_runner(client_runner)
       end)
     end, :empty}
  end

  def just_connect({initiator, _intiator_account}, {responder, _responder_account}, runner_pid) do
    jobs_initiator = [
      {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
      sequence_finish_job(runner_pid, initiator)
    ]

    jobs_responder = [
      sequence_finish_job(runner_pid, responder)
    ]

    {jobs_initiator, jobs_responder}
  end

  def close_solo_v2({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
         fuzzy: 8
       }},
      {:initiator,
       %{
         message: {:channels_update, 2, :self, "channels.update"},
         next: close_solo_job(),
         fuzzy: 8
       }},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "closing"},
         fuzzy: 10,
         next: sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_info, 0, :transient, "closing"},
         fuzzy: 10,
         next: sequence_finish_job(runner_pid, responder)
       }}
    ]

  def close_mutual_v2({initiator, _intiator_account}, {responder, _responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
         fuzzy: 8
       }},
      #  get poi is done under the hood, but this call tests additional code
      {:initiator,
       %{
         message: {:channels_update, 2, :self, "channels.update"},
         next: {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
         fuzzy: 8
       }},
      {:initiator,
       %{
         #  message: {:channels_update, 2, :self, "channels.update"},
         next: close_mutual_job(),
         fuzzy: 8
       }},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "closed_confirmed"},
         fuzzy: 10,
         next: sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_info, 0, :transient, "closed_confirmed"},
         fuzzy: 14,
         next: sequence_finish_job(runner_pid, responder)
       }}
    ]

  def gen_name(name, suffix) do
    String.to_atom(to_string(name) <> Integer.to_string(suffix))
  end

  # elimiation overlap yields issues, need to be investigated
  @grace_period_ms 2000

  def start_helper(ae_url, network_id) do
    Enum.each(Enum.zip(joblist(), 1..Enum.count(joblist())), fn {fun, suffix} ->
      Logger.info("Launching next job in queue")
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

        Logger.debug("Received message from runner: #{inspect(name)} remaining: #{inspect(reduced_list)}")

        await_finish(reduced_list)
    end
  end

  def custom_connection_setting(role, _host_url) do
    same = %{
      channel_reserve: "2",
      lock_period: "10",
      port: "1500",
      protocol: "json-rpc",
      push_amount: "1",
      minimum_depth: 0,
      role: role
    }

    role_map =
      case role do
        :initiator ->
          # %URI{host: host} = URI.parse(host_url)
          # TODO Worksound to be able to connect to testnet
          # %{host: host, role: "initiator"}
          %{host: "localhost"}

        _ ->
          %{}
      end

    Map.merge(same, role_map)
  end

  def default_configuration(initiator_pub, responder_pub) do
    %{
      basic_configuration: %SocketConnector.WsConnection{
        initiator_id: initiator_pub,
        initiator_amount: 7_000_000_000_000,
        responder_id: responder_pub,
        responder_amount: 4_000_000_000_000
      },
      custom_param_fun: &custom_connection_setting/2
    }
  end

  def start_helper(
        ae_url,
        network_id,
        name_initiator,
        name_responder,
        job_builder,
        configuration \\ &default_configuration/2
      ) do
    initiator_pub = TestAccounts.initiatorPubkeyEncoded()
    responder_pub = TestAccounts.responderPubkeyEncoded()

    Logger.debug("executing test: #{inspect(job_builder)}")

    {jobs_initiator, jobs_responder} =
      seperate_jobs(job_builder.({name_initiator, initiator_pub}, {name_responder, responder_pub}, self()))

    state_channel_configuration = configuration.(initiator_pub, responder_pub)

    start_link(
      {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey(), state_channel_configuration, ae_url,
       network_id, :initiator, jobs_initiator, :yellow, name_initiator}
    )

    start_link(
      {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey(), state_channel_configuration, ae_url,
       network_id, :responder, jobs_responder, :blue, name_responder}
    )

    await_finish([name_initiator, name_responder])
  end
end
