defmodule SocketConnectorTest do
  use ExUnit.Case
  require Logger
  # require ClientRunner

  # Code.require_file "client_runner.ex", __DIR__

  def gen_names(id) do
    clean_id = Atom.to_string(id)
    {String.to_atom("alice " <> clean_id), String.to_atom("bob " <> clean_id)}
  end

  def accounts_initiator() do
    {TestAccounts.initiatorPubkeyEncoded(), TestAccounts.initiatorPrivkey()}
  end

  def accounts_responder() do
    {TestAccounts.responderPubkeyEncoded(), TestAccounts.responderPrivkey()}
  end

  @tag :override
  test "override basic params" do
    expect_default = %{
      basic_configuration: %SocketConnector.WsConnection{
        initiator_amount: 7000000000000,
        initiator_id: "hej",
        responder_amount: 4000000000000,
        responder_id: "hopp"
      }
    }
    assert expect_default.basic_configuration == SessionHolderHelper.custom_config(%{}, %{}).("hej", "hopp").basic_configuration
    expect = %{
      basic_configuration: %SocketConnector.WsConnection{
        initiator_amount: 7000000000000,
        initiator_id: "hej",
        responder_amount: 23,
        responder_id: "hopp"
      }
    }
    assert expect.basic_configuration == SessionHolderHelper.custom_config(%{responder_amount: 23}, %{}).("hej", "hopp").basic_configuration
  end

  @tag :hello_world
  test "hello fsm", context do
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
           next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty},
           fuzzy: 3
         }},
        {:responder, %{message: {:channels_info, 0, :transient, "open"}}},
        {:responder, %{message: {:channels_update, 1, :other, "channels.update"}}},
        # end of opening sequence
        # leaving
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

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1400})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  @tag :hello_world_mini
  test "hello fsm mini", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1401})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # @tag :ignore
  @tag :abort
  test "abort transfer", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:sign_approve, 1, "channels.sign.initiator_sign"},
           fuzzy: 10
         }},
        {:responder,
         %{
           message: {:sign_approve, 1, "channels.sign.responder_sign"},
           fuzzy: 10
         }},
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
           fuzzy: 10
         }},
        {:initiator,
         %{
           message: {:sign_approve, 2, "channels.sign.update"},
           fuzzy: 10,
           sign: {:abort, 555}
         }},
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "aborted_update"},
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
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1402})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # this test works locally again and again, but temporary removed for circle ci
  @tag :ignore
  @tag :close_on_chain
  test "close on chain", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
           fuzzy: 9
         }},
        {:initiator,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           next: {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
           fuzzy: 5
         }},
        {:initiator,
         %{
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                nonce = ChannelService.OnChain.nonce(SessionHolderHelper.ae_url(), intiator_account)
                height = ChannelService.OnChain.current_height(SessionHolderHelper.ae_url())
                Logger.debug("nonce is #{inspect(nonce)} height is: #{inspect(height)}")

                transaction = SessionHolder.solo_close_transaction(pid_session_holder, 2, nonce + 1, height)

                ChannelService.OnChain.post_solo_close(SessionHolderHelper.ae_url(), transaction)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:initiator,
         %{
           message: {:on_chain, 0, :transient, "solo_closing"},
           fuzzy: 10,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           message: {:on_chain, 0, :transient, "solo_closing"},
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1403})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # this test works locally again and again, but temporary removed for circle ci
  @tag :ignore
  @tag :close_on_chain_mal
  test "close on chain maliscous", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
           fuzzy: 9
         }},
        {:initiator,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           next: {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
           fuzzy: 5
         }},
        {:initiator,
         %{
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 7) end, :empty},
           fuzzy: 9
         }},
        {:initiator,
         %{
           message: {:channels_update, 3, :self, "channels.update"},
           next: {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
           fuzzy: 5
         }},
        {:initiator,
         %{
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                nonce = ChannelService.OnChain.nonce(SessionHolderHelper.ae_url(),intiator_account)
                height = ChannelService.OnChain.current_height(SessionHolderHelper.ae_url())

                transaction =
                  GenServer.call(
                    pid_session_holder,
                    {:solo_close_transaction, 2, nonce + 1, height}
                  )

                ChannelService.OnChain.post_solo_close(SessionHolderHelper.ae_url(), transaction)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:initiator,
         %{
           message: {:on_chain, 0, :transient, "can_slash"},
           fuzzy: 10,
           next: {:sync, fn pid, from -> SocketConnector.slash(pid, from) end, :empty}
           #  next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           message: {:on_chain, 0, :transient, "can_slash"},
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }},
        {:initiator,
         %{
           message: {:on_chain, 0, :transient, "solo_closing"},
           fuzzy: 5,
           next: {:async, fn pid -> SocketConnector.settle(pid) end, :empty}
           #  next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
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
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1404})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  @tag :reestablish
  test "withdraw after re-establish", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
                SessionHolder.reestablish(pid_session_holder, 1510)
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
        {:initiator,
         %{
           message: {:sign_approve, 2, "channels.sign.withdraw_tx"},
           fuzzy: 20,
           sign: {:check_poi},
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           message: {:channels_update, 2, :other, "channels.update"},
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }},
        {:initiator,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1405})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # test "withdraw after reestablish", context do
  #   {alice, bob} = gen_names(context.test)

  #   ClientRunner.start_peers(
  #     SessionHolderHelper.ae_url(),
  #     SessionHolderHelper.network_id(),
  #     %{
      #   initiator: %{name: alice, keypair: accounts_initiator()},
      #   responder: %{name: bob, keypair: accounts_responder()}
      # },
  #     &TestScenarios.withdraw_after_reestablish_v2/3
  #   )
  # end

  @tag :backchannel
  test "backchannel jobs", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "open"},
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.close_connection(pid_session_holder)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty},
           fuzzy: 20
         }},
        #  grace time to make sure that initiator is gone
        {:responder,
         %{
           message: {:channels_update, 1, :other, "channels.update"},
           next: ClientRunnerHelper.pause_job(3000),
           fuzzy: 10
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
         %{
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 2) end, :empty}
         }},
        {:responder,
         %{
           message: {:channels_update, 2, :self, "channels.conflict"},
           fuzzy: 5,
           next:
             {:async,
              fn pid ->
                SocketConnector.initiate_transfer(pid, 4)
              end, :empty}
         }},
        # lets do some backchannel signing
        {:responder,
         %{
           message: {:sign_approve, 2, "channels.sign.update"},
           fuzzy: 2,
           sign: {:backchannel, initiator}
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
                SessionHolder.reestablish(pid_session_holder, 1233)
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
    end

    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator()},
        responder: %{name: bob, keypair: accounts_responder()}
      },
      scenario
    )
  end

  def close_solo_job() do
    # special cased since this doesn't end up in an update.
    close_solo = fn pid -> SocketConnector.close_solo(pid) end

    {:local,
     fn client_runner, pid_session_holder ->
       SessionHolder.run_action(pid_session_holder, close_solo)
       ClientRunnerHelper.resume_runner(client_runner)
     end, :empty}
  end

  @tag :close_solo
  # @tag timeout: 60000 * 10
  test "close solo", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
           fuzzy: 9
         }},
        {:initiator,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           next: close_solo_job(),
           fuzzy: 9
         }},
        {:initiator,
         %{
           message: {:channels_info, 0, :transient, "closing"},
           fuzzy: 15,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           message: {:channels_info, 0, :transient, "closing"},
           fuzzy: 15,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1406})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  @tag :close_mut
  test "close mutual", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, _intiator_account}, {responder, _responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
           fuzzy: 9
         }},
        #  get poi is done under the hood, but this call tests additional code
        {:initiator,
         %{
           message: {:channels_update, 2, :self, "channels.update"},
           next: {:sync, fn pid, from -> SocketConnector.get_poi(pid, from) end, :empty},
           fuzzy: 9
         }},
        {:initiator,
         %{
           next: {:async, fn pid -> SocketConnector.shutdown(pid) end, :empty}
         }},
        {:initiator,
         %{
           message: {:sign_approve, 0, "channels.sign.shutdown_sign"},
           sign: {:check_poi}
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
           fuzzy: 20,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator()},
        responder: %{name: bob, keypair: accounts_responder()}
      },
      scenario
    )
  end

  test "reestablish jobs 2", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
           fuzzy: 15
         }},
        {:responder,
         %{
           #  message: {:channels_update, 1, :self, "channels.update"},
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.close_connection(pid_session_holder)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:responder, %{next: ClientRunnerHelper.pause_job(1000)}},
        {:responder,
         %{
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.reestablish(pid_session_holder, 1602)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:responder,
         %{
           next:
             ClientRunnerHelper.assert_funds_job(
               {intiator_account, 6_999_999_999_997},
               {responder_account, 4_000_000_000_003}
             )
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
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1407})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # relocate contact files to get this working.
  @tag :contract_exp
  test "contract jobs experiment", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "../../contracts/tictactoe.aes", %{abi_version: 3, vm_version: 5, backend: :fate}}

      # correct path if started in shell...
      # initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
        {:initiator,
         %{
           # initiator have put 10 in the contract
           next: {:async, fn pid -> SocketConnector.new_contract(pid, initiator_contract, 10) end, :empty}
         }},
        {:responder,
         %{
           fuzzy: 20,
           message: {:channels_update, 3, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                # responder add 10 (same) in the contract
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'join',
                  ['true'],
                  10
                )
              end, :empty}
         }},
        {:responder,
         %{
           fuzzy: 10,
           message: {:channels_update, 4, :self, "channels.update"},
           next:
             {:sync,
              fn pid, from ->
                SocketConnector.get_contract_reponse(
                  pid,
                  initiator_contract,
                  'join',
                  from
                )
              end,
              fn a ->
                assert a == {:ok, {:tuple, [], []}}
              end}
         }},
        {:responder,
         %{
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['2', '2']
                )
              end, :empty}
         }},
        {:responder,
         %{
           fuzzy: 10,
           message: {:channels_update, 5, :self, "channels.update"},
           next:
             {:sync,
              fn pid, from ->
                SocketConnector.get_contract_reponse(
                  pid,
                  initiator_contract,
                  'move',
                  from
                )
              end,
              fn a ->
                assert a == {:ok, {:bool, [], false}}
              end}
         }},
        {:initiator,
         %{
           fuzzy: 10,
           message: {:channels_update, 5, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['1', '1']
                )
              end, :empty}
         }},
        {:initiator,
         %{
           fuzzy: 10,
           message: {:channels_update, 6, :self, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['1', '2']
                )
              end, :empty}
         }},
        {:initiator,
         %{
           fuzzy: 10,
           message: {:channels_update, 7, :self, "channels.update"},
           next:
             {:sync,
              fn pid, from ->
                SocketConnector.get_contract_reponse(
                  pid,
                  initiator_contract,
                  'move',
                  from
                )
              end,
              fn a ->
                # TODO, parse "not your turn" from error message
                assert elem(a, 0) == :error
              end}
         }},
        {:responder,
         %{
           fuzzy: 20,
           message: {:channels_update, 7, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['1', '2']
                )
              end, :empty}
         }},
        {:initiator,
         %{
           fuzzy: 10,
           message: {:channels_update, 8, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['0', '2']
                )
              end, :empty}
         }},
        {:responder,
         %{
           fuzzy: 20,
           message: {:channels_update, 9, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['2', '1']
                )
              end, :empty}
         }},
        {:initiator,
         %{
           next:
             ClientRunnerHelper.assert_funds_job(
               #  initiator have put 10 in the contract
               {intiator_account, 6_999_999_999_987},
               {responder_account, 3_999_999_999_993}
             )
         }},
        {:initiator,
         %{
           # This is the winning move
           fuzzy: 10,
           message: {:channels_update, 10, :other, "channels.update"},
           next:
             {:async,
              fn pid ->
                SocketConnector.call_contract(
                  pid,
                  initiator_contract,
                  'move',
                  ['2', '0']
                )
              end, :empty}
         }},
        {:initiator,
         %{
           fuzzy: 10,
           message: {:channels_update, 11, :self, "channels.update"},
           next:
             {:sync,
              fn pid, from ->
                SocketConnector.get_contract_reponse(
                  pid,
                  initiator_contract,
                  'move',
                  from
                )
              end,
              fn a ->
                # we have a winner!
                assert a == {:ok, {:bool, [], true}}
              end}
         }},
        {:initiator,
         %{
           # initiator wins the total amount of credits, since he won.
           next:
             ClientRunnerHelper.assert_funds_job(
               {intiator_account, 7_000_000_000_007},
               {responder_account, 3_999_999_999_993}
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
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1408})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )

  end

  @tag :contract
  test "contract jobs", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "../../contracts/TicTacToe_old.aes", %{abi_version: 1, vm_version: 3, backend: :aevm}}

      # correct path if started in shell...
      # initiator_contract = {TestAccounts.initiatorPubkeyEncoded(), "contracts/TicTacToe.aes"}
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
        {:initiator,
         %{
           next: {:async, fn pid -> SocketConnector.new_contract(pid, initiator_contract, 10) end, :empty}
         }},
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
              end,
              fn a ->
                assert a == {:ok, {:string, [], "Game continues. The other player's turn."}}
              end}
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
               #  reduce by 10 + 3, 10 deposit in contract
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
           message: {:channels_update, 6, :self, "channels.update"},
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
           message: {:channels_update, 8, :self, "channels.update"},
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
           message: {:channels_update, 8, :other, "channels.update"},
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
              end, fn a -> assert a == {:ok, {:string, [], "Place is already taken!"}} end}
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

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1408})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  @tag :reestablish
  test "reestablish jobs", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           message: {:channels_update, 1, :self, "channels.update"},
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
        {:initiator,
         %{
           # message: {:channels_update, 1, :self, "channels.update"},
           next: {:async, fn pid -> SocketConnector.leave(pid) end, :empty}
           # fuzzy: 3
         }},
        {:initiator,
         %{
           fuzzy: 20,
           message: {:channels_info, 0, :transient, "died"},
           next: ClientRunnerHelper.pause_job(300)
         }},
        {:initiator,
         %{
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.reestablish(pid_session_holder, 1501)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:responder,
         %{
           fuzzy: 20,
           # :channels_info, 0, :transient, "peer_disconnected"
           message: {:channels_update, 2, :transient, "channels.leave"},
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.kill_connection(pid_session_holder)
                SessionHolder.reestablish(pid_session_holder, 1501)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:responder, %{next: ClientRunnerHelper.pause_job(1000)}},
        {:responder,
         %{
           fuzzy: 3,
           next:
             ClientRunnerHelper.assert_funds_job(
               {intiator_account, 6_999_999_999_997},
               {responder_account, 4_000_000_000_003}
             )
         }},
        # reestablish without leave
        {:responder,
         %{
           next:
             {:local,
              fn client_runner, pid_session_holder ->
                SessionHolder.kill_connection(pid_session_holder)
                SessionHolder.reestablish(pid_session_holder, 1501)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        {:responder,
         %{
           next:
             ClientRunnerHelper.assert_funds_job(
               {intiator_account, 6_999_999_999_997},
               {responder_account, 4_000_000_000_003}
             )
         }},
        {:initiator,
         %{
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 0, port: 1408})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator()},
        responder: %{name: bob, keypair: accounts_responder()}
      },
      scenario
    )
  end

  # test "query after reconnect", context do
  #   {alice, bob} = gen_names(context.test)

  #   ClientRunner.start_peers(
  #     SessionHolderHelper.ae_url(),
  #     SessionHolderHelper.network_id(),
  #     %{
      #   initiator: %{name: alice, keypair: accounts_initiator()},
      #   responder: %{name: bob, keypair: accounts_responder()}
      # },
  #     &TestScenarios.query_after_reconnect_v2/3
  #   )
  # end

  @tag :open_channel_passive
  # this scenario does not work on circle ci. needs to be investigated
  test "teardown on channel creation", context do
    {alice, bob} = gen_names(context.test)

    scenario = fn {initiator, intiator_account}, {responder, responder_account}, runner_pid ->
      [
        {:initiator,
         %{
           # worked before
           # message: {:channels_info, 0, :transient, "funding_signed"},
           # should work now
           message: {:channels_info, 0, :transient, "own_funding_locked"},
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
                SessionHolder.reestablish(pid_session_holder, 1501)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
         }},
        # currently no message is received on reconnect.
        # to eager fething causes timeout due to missing response.
        {:initiator, %{next: ClientRunnerHelper.pause_job(1000)}},
        {:initiator,
         %{
           fuzzy: 3,
           next:
             ClientRunnerHelper.assert_funds_job(
               {intiator_account, 6_999_999_999_999},
               {responder_account, 4_000_000_000_001}
             )
         }},
        {:initiator,
         %{
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
         }},
        {:responder,
         %{
           message: {:channels_update, 1, :other, "channels.update"},
           fuzzy: 14,
           next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
         }}
      ]
    end

    channel_config = SessionHolderHelper.custom_config(%{}, %{minimum_depth: 50, port: 1409})
    ClientRunner.start_peers(
      SessionHolderHelper.ae_url(),
      SessionHolderHelper.network_id(),
      %{
        initiator: %{name: alice, keypair: accounts_initiator(), custom_configuration: channel_config},
        responder: %{name: bob, keypair: accounts_responder(), custom_configuration: channel_config}
      },
      scenario
    )
  end

  # scenario = fn {initiator, intiator_account}, {responder, _responder_account}, runner_pid ->
  #   []
  # end
end
