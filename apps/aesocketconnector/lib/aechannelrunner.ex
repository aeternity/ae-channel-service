defmodule AeChannelRunner do
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"


  def start_channel_helper() do
    start_channel(AeTestAccounts.initiatorPubkey(), AeTestAccounts.initiatorPrivkey(), AeTestAccounts.responderPubkey(), AeTestAccounts.responderPrivkey(), @ae_url, @network_id)
  end

  def compile_contract() do
    # :aeso_compiler.file("apps/aesocketconnector/res/contract")
    # :aeso_compiler.from_string(con, [:pp_assembler])
  end

  def start_channel(initiator_pub, initiator_priv, responder_pub, responder_priv, ae_url, network_id) do

    # TODO introduce a job list sequence for the instances.
    state_channel_configuration = %AeSocketConnector.WsConnection{initiator: initiator_pub, initiator_amount: 7000000000000, responder: responder_pub, responder_amount: 4000000000000}

    {:ok, pid_initiator} = AeSessionHolder.start_link(%AeSocketConnector{pub_key: initiator_pub, priv_key: initiator_priv, session: state_channel_configuration, role: :initiator}, ae_url, network_id, :yellow)
    Logger.debug "pid_initiator #{inspect pid_initiator}", ansi_color: :yellow

    {:ok, pid_responder} = AeSessionHolder.start_link(%AeSocketConnector{pub_key: responder_pub, priv_key: responder_priv, session: state_channel_configuration, role: :responder}, ae_url, network_id, :blue)
    Logger.debug "pid_responder #{inspect pid_responder}", ansi_color: :blue

    # Process.sleep(4000)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.query_funds(pid) end)
    #
    # Process.sleep(4000)
    # AeSessionHolder.run_action(pid_responder, fn(pid) -> AeSocketConnector.initiate_transfer(pid, 2) end)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.initiate_transfer(pid, 2) end)
    Process.sleep(8000)
    AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.upload_contract(pid, "contracts/simple.aes") end)

    Process.sleep(4000)
    AeSessionHolder.run_action(pid_responder, fn(pid) -> AeSocketConnector.withdraw(pid, 1000000) end)
    #
    Process.sleep(4000)
    AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.query_funds(pid) end)
    #
    Process.sleep(4000)
    AeSessionHolder.run_action(pid_responder, fn(pid) -> AeSocketConnector.deposit(pid, 1000000) end)
    #
    Process.sleep(4000)
    AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.query_funds(pid) end)
    #
    # Process.sleep(4000)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.get_offchain_state(pid) end)

    Process.sleep(4000)
    # TODO mutual shutdown should not yield a  reconnect, but rather i nice shutdown.
    AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.leave(pid) end)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.shutdown(pid) end)
  end
end
