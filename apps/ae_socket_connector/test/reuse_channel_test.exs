defmodule ReuseChannelTest do

  use ExUnit.Case
  require Logger

  def clean_log_config_file(log_config) do
    File.rm(Path.join(log_config.path, log_config.file))
  end

  def name_test(context, suffix) do
    %{context | test: String.to_atom(Atom.to_string(context.test) <> suffix)}
  end

  @tag :dets
  @tag :ignore # We need to modfiy be creative to provide reconnect information in some clever whay, where we save the fsm_id from the first run
  test "reestablish using dets", context do
    hello_fsm_part_1of2(name_test(context, "_1"))
    hello_fsm_part_2of2_auto_reestablish(name_test(context, "_2"))
  end

  def hello_fsm_part_1of2(context) do
    {alice, bob} = SocketConnectorTest.gen_names(context.test)

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

    log_config_initiator = %{file: "consecutive_initiator", path: "data"}
    clean_log_config_file(log_config_initiator)
    log_config_responder = %{file: "consecutive_responder", path: "data"}
    clean_log_config_file(log_config_responder)

    ClientRunner.start_peers(
      SocketConnectorHelper.ae_url(),
      SockerConnectorHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: SocketConnectorTest.accounts_initiator(), log_config: %{file: "consecutive_initiator", path: "data"}},
        responder: %{name: bob, keypair: SocketConnectorTest.accounts_responder(), log_config: %{file: "consecutive_responder", path: "data"}}
      },
      scenario
    )
  end

  def hello_fsm_part_2of2_auto_reestablish(context) do
    {alice, bob} = SocketConnectorTest.gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "fsm_up"},
           next: ClientRunnerHelper.pause_job(1000)
         }},
        {:initiator,
         %{
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
      ]
    end

    ClientRunner.start_peers(
      SocketConnectorHelper.ae_url(),
      SockerConnectorHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: SocketConnectorTest.accounts_initiator(), log_config: %{file: "consecutive_initiator", path: "data"}},
        responder: %{name: bob, keypair: SocketConnectorTest.accounts_responder(), log_config: %{file: "consecutive_responder", path: "data"}}
      },
      scenario
    )
  end
end
