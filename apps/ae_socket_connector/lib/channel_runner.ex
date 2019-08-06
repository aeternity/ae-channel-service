defmodule ChannelRunner do
  require Logger

  @ae_url "ws://localhost:3014/channel"
  @network_id "my_test"

  @pause 2000

  def start_channel_helper(),
    do: start_channel_helper(:single)

  def start_channel_helper(mode) do
    case mode do
      :single ->
        start_channel(
          TestAccounts.initiatorPubkey(),
          TestAccounts.initiatorPrivkey(),
          TestAccounts.responderPubkey(),
          TestAccounts.responderPrivkey(),
          @ae_url,
          @network_id
        )

      :multi ->
        spawn(ChannelRunner, :start_initiator, [
          TestAccounts.initiatorPubkey(),
          TestAccounts.initiatorPrivkey(),
          TestAccounts.responderPubkey(),
          nil,
          @ae_url,
          @network_id,
          @pause
        ])

        spawn(ChannelRunner, :start_responder, [
          TestAccounts.initiatorPubkey(),
          nil,
          TestAccounts.responderPubkey(),
          TestAccounts.responderPrivkey(),
          @ae_url,
          @network_id,
          0
        ])
    end

    # start_channel(
    #   TestAccounts.initiatorPubkey(),
    #   TestAccounts.initiatorPrivkey(),
    #   TestAccounts.responderPubkey(),
    #   TestAccounts.responderPrivkey(),
    #   @ae_url,
    #   @network_id
    # )
  end

  def compile_contract() do
    # :aeso_compiler.file("apps/aesocketconnector/res/contract")
    # :aeso_compiler.from_string(con, [:pp_assembler])
  end

  # def start_responder(
  #       initiator_pub,
  #       _initiator_priv,
  #       responder_pub,
  #       responder_priv,
  #       ae_url,
  #       network_id,
  #       offset
  #     ) do
  #   state_channel_configuration = %SocketConnector.WsConnection{
  #     initiator: initiator_pub,
  #     initiator_amount: 7_000_000_000_000,
  #     responder: responder_pub,
  #     responder_amount: 4_000_000_000_000
  #   }
  #
  #   {:ok, pid_responder} =
  #     SessionHolder.start_link(
  #       %SocketConnector{
  #         pub_key: responder_pub,
  #         priv_key: responder_priv,
  #         session: state_channel_configuration,
  #         role: :responder
  #       },
  #       ae_url,
  #       network_id,
  #       :blue
  #     )
  #
  #   Logger.debug("pid_responder #{inspect(pid_responder)}", ansi_color: :blue)
  #
  #   # Process.sleep(@pause)
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.query_funds(pid) end)
  #   #
  #
  #   Process.sleep(offset)
  #
  #   Process.sleep(6000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_responder, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :blue)
  #
  #   Process.sleep(@pause)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.initiate_transfer(pid, 2)
  #   end)
  #
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.initiate_transfer(pid, 2) end)
  #
  #   Process.sleep(6000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_responder, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :blue)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.new_contract(pid, {responder_pub, "contracts/TicTacToe.aes"})
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_responder, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :blue)
  #
  #   channel_state =
  #     SessionHolder.run_action_sync(pid_responder, fn pid, from ->
  #       SocketConnector.get_offchain_state(pid, from)
  #     end)
  #
  #   Logger.info("state is: #{inspect(channel_state)}", ansi_color: :blue)
  #
  #   # get inspiration here: https://github.com/aeternity/aesophia/blob/master/test/aeso_abi_tests.erl#L99
  #   # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['11', '1'])
  #   end)
  #
  #   Process.sleep(5000)
  #   # Logger.error "get_contract_respose #{inspect get_contract_respose}"
  #
  #   Logger.debug("CALL CONTRACT SYNC")
  #
  #   get_contract_respose =
  #     SessionHolder.run_action_sync(pid_responder, fn pid, from ->
  #       SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', from)
  #     end)
  #
  #   Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
  #     ansi_color: :blue
  #   )
  #
  #   Process.sleep(5000)
  #
  #   get_contract_respose =
  #     SessionHolder.run_action(pid_responder, fn pid ->
  #       SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', nil)
  #     end)
  #
  #   Logger.info("get contract response Async is: #{inspect(get_contract_respose)}",
  #     ansi_color: :blue
  #   )
  #
  #   # get_contract_respose = SessionHolder.run_action_sync(pid_responder, fn (pid, from) ->
  #   #   SocketConnector.call_contract_sync(pid, from, "contracts/TicTacToe.aes", 'make_move', ['12', '1'])
  #   # end)
  #   # Logger.error "get_contract_respose #{inspect get_contract_respose}"
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', nil)
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '1'])
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '2'])
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move')
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.withdraw(pid, 1_000_000)
  #   end)
  #
  #   #
  #   Process.sleep(@pause)
  #   SessionHolder.run_action(pid_responder, fn pid -> SocketConnector.query_funds(pid) end)
  #   #
  #   Process.sleep(@pause)
  #
  #   SessionHolder.run_action(pid_responder, fn pid ->
  #     SocketConnector.deposit(pid, 1_000_000)
  #   end)
  #
  #   #
  #   Process.sleep(@pause)
  #   SessionHolder.run_action(pid_responder, fn pid -> SocketConnector.query_funds(pid) end)
  #   #
  #   # Process.sleep(@pause)
  #   # SessionHolder.run_action(pid_responder, fn(pid) -> SocketConnector.get_offchain_state(pid) end)
  #
  #   Process.sleep(@pause)
  #   # TODO mutual shutdown should not yield a reconnect, but rather a nice shutdown.
  #   SessionHolder.run_action(pid_responder, fn pid -> SocketConnector.leave(pid) end)
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.shutdown(pid) end)
  # end
  #
  # def start_initiator(
  #       initiator_pub,
  #       initiator_priv,
  #       responder_pub,
  #       _responder_priv,
  #       ae_url,
  #       network_id,
  #       offset
  #     ) do
  #   state_channel_configuration = %SocketConnector.WsConnection{
  #     initiator: initiator_pub,
  #     initiator_amount: 7_000_000_000_000,
  #     responder: responder_pub,
  #     responder_amount: 4_000_000_000_000
  #   }
  #
  #   {:ok, pid_initiator} =
  #     SessionHolder.start_link(
  #       %SocketConnector{
  #         pub_key: initiator_pub,
  #         priv_key: initiator_priv,
  #         session: state_channel_configuration,
  #         role: :initiator
  #       },
  #       ae_url,
  #       network_id,
  #       :yellow
  #     )
  #
  #   Logger.debug("pid_initiator #{inspect(pid_initiator)}", ansi_color: :yellow)
  #
  #   # Process.sleep(@pause)
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.query_funds(pid) end)
  #   #
  #
  #   Process.sleep(offset)
  #
  #   Process.sleep(6000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :yellow)
  #
  #   Process.sleep(@pause)
  #
  #   SessionHolder.run_action(pid_initiator, fn pid ->
  #     SocketConnector.initiate_transfer(pid, 2)
  #   end)
  #
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.initiate_transfer(pid, 2) end)
  #
  #   Process.sleep(6000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :yellow)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_initiator, fn pid ->
  #     SocketConnector.new_contract(pid, "contracts/TicTacToe.aes")
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   funds =
  #     SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
  #       SocketConnector.query_funds(pid, from)
  #     end)
  #
  #   Logger.info("funds are: #{inspect(funds)}", ansi_color: :yellow)
  #
  #   channel_state =
  #     SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
  #       SocketConnector.get_offchain_state(pid, from)
  #     end)
  #
  #   Logger.info("state is: #{inspect(channel_state)}", ansi_color: :yellow)
  #
  #   # get inspiration here: https://github.com/aeternity/aesophia/blob/master/test/aeso_abi_tests.erl#L99
  #   # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']
  #
  #   SessionHolder.run_action(pid_initiator, fn pid ->
  #     SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['11', '1'])
  #   end)
  #
  #   Process.sleep(5000)
  #   # Logger.error "get_contract_respose #{inspect get_contract_respose}"
  #
  #   get_contract_respose =
  #     SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
  #       SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', from)
  #     end)
  #
  #   Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
  #     ansi_color: :yellow
  #   )
  #
  #   get_contract_respose =
  #     SessionHolder.run_action(pid_initiator, fn pid ->
  #       SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', nil)
  #     end)
  #
  #   Logger.info("get contract response Async is: #{inspect(get_contract_respose)}",
  #     ansi_color: :yellow
  #   )
  #
  #   # get_contract_respose = SessionHolder.run_action_sync(pid_initiator, fn (pid, from) ->
  #   #   SocketConnector.call_contract_sync(pid, from, "contracts/TicTacToe.aes", 'make_move', ['12', '1'])
  #   # end)
  #   # Logger.error "get_contract_respose #{inspect get_contract_respose}"
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_initiator, fn pid ->
  #     SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move', nil)
  #   end)
  #
  #   Process.sleep(5000)
  #
  #   SessionHolder.run_action(pid_initiator, fn pid ->
  #     SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '1'])
  #   end)
  #
  #   # Process.sleep(5000)
  #   #
  #   # SessionHolder.run_action(pid_initiator, fn pid ->
  #   #   SocketConnector.call_contract(pid, "contracts/TicTacToe.aes", 'make_move', ['12', '2'])
  #   # end)
  #   #
  #   # Process.sleep(5000)
  #   #
  #   # SessionHolder.run_action(pid_initiator, fn pid ->
  #   #   SocketConnector.get_contract_reponse(pid, "contracts/TicTacToe.aes", 'make_move')
  #   # end)
  #   #
  #   # Process.sleep(5000)
  #   #
  #   # SessionHolder.run_action(pid_initiator, fn pid ->
  #   #   SocketConnector.withdraw(pid, 1_000_000)
  #   # end)
  #   #
  #   # #
  #   # Process.sleep(@pause)
  #   # SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)
  #   # #
  #   # Process.sleep(@pause)
  #   #
  #   # SessionHolder.run_action(pid_initiator, fn pid ->
  #   #   SocketConnector.deposit(pid, 1_000_000)
  #   # end)
  #
  #   #
  #   Process.sleep(@pause)
  #   SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)
  #   #
  #   # Process.sleep(@pause)
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.get_offchain_state(pid) end)
  #
  #   Process.sleep(@pause)
  #   # TODO mutual shutdown should not yield a reconnect, but rather a nice shutdown.
  #   SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.leave(pid) end)
  #   # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.shutdown(pid) end)
  # end

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

    Process.sleep(@pause)
    Logger.info("query funds async", ansi_color: :yellow)

    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)

    Process.sleep(@pause)

    Logger.info("query funds 2", ansi_color: :yellow)

    funds =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.query_funds(pid, from)
      end)

    Logger.info("funds are: #{inspect(funds)}")

    Process.sleep(@pause)

    Logger.info("transfer funds", ansi_color: :blue)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.initiate_transfer(pid, 2)
    end)

    #
    # # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.initiate_transfer(pid, 2) end)
    #
    Process.sleep(@pause)

    Logger.info("query funds 3", ansi_color: :yellow)

    funds =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.query_funds(pid, from)
      end)

    Logger.info("funds are: #{inspect(funds)}")

    Process.sleep(@pause)

    initiator_contract = {initiator_pub, "contracts/TicTacToe.aes"}

    responder_contract = {responder_pub, "contracts/TicTacToe.aes"}

    Logger.info("deploy contract", ansi_color: :yellow)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.new_contract(pid, initiator_contract)
    end)

    Process.sleep(@pause)

    Logger.info("A", ansi_color: :red)
    Logger.info("deploy contract", ansi_color: :blue)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.new_contract(pid, responder_contract)
    end)

    # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']

    Process.sleep(@pause)
    Logger.info("B", ansi_color: :red)
    Logger.info("call contract", ansi_color: :yellow)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(
        pid,
        initiator_contract,
        'make_move',
        ['11', '1']
      )
    end)

    Process.sleep(@pause)
    Logger.info("C", ansi_color: :red)
    Logger.info("call contract", ansi_color: :blue)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(
        pid,
        initiator_contract,
        'make_move',
        ['11', '1']
      )
    end)

    Process.sleep(@pause)
    Logger.info("get contract result", ansi_color: :yellow)
    Logger.info("D", ansi_color: :red)

    get_contract_respose =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.get_contract_reponse(
          pid,
          initiator_contract,
          'make_move',
          from
        )
      end)

    Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
      ansi_color: :blue
    )

    Process.sleep(@pause)
    Logger.info("E", ansi_color: :red)
    Logger.info("call contract", ansi_color: :blue)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.call_contract(
        pid,
        responder_contract,
        'make_move',
        ['11', '1']
      )
    end)

    Process.sleep(@pause)
    Logger.info("get contract result", ansi_color: :blue)
    Logger.info("F", ansi_color: :red)

    get_contract_respose =
      SessionHolder.run_action_sync(pid_responder, fn pid, from ->
        SocketConnector.get_contract_reponse(
          pid,
          responder_contract,
          'make_move',
          from
        )
      end)

    Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
      ansi_color: :blue
    )

    Process.sleep(@pause)
    Logger.info("call contract", ansi_color: :yellow)
    Logger.info("G", ansi_color: :red)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(
        pid,
        responder_contract,
        'make_move',
        ['12', '2']
      )
    end)

    Process.sleep(@pause)
    Logger.info("call contract", ansi_color: :yellow)
    Logger.info("H", ansi_color: :red)

    SessionHolder.run_action(pid_initiator, fn pid ->
      SocketConnector.call_contract(
        pid,
        initiator_contract,
        'make_move',
        ['12', '1']
      )
    end)

    Process.sleep(@pause)
    Logger.info("call contract", ansi_color: :blue)
    Logger.info("I", ansi_color: :red)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.call_contract(
        pid,
        initiator_contract,
        'make_move',
        ['12', '2']
      )
    end)

    # Process.sleep(@pause)
    # Logger.info("call contract", ansi_color: :blue)
    # Logger.info("J", ansi_color: :red)

    # SessionHolder.run_action(pid_responder, fn pid ->
    #   SocketConnector.call_contract(
    #     pid,
    #     responder_contract,
    #     'make_move',
    #     ['12', '2']
    #   )
    # end)

    Process.sleep(@pause)
    Logger.info("K", ansi_color: :red)

    Logger.info("get contract result", ansi_color: :blue)

    get_contract_respose =
      SessionHolder.run_action_sync(pid_responder, fn pid, from ->
        SocketConnector.get_contract_reponse(
          pid,
          initiator_contract,
          'make_move',
          from
        )
      end)

    Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
      ansi_color: :blue
    )

    Logger.info("L", ansi_color: :red)

    Logger.info("get contract result", ansi_color: :yellow)

    get_contract_respose =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.get_contract_reponse(
          pid,
          initiator_contract,
          'make_move',
          from
        )
      end)

    Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
      ansi_color: :yellow
    )

    Logger.info("M", ansi_color: :red)

    Logger.info("get contract result", ansi_color: :yellow)

    get_contract_respose =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.get_contract_reponse(
          pid,
          responder_contract,
          'make_move',
          from
        )
      end)

    Logger.info("get contract response sync is: #{inspect(get_contract_respose)}",
      ansi_color: :yellow
    )

    # Process.sleep(123442)
    #
    # SessionHolder.run_action(pid_responder, fn pid ->
    #   SocketConnector.call_contract(
    #     pid,
    #     initiator_contract,
    #     'make_move',
    #     ['10', '2']
    #   )
    # end)
    #
    # Process.sleep(2000)
    #
    #
    # get_contract_respose =
    #   SessionHolder.run_action_sync(pid_responder, fn pid, from ->
    #     SocketConnector.get_contract_reponse(
    #       pid,
    #       initiator_contract,
    #       'make_move',
    #       from
    #     )
    #   end)
    #
    # Logger.info("get contract response sync is (responder): #{inspect(get_contract_respose)}")
    #
    #
    # Process.sleep(2000)
    #
    # # SessionHolder.run_action(pid_responder, fn pid ->
    # #   SocketConnector.call_contract(
    # #     pid,
    # #     initiator_contract,
    # #     'make_move',
    # #     ['12', '2']
    # #   )
    # # end)
    #

    Process.sleep(@pause)

    Logger.info("get contract off-chain state",
      ansi_color: :yellow
    )

    channel_state =
      SessionHolder.run_action_sync(pid_initiator, fn pid, from ->
        SocketConnector.get_offchain_state(pid, from)
      end)

    Logger.info("off-chain state is: #{inspect(channel_state)}", ansi_color: :yellow)

    Process.sleep(@pause)

    Logger.info("withdraw", ansi_color: :blue)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.withdraw(pid, 1_000_000)
    end)

    Process.sleep(@pause)
    Logger.info("query", ansi_color: :yellow)

    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)
    Process.sleep(@pause)
    Logger.info("deposit", ansi_color: :blue)

    SessionHolder.run_action(pid_responder, fn pid ->
      SocketConnector.deposit(pid, 1_000_000)
    end)

    Process.sleep(@pause)
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.query_funds(pid) end)

    Logger.info("get offchain state", ansi_color: :yellow)

    Process.sleep(@pause)
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.get_offchain_state(pid) end)

    Logger.info("leave", ansi_color: :yellow)

    Process.sleep(6000)
    # TODO mutual shutdown should not yield a reconnect, but rather a nice shutdown.
    SessionHolder.run_action(pid_initiator, fn pid -> SocketConnector.leave(pid) end)
    # SessionHolder.run_action(pid_initiator, fn(pid) -> SocketConnector.shutdown(pid) end)
  end
end
