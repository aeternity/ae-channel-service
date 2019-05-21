defmodule AeTestAccounts do
  # balance
  # {
  #    "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS": 10000000000000000000,
  #    "ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq": 10000000000000000000
  # }

  # @initiator_id "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
  # @initiator "ws://localhost:3014/channel?channel_reserve=2&host=localhost&initiator_amount=70000000000000&initiator_id=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&lock_period=10&port=12340&protocol=json-rpc&push_amount=1&responder_amount=40000000000000&responder_id=ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq&role=initiator"
  require Logger

  defp initiatorPubkey do
     <<106,184,29,213,77,73,184,77,59,65,33,156,241,78,239,173,
    39,2,126,254,111,28,73,150,6,150,66,20,47,81,213,154>>
  end

  defp initiatorPrivkey() do
    <<133,143,10,3,177,135,2,205,204,153,181,19,83,137,93,186,
    100,92,12,201,228,174,194,70,27,220,3,227,212,32,203,
    247,106,184,29,213,77,73,184,77,59,65,33,156,241,78,239,
    173,39,2,126,254,111,28,73,150,6,150,66,20,47,81,213,154>>
  end


  # @responder_id "ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq"
  # @responder "ws://localhost:3014/channel?channel_reserve=2&initiator_amount=70000000000000&initiator_id=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&lock_period=10&port=12340&protocol=json-rpc&push_amount=1&responder_amount=40000000000000&responder_id=ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq&role=responder"
  defp responderPubkey() do
    <<145,57,82,197,159,203,87,93,38,245,163,158,237,249,101,
    141,158,185,198,87,190,11,15,96,80,225,138,111,252,37,
    59,79>>
  end
  defp responderPrivkey() do
    <<55,112,8,133,136,166,103,209,225,173,157,98,179,248,227,
        75,64,253,175,97,81,149,27,108,35,160,80,16,121,176,159,
        138,145,57,82,197,159,203,87,93,38,245,163,158,237,249,
        101,141,158,185,198,87,190,11,15,96,80,225,138,111,252,
        37,59,79>>
  end

  def start_channel() do

    # TODO introduce a job list sequence for the instances.
    state_channel_configuration = %AeSocketConnector.WsConnection{initiator: initiatorPubkey(), initiator_amount: 7000000000000, responder: responderPubkey(), responder_amount: 4000000000000}

    {:ok, pid_initiator} = AeSessionHolder.start_link(%AeSocketConnector{pub_key: initiatorPubkey(), priv_key: initiatorPrivkey(), session: state_channel_configuration, role: :initiator}, :yellow)
    Logger.debug "pid_initiator #{inspect pid_initiator}", ansi_color: :yellow

    {:ok, pid_responder} = AeSessionHolder.start_link(%AeSocketConnector{pub_key: responderPubkey(), priv_key: responderPrivkey(), session: state_channel_configuration, role: :responder}, :blue)
    Logger.debug "pid_responder #{inspect pid_responder}", ansi_color: :blue

    # Process.sleep(4000)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.query_funds(pid) end)
    #
    # Process.sleep(4000)
    # AeSessionHolder.run_action(pid_responder, fn(pid) -> AeSocketConnector.initiate_transfer(pid, 2) end)
    # AeSessionHolder.run_action(pid_initiator, fn(pid) -> AeSocketConnector.initiate_transfer(pid, 2) end)
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
