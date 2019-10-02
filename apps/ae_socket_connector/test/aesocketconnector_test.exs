defmodule SocketConnectorTest do
  use ExUnit.Case
  # doctest SocketConnectxor
  require ChannelRunner

  @ae_url ChannelRunner.ae_url()
  @network_id ChannelRunner.network_id()

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

  @tag :hello_world
  test "hello fsm", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.hello_fsm/3,
      custom_config(%{}, %{minimum_depth: 0, port: 1400})
    )
  end

  test "withdraw after re-connect", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.withdraw_after_reconnect/3
    )
  end

  test "withdraw after reestablish", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.withdraw_after_reestablish/3
    )
  end

  test "backchannel jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.backchannel_jobs/3
    )
  end

  test "close solo", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.close_solo/3
    )
  end

  @tag :close
  test "close mutual", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.close_mutual/3
    )
  end

  test "reconnect jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.reconnect_jobs/3
    )
  end

  # relocate contact files to get this working.
  @tag :contract
  test "contract jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.contract_jobs/3
    )
  end

  test "reestablish jobs", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.reestablish_jobs/3
    )
  end

  test "query after reconnect", context do
    {alice, bob} = gen_names(context.test)

    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.query_after_reconnect/3
    )
  end

  test "teardown on channel creation", context do
    {alice, bob} = gen_names(context.test)
    assert "false positve, this test needs to disconnect on info message" = "code need to be added in framwork"
    ClientRunner.start_helper(
      @ae_url,
      @network_id,
      alice,
      bob,
      &ClientRunner.teardown_on_channel_creation/3,
      custom_config(%{}, %{minimum_depth: 50})
    )
  end
end
