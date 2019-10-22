defmodule SocketConnectorTest do
  use ExUnit.Case
  require ClientRunner

  @ae_url ClientRunner.ae_url()
  @network_id ClientRunner.network_id()

  def gen_names(id) do
    clean_id = Atom.to_string(id)
    {String.to_atom("alice " <> clean_id), String.to_atom("bob " <> clean_id)}
  end

  def custom_config(overide_basic_param, override_custom) do
    fn initator_pub, responder_pub ->
      %{basic_configuration: basic_configuration} =
        Map.merge(ClientRunner.default_configuration(initator_pub, responder_pub), overide_basic_param)

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

  @tag :hello_world
  test "hello fsm", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.hello_fsm_v2/3,
      custom_config(%{}, %{minimum_depth: 0, port: 1400})
    )
  end

  @tag :close_on_chain
  test "close on chain", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.close_on_chain_v2/3,
      custom_config(%{}, %{minimum_depth: 0, port: 1400})
    )
  end

  @tag :close_on_chain_mal
  test "close on chain maliscous", context do
    {alice, bob} = gen_names(context.test)


    scenario = fn ({initiator, intiator_account}, {responder, _responder_account}, runner_pid) ->
      [
        {:initiator,
        %{
          message: {:channels_update, 1, :transient, "channels.update"},
          next: {:async, fn pid -> SocketConnector.initiate_transfer(pid, 5) end, :empty},
          fuzzy: 8
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
          fuzzy: 8
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
                nonce = OnChain.nonce(intiator_account)
                height = OnChain.current_height()
                transaction = GenServer.call(pid_session_holder, {:solo_close_transaction, 2, nonce + 1, height})
                OnChain.post_solo_close(transaction)
                ClientRunnerHelper.resume_runner(client_runner)
              end, :empty}
        }},
        {:initiator,
        %{
          message: {:on_chain, 0, :transient, "can_slash"},
          fuzzy: 10,
          next: {:sync, fn pid, from -> SocketConnector.slash(pid, from) end, :empty},
          #  next: ClientRunnerHelper.sequence_finish_job(runner_pid, initiator)
        }},
        {:responder,
        %{
          message: {:on_chain, 0, :transient, "can_slash"},
          fuzzy: 20,
          next: ClientRunnerHelper.sequence_finish_job(runner_pid, responder)
        }}
      ] end

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      scenario,
      custom_config(%{}, %{minimum_depth: 0, port: 1400})
    )
  end

  @tag :reconnect
  test "withdraw after re-connect", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.withdraw_after_reconnect_v2/3
    )
  end

  # test "withdraw after reestablish", context do
  #   {alice, bob} = gen_names(context.test)

  #   ClientRunner.start_peers(
  #     @ae_url,
  #     @network_id,
  #     {alice, accounts_initiator()},
  #     {bob, accounts_responder()},
  #     &TestScenarios.withdraw_after_reestablish_v2/3
  #   )
  # end

  test "backchannel jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.backchannel_jobs_v2/3
    )
  end

  @tag :close
  test "close solo", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.close_solo_v2/3
    )
  end

  @tag :close
  test "close mutual", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.close_mutual_v2/3
    )
  end

  test "reconnect jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.reconnect_jobs_v2/3
    )
  end

  # relocate contact files to get this working.
  @tag :contract
  test "contract jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.contract_jobs_v2/3
    )
  end

  # test "reestablish jobs", context do
  #   {alice, bob} = gen_names(context.test)

  #   ClientRunner.start_peers(
  #     @ae_url,
  #     @network_id,
  #     {alice, accounts_initiator()},
  #     {bob, accounts_responder()},
  #     &TestScenarios.reestablish_jobs_v2/3
  #   )
  # end

  # test "query after reconnect", context do
  #   {alice, bob} = gen_names(context.test)

  #   ClientRunner.start_peers(
  #     @ae_url,
  #     @network_id,
  #     {alice, accounts_initiator()},
  #     {bob, accounts_responder()},
  #     &TestScenarios.query_after_reconnect_v2/3
  #   )
  # end

  @tag :open_channel_passive
  test "teardown on channel creation", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_peers(
      @ae_url,
      @network_id,
      {alice, accounts_initiator()},
      {bob, accounts_responder()},
      &TestScenarios.teardown_on_channel_creation_v2/3,
      custom_config(%{}, %{minimum_depth: 50})
    )
  end
end
