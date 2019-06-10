defmodule ChannelRunner do
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"

  def start_channel_helper() do
    start_channel(
      TestAccounts.initiatorPubkey(),
      TestAccounts.initiatorPrivkey(),
      TestAccounts.responderPubkey(),
      TestAccounts.responderPrivkey(),
      @ae_url,
      @network_id
    )
  end

  def compile_contract() do
    # :aeso_compiler.file("apps/aesocketconnector/res/contract")
    # :aeso_compiler.from_string(con, [:pp_assembler])
  end

  def start_channel(
        initiator_pub,
        initiator_priv,
        responder_pub,
        responder_priv,
        ae_url,
        network_id
      ) do
    # TODO introduce a job list sequence for the instances.
    state_channel_configuration = %SocketConnector.WsConnection{
      initiator: initiator_pub,
      initiator_amount: 7_000_000_000_000,
      responder: responder_pub,
      responder_amount: 4_000_000_000_000
    }

    {:ok, pid_initiator} =
      SessionHolder.start_link(
        %SocketConnector{
          pub_key: initiator_pub,
          priv_key: initiator_priv,
          session: state_channel_configuration,
          role: :initiator
        },
        ae_url,
        network_id,
        :yellow
      )

    Logger.debug("pid_initiator #{inspect(pid_initiator)}", ansi_color: :yellow)

    {:ok, pid_responder} =
      SessionHolder.start_link(
        %SocketConnector{
          pub_key: responder_pub,
          priv_key: responder_priv,
          session: state_channel_configuration,
          role: :responder
        },
        ae_url,
        network_id,
        :blue
      )

    Logger.debug("pid_responder #{inspect(pid_responder)}", ansi_color: :blue)

    # Process.sleep(4000)
    # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.query_funds(pid) end)
    #
    # Process.sleep(4000)
    # SessionHolder.run_action(pid_responder, fn(pid) -> SocketConnector.initiate_transfer(pid, 2) end)
    # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.initiate_transfer(pid, 2) end)
    Process.sleep(5000)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.new_contract(pid, "contracts/TicTacToe.aes")
    end)

    Process.sleep(5000)

    # get inspiration here: https://github.com/aeternity/aesophia/blob/master/test/aeso_abi_tests.erl#L99
    # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']
    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['11', '1'])
    end)

    Process.sleep(5000)

    tennis = SessionHolder.run_action_sync(pid_initiator, fn (pid, from) ->
      SocketConnector.get_contract_reponse_sync(pid, from, "contracts/TicTacToe.aes", 'make_move')
    end)
    Logger.error "dklsjdajks #{inspect tennis}"

    Process.sleep(5000)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move')
    end)

    Process.sleep(5000)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '1'])
    end)



    Process.sleep(5000)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '2'])
    end)

    Process.sleep(5000)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move')
    end)

    Process.sleep(5000)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.withdraw(pid, 1_000_000)
    end)

    #
    Process.sleep(4000)
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)
    #
    Process.sleep(4000)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.deposit(pid, 1_000_000)
    end)

    #
    Process.sleep(4000)
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)
    #
    # Process.sleep(4000)
    # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.get_offchain_state(pid) end)

    Process.sleep(4000)
    # TODO mutual shutdown should not yield a reconnect, but rather a nice shutdown.
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.leave(pid) end)
    # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.shutdown(pid) end)
  end
end
