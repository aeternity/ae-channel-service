ExUnit.start
ExUnit.configure seed: 0

defmodule ReuseChannelTest do
   # run test consecutive

  use ExUnit.Case
  require ClientRunner
  require Logger

  @ae_url ClientRunner.ae_url()
  @network_id ClientRunner.network_id()

  def gen_names(id) do
    clean_id = Atom.to_string(id)
    {String.to_atom("alice " <> clean_id), String.to_atom("bob " <> clean_id)}
  end

  def custom_config(overide_basic_param, override_custom) do
    fn initator_pub, responder_pub ->
      %{basic_configuration: basic_configuration} =
        Map.merge(
          ClientRunner.default_configuration(initator_pub, responder_pub),
          overide_basic_param
        )

      %{
        basic_configuration: basic_configuration,
        custom_param_fun: fn role, host_url ->
          Map.merge(ClientRunner.custom_connection_setting(role, host_url), override_custom)
        end
      }
    end
  end

  def accounts_initiator() do
    {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey()}
  end

  def accounts_responder() do
    {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey()}
  end

  def clean_log_config_file(log_config) do
    File.rm(Path.join(log_config.log_path, log_config.log_file))
  end

  def name_test(context, suffix) do
    %{context | test: String.to_atom(Atom.to_string(context.test) <> suffix)}
  end

  @tag :dets
  test "reestablish using dets", context do
    testname = Atom.to_string(context.test)

    hello_fsm_part_1of2(name_test(context, "_1"))
    hello_fsm_part_2of2_auto_reestablish(name_test(context, "_2"))
  end

  def hello_fsm_part_1of2(context) do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        # opening channel
        # re-add once the node is updated to use password
        # {:responder, %{message: {:channels_info, 0, :transient, "fsm_up"}}},
        {:responder, %{fuzzy: 1, message: {:channels_info, 0, :transient, "channel_open"}}},
        # re-add once the node is updated to use password
        # {:initiator, %{message: {:channels_info, 0, :transient, "fsm_up"}}},
        {:initiator, %{fuzzy: 1, message: {:channels_info, 0, :transient, "channel_accept"}}},
        {:initiator, %{message: {:sign_approve, 1, "channels.sign.initiator_sign"}}},
        {:responder, %{message: {:channels_info, 0, :transient, "funding_created"}}},
        {:responder, %{message: {:sign_approve, 1, "channels.sign.responder_sign"}}},
        {:responder, %{message: {:on_chain, 0, :transient, "funding_created"}}},
        {:initiator, %{message: {:channels_info, 0, :transient, "funding_signed"}}},
        {:initiator, %{message: {:on_chain, 0, :transient, "funding_signed"}}},
        # {:responder, %{message: {:on_chain, 0, :transient, "channel_changed"}}},
        {:responder, %{fuzzy: 1, message: {:channels_info, 0, :transient, "own_funding_locked"}}},
        # {:initiator, %{message: {:on_chain, 0, :transient, "channel_changed"}}},
        {:initiator, %{fuzzy: 1, message: {:channels_info, 0, :transient, "own_funding_locked"}}},
        {:initiator, %{fuzzy: 1, message: {:channels_info, 0, :transient, "funding_locked"}}},
        {:responder, %{fuzzy: 1, message: {:channels_info, 0, :transient, "funding_locked"}}},
        {:initiator, %{message: {:channels_info, 0, :transient, "open"}}},
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           #  next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.close_connection(pid_session_holder)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty},
           #  next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator),
           fuzzy: 3
         }},
        {:responder, %{message: {:channels_info, 0, :transient, "open"}}},
        {:responder,
         %{
           message: {:channels_update, 1, :other, "channels.update"},
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.close_connection(pid_session_holder)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty},
           #  next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder),
           fuzzy: 3
         }},
        {:responder,
         %{
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }},
        {:initiator,
         %{
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }}
        # # end of opening sequence
        # # leaving
        # {:responder,
        #  %{
        #    message: {:channels_update, 1, :transient, "channels.leave"},
        #    fuzzy: 1,
        #    next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
        #  }},
        # {:initiator, %{message: {:channels_update, 1, :transient, "channels.leave"}, fuzzy: 1}},
        # {:initiator,
        #  %{
        #    message: {:channels_info, 0, :transient, "died"},
        #    fuzzy: 0,
        #    next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
        #  }}
      ]
    end

    log_config_initiator = %{log_file: "consecutive_initiator", log_path: "log"}
    clean_log_config_file(log_config_initiator)
    log_config_responder = %{log_file: "consecutive_responder", log_path: "log"}
    clean_log_config_file(log_config_responder)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator(), log_config_initiator},
      {bob, accounts_responder(), log_config_responder},
      scenario,
      custom_config(%{}, %{minimum_depth: 0, port: 1400})
    )
  end

  def hello_fsm_part_2of2_auto_reestablish(context) do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        # end of opening sequence
        # leaving
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "fsm_up"},
           next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty}
         }},
        {:responder,
         %{
           message: {:channels_info, 0, :transient, "fsm_up"}
         }},
        {:responder,
         %{
           message: {:channels_update, 1, :transient, "channels.leave"},
           fuzzy: 1,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }},
        {:initiator, %{message: {:channels_update, 1, :transient, "channels.leave"}, fuzzy: 1}},
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "died"},
           fuzzy: 0,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }}
        # {:initiator,
        #  %{
        #    message: {:channels_info, 0, :transient, "channel_reestablished"},
        #    next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
        #    fuzzy: 10
        #  }},
        # {:responder,
        #  %{
        #    message: {:channels_update, 1, :transient, "channels.leave"},
        #    fuzzy: 20,
        #    next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
        #  }},
        # {:initiator,
        #  %{
        #    message: {:channels_info, 0, :transient, "died"},
        #    fuzzy: 20,
        #    next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
        #  }}
      ]
    end

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator(), %{log_file: "consecutive_initiator", log_path: "log"}},
      {bob, accounts_responder(), %{log_file: "consecutive_responder", log_path: "log"}},
      scenario,
      custom_config(%{}, %{minimum_depth: 0, port: 1401})
    )
  end
end
