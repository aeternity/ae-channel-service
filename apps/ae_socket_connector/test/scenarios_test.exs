defmodule TestScenarios do
  # import ClientRunnerHelper

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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }},
      {:initiator, %{message: {:channels_update, 1, :transient, "channels.leave"}, fuzzy: 0}},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "died"},
         fuzzy: 0,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "died"},
         fuzzy: 20,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
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
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty},
         fuzzy: 10
       }},
      {:initiator, %{next: ClientRunnerHelper.pause_job(1000)}},
      {:initiator,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder, 12345)
              ClientRunnerHelper.resume_runner(client_runner)
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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         message: {:channels_update, 2, :transient, "channels.update"},
         fuzzy: 20,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
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
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty},
         fuzzy: 20
       }},
      {:responder,
       %{
         next:
           ClientRunnerHelper.assert_funds_job(
             {intiator_account, 6_999_999_999_999},
             {responder_account, 4_000_000_000_001}
           )
       }},
      {:responder,
       %{message: {:channels_update, 1, :transient, "channels.update"}, next: ClientRunnerHelper.pause_job(3000), fuzzy: 10}},
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
         message: {:channels_update, 2, :self, "channels.update"},
         fuzzy: 3,
         next:
           ClientRunnerHelper.assert_funds_job(
             {intiator_account, 7_000_000_000_003},
             {responder_account, 3_999_999_999_997}
           )
       }},
      {:responder,
       %{
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty}
       }},
      {:initiator, %{next: ClientRunnerHelper.pause_job(10000)}},
      {:initiator,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder, 1233)
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty}
       }},
      {:initiator,
       %{
         next:
           ClientRunnerHelper.assert_funds_job(
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
         message: {:channels_update, 3, :self, "channels.update"},
         fuzzy: 3,
         next:
           ClientRunnerHelper.assert_funds_job(
             {intiator_account, 6_999_999_999_998},
             {responder_account, 4_000_000_000_002}
           )
       }},
      {:responder,
       %{
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }}
    ]

  def contract_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid) do
    initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "../../contracts/TicTacToe.aes"}
    # correct path if started in shell...
    # initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}

    [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty},
         fuzzy: 10
       }},
      {:initiator,
       %{
         message: {:channels_update, 2, :self, "channels.update"},
         fuzzy: 3,
         next:
           ClientRunnerHelper.assert_funds_job(
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
           ClientRunnerHelper.assert_funds_job(
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
           ClientRunnerHelper.assert_funds_job(
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
           ClientRunnerHelper.assert_funds_job(
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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }},
      {:initiator,
       %{
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }}
    ]
  end

  def reconnect_jobs_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_update, 1, :transient, "channels.update"},
         next:
           ClientRunnerHelper.assert_funds_job(
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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_update, 2, :other, "channels.update"},
         next:
           ClientRunnerHelper.assert_funds_job(
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
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty},
         fuzzy: 10
       }},
      {:responder, %{next: ClientRunnerHelper.pause_job(1000)}},
      {:responder,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reconnect(pid_session_holder)
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty},
         fuzzy: 0
       }},
      {:responder,
       %{
         next:
           ClientRunnerHelper.assert_funds_job(
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
         message: {:channels_update, 3, :self, "channels.update"},
         next:
           ClientRunnerHelper.assert_funds_job(
             {intiator_account, 6_999_999_999_999},
             {responder_account, 4_000_000_000_001}
           ),
         fuzzy: 10
       }},
      {:responder,
       %{
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }}
    ]

  def close_solo_job() do
    # special cased since this doesn't end up in an update.
    close_solo = fn pid -> SocketConnector.close_solo(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, close_solo)
       ClientRunnerHelper.resume_runner(client_runner)
     end, :empty}
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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_info, 0, :transient, "closing"},
         fuzzy: 10,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }}
    ]

  def close_mutual_job() do
    # special cased since this doesn't end up in an update.
    shutdown = fn pid -> SocketConnector.shutdown(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, shutdown)
       ClientRunnerHelper.resume_runner(client_runner)
     end, :empty}
  end

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
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_info, 0, :transient, "closed_confirmed"},
         fuzzy: 14,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }}
    ]

  def teardown_on_channel_creation_v2({initiator, intiator_account}, {responder, responder_account}, runner_pid),
    do: [
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "funding_signed"},
         fuzzy: 10,
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.close_connection(pid_session_holder)
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty}
       }},
      {:initiator, %{next: ClientRunnerHelper.pause_job(10000)}},
      {:initiator,
       %{
         next:
           {:local,
            fn client_runner, pid_session_holder ->
              SessionHolder.reestablish(pid_session_holder, 12343)
              ClientRunnerHelper.resume_runner(client_runner)
            end, :empty}
       }},
      {:initiator,
       %{
         message: {:channels_update, 2, :self, "channels.update"},
         fuzzy: 3,
         next:
           ClientRunnerHelper.assert_funds_job(
             {intiator_account, 6_999_999_999_997},
             {responder_account, 4_000_000_000_003}
           )
       }},
      {:initiator,
       %{
         message: {:channels_info, 0, :transient, "open"},
         fuzzy: 10,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
       }},
      {:responder,
       %{
         message: {:channels_info, 0, :transient, "open"},
         fuzzy: 14,
         next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
       }}
    ]

  # def just_connect({initiator, _intiator_account}, {responder, _responder_account}, runner_pid) do
  #   jobs_initiator = [
  #     {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
  #     ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
  #   ]

  #   jobs_responder = [
  #     ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
  #   ]

  #   {jobs_initiator, jobs_responder}
  # end
end
