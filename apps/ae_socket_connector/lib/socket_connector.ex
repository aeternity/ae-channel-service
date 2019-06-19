defmodule SocketConnector do
  use WebSockex
  require Logger

  @socket_ping_intervall 50

  defstruct pub_key: nil,
            priv_key: nil,
            role: nil,
            # WsConnection{},
            session: %{},
            color: nil,
            channel_id: nil,
            pending_id: nil,
            # SyncCall{},
            sync_call: %{},
            ws_manager_pid: nil,
            state_tx: nil,
            network_id: nil,
            ws_base: nil,
            nonce_map: %{},
            contract_file: nil,
            contract_owner: nil,
            contract_pubkey: nil,
            contract_fun: nil,
            timer_reference: nil

  defmodule(WsConnection,
    do:
      defstruct(
        initiator: nil,
        responder: nil,
        initiator_amount: nil,
        responder_amount: nil
      )
  )

  # TODO make some great use of this
  defmodule(Contract,
    do:
      defstruct(
        contract_file: nil,
        contract_owner: nil,
        contract_pubkey: nil
      )
  )

  defmodule(SyncCall,
    do:
      defstruct(
        request: nil,
        response: nil
      )
  )

  def start_link(
        _name,
        %__MODULE__{
          pub_key: _pub_key,
          priv_key: _priv_key,
          session: %WsConnection{
            initiator: initiator,
            responder: responder,
            initiator_amount: initiator_amount,
            responder_amount: responder_amount
          },
          role: role
        } = state_channel_context,
        ws_base,
        network_id,
        color,
        ws_manager_pid
      ) do
    initiator_id = :aeser_api_encoder.encode(:account_pubkey, initiator)
    responder_id = :aeser_api_encoder.encode(:account_pubkey, responder)
    session_map = init_map(initiator_id, responder_id, initiator_amount, responder_amount, role)
    ws_url = create_link(ws_base, session_map)
    Logger.debug("start_link #{inspect(ws_url)}", ansi_color: color)

    {:ok, pid} =
      WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{
        state_channel_context
        | ws_manager_pid: ws_manager_pid,
          ws_base: ws_base,
          network_id: network_id,
          timer_reference: nil,
          color: [ansi_color: color]
      })

    start_ping(pid)
    {:ok, pid}

    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end

  def start_link(
        _name,
        %__MODULE__{state_tx: nil},
        _ws_base,
        :reestablish,
        color,
        _ws_manager_pid
      ) do
    Logger.error("cannot reconnect", ansi_color: color)
    {:ok, nil}

    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end

  def start_link(
        _name,
        %__MODULE__{pub_key: _pub_key, role: role, channel_id: channel_id, state_tx: state_tx} =
          state_channel_context,
        :reestablish,
        color,
        ws_manager_pid
      ) do
    session_map = init_reestablish_map(channel_id, state_tx, role)
    ws_url = create_link(state_channel_context.ws_base, session_map)
    Logger.debug("start_link reestablish #{inspect(ws_url)}", ansi_color: color)

    {:ok, pid} =
      WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{
        state_channel_context
        | ws_manager_pid: ws_manager_pid,
          timer_reference: nil,
          color: [ansi_color: color]
      })

    start_ping(pid)
    {:ok, pid}

    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end

  @spec start_ping(pid) :: :ok
  def start_ping(pid) do
    WebSockex.cast(pid, {:ping})
  end

  @spec initiate_transfer(pid, integer) :: :ok
  def initiate_transfer(pid, amount) do
    WebSockex.cast(pid, {:transfer, amount})
  end

  @spec deposit(pid, integer) :: :ok
  def deposit(pid, amount) do
    WebSockex.cast(pid, {:deposit, amount})
  end

  @spec withdraw(pid, integer) :: :ok
  def withdraw(pid, amount) do
    WebSockex.cast(pid, {:withdraw, amount})
  end

  @spec query_funds(pid, pid) :: :ok
  def query_funds(pid, from \\ nil) do
    WebSockex.cast(pid, {:query_funds, from})
  end

  @spec get_offchain_state(pid, pid) :: :ok
  def get_offchain_state(pid, from \\ nil) do
    WebSockex.cast(pid, {:get_offchain_state, from})
  end

  @spec shutdown(pid) :: :ok
  def shutdown(pid) do
    WebSockex.cast(pid, {:shutdown, {}})
  end

  @spec leave(pid) :: :ok
  def leave(pid) do
    WebSockex.cast(pid, {:leave, {}})
  end

  @spec new_contract(pid, String.t()) :: :ok
  def new_contract(pid, contract_file) do
    WebSockex.cast(pid, {:new_contract, contract_file})
  end

  @spec call_contract(pid, String.t(), binary(), binary()) :: :ok
  def call_contract(pid, contract_file, fun, args) do
    WebSockex.cast(pid, {:call_contract, contract_file, fun, args})
  end

  @spec get_contract_reponse(pid, String.t(), binary(), pid) :: :ok
  def get_contract_reponse(pid, contract_file, fun, from \\ nil) do
    WebSockex.cast(pid, {:get_contract_reponse, contract_file, fun, from})
  end

  # server side

  def handle_connect(_conn, state) do
    # Logger.info("Connected! #{inspect conn}")
    {:ok, state}
  end

  def handle_cast({:ping}, state) do
    get_timer = fn timer ->
      case timer do
        nil ->
          {:ok, t_ref} =
            :timer.apply_interval(
              :timer.seconds(@socket_ping_intervall),
              __MODULE__,
              :start_ping,
              [self()]
            )

          t_ref

        timer ->
          timer
      end
    end

    timer_reference = get_timer.(state.timer_reference)
    {:reply, :ping, %__MODULE__{state | timer_reference: timer_reference}}
  end

  # def handle_pong(pong_frame, state) do
  #   {:ok, state}
  # end

  def handle_cast({:transfer, amount}, state) do
    sync_call = transfer_amount(state.session.initiator, state.session.responder, amount)

    Logger.info("=> transfer #{inspect(sync_call)}", state.color)

    {:reply, {:text, Poison.encode!(sync_call)},
     %__MODULE__{state | pending_id: Map.get(sync_call, :id, nil), sync_call: sync_call}}
  end

  def handle_cast({:deposit, amount}, state) do
    transfer = deposit(amount)
    Logger.info("=> deposit #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:withdraw, amount}, state) do
    transfer = withdraw(amount)
    Logger.info("=> withdraw #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:query_funds, from_pid}, state) do
    sync_call = %SyncCall{request: request} = request_funds(state, from_pid)

    Logger.info("=> get contract #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         sync_call: sync_call
     }}
  end

  def handle_cast({:get_offchain_state, from_pid}, state) do
    sync_call = %SyncCall{request: request} = get_offchain_state_query(from_pid)

    Logger.info("=> get offchain state #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         sync_call: sync_call
     }}
  end

  def handle_cast({:shutdown, {}}, state) do
    transfer = shutdown()
    Logger.info("=> shutdown #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:leave, {}}, state) do
    transfer = leave()
    Logger.info("=> leave #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:new_contract, contract_file}, state) do
    {:ok, map} = :aeso_compiler.file(contract_file)
    encoded_bytecode = :aeser_api_encoder.encode(:contract_bytearray, :aect_sophia.serialize(map))

    {:ok, call_data, _, _} =
      :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'init', [])

    encoded_calldata = :aeser_api_encoder.encode(:contract_bytearray, call_data)
    transfer = new_contract_req(encoded_bytecode, encoded_calldata, 3)
    # transfer = new_contract(encoded_bytecode, "", 3)
    # transfer = new_contract(@code, @call_data, 3)
    Logger.info("=> new contract #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  # get inspiration here: https://github.com/aeternity/aesophia/blob/master/test/aeso_abi_tests.erl#L99
  # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']
  def handle_cast({:call_contract, contract_file, fun, args}, state) do
    {:ok, call_data, _, _} =
      :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), fun, args)

    Logger.debug("call_contract, contract pubkey #{inspect(state.contract_pubkey)}")

    encoded_calldata = :aeser_api_encoder.encode(:contract_bytearray, call_data)
    address = state.contract_pubkey

    transfer = call_contract_req(address, encoded_calldata)
    Logger.info("=> call contract #{inspect(transfer)}", state.color)

    {:reply, {:text, Poison.encode!(transfer)},
     %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:get_contract_reponse, contract_file, fun, from_pid}, state) do
    address = state.contract_pubkey

    sync_call =
      %SyncCall{request: request} =
      get_contract_response_query(
        address,
        :aeser_api_encoder.encode(:account_pubkey, state.pub_key),
        state.nonce_map[:round],
        from_pid
      )

    Logger.info("=> get contract #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         contract_file: contract_file,
         contract_fun: fun,
         sync_call: sync_call
     }}
  end

  # https://github.com/aeternity/protocol/blob/master/node/api/examples/channels/json-rpc/sc_ws_close_mutual.md#initiator-----node-5
  def request_funds(state, from_pid) do
    %WsConnection{initiator: initiator, responder: responder} = state.session
    account_initiator = :aeser_api_encoder.encode(:account_pubkey, initiator)
    account_responder = :aeser_api_encoder.encode(:account_pubkey, responder)

    make_sync(
      from_pid,
      %SyncCall{
        request: %{
          jsonrpc: "2.0",
          method: "channels.get.balances",
          params: %{accounts: [account_initiator, account_responder]}
        },
        response: fn %{"result" => result}, state ->
          GenServer.reply(from_pid, result)
          {result, state}
        end
      }
    )
  end

  def transfer_amount(from, to, amount) do
    account_from = :aeser_api_encoder.encode(:account_pubkey, from)
    account_to = :aeser_api_encoder.encode(:account_pubkey, to)

    %SyncCall{
      request: %{
        jsonrpc: "2.0",
        method: "channels.update.new",
        params: %{
          from: account_from,
          to: account_to,
          amount: amount
        }
      },
      response: nil
    }
  end

  def get_offchain_state_query(from_pid) do
    make_sync(from_pid, %SyncCall{
      request: %{
        id: :erlang.unique_integer([:monotonic]),
        jsonrpc: "2.0",
        method: "channels.get.offchain_state",
        params: %{}
      },
      response: fn %{"result" => result}, state ->
        GenServer.reply(from_pid, result)
        {result, state}
      end
    })
  end

  def shutdown() do
    %{
      jsonrpc: "2.0",
      method: "channels.shutdown",
      params: %{}
    }
  end

  def leave() do
    %{
      jsonrpc: "2.0",
      method: "channels.leave",
      params: %{}
    }
  end

  def deposit(amount) do
    %{
      jsonrpc: "2.0",
      method: "channels.deposit",
      params: %{
        amount: amount
      }
    }
  end

  def withdraw(amount) do
    %{
      jsonrpc: "2.0",
      method: "channels.withdraw",
      params: %{
        amount: amount
      }
    }
  end

  def new_contract_req(code, call_data, _version) do
    %{
      jsonrpc: "2.0",
      method: "channels.update.new_contract",
      params: %{
        abi_version: 1,
        call_data: call_data,
        code: code,
        deposit: 10,
        vm_version: 3
      }
    }
  end

  def call_contract_req(address, call_data) do
    %{
      jsonrpc: "2.0",
      method: "channels.update.call_contract",
      params: %{
        abi_version: 1,
        amount: 0,
        call_data: call_data,
        contract: address
      }
    }
  end

  def make_sync(from, %SyncCall{request: request, response: response}) do
    {request, response}

    case from do
      nil ->
        %SyncCall{request: request, response: nil}

      _pid ->
        %SyncCall{
          request: Map.put(request, :id, :erlang.unique_integer([:monotonic])),
          response: response
        }
    end
  end

  def get_contract_response_query(address, caller, round, from_pid) do
    make_sync(
      from_pid,
      %SyncCall{
        request: %{
          jsonrpc: "2.0",
          method: "channels.get.contract_call",
          params: %{
            caller: caller,
            contract: address,
            round: round
          }
        },
        response: fn %{"result" => result}, state ->
          {result, state_updated} = process_get_contract_reponse(result, state)
          GenServer.reply(from_pid, result)
          {result, state_updated}
        end
      }
    )
  end

  def handle_frame({:text, msg}, state) do
    message = Poison.decode!(msg)
    # Logger.info("Received Message: #{inspect msg} #{inspect message} #{inspect self()}")
    process_message(message, state)
  end

  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local close with reason: #{inspect(reason)}", state.color)
    :timer.cancel(state.timer_reference)
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    Logger.info("disconnected...", state.color)
    :timer.cancel(state.timer_reference)
    GenServer.cast(state.ws_manager_pid, {:connection_dropped, state})
    super(disconnect_map, state)
  end

  # ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=responder
  # ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&host=localhost&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=initiator
  def init_reestablish_map(channel_id, offchain_tx, role) do
    initiator = %{host: "localhost", role: "initiator"}
    responder = %{role: "responder"}

    same = %{
      existing_channel_id: channel_id,
      offchain_tx: offchain_tx,
      protocol: "json-rpc",
      port: "12341"
    }

    role_map =
      case role do
        :initiator -> initiator
        :responder -> responder
      end

    Map.merge(same, role_map)
  end

  def init_map(initiator_id, responder_id, initiator_amount, responder_amount, role) do
    initiator = %{host: "localhost", role: "initiator"}
    responder = %{role: "responder"}

    same = %{
      channel_reserve: "2",
      initiator_amount: initiator_amount,
      initiator_id: initiator_id,
      lock_period: "10",
      port: "12340",
      protocol: "json-rpc",
      push_amount: "1",
      responder_amount: responder_amount,
      responder_id: responder_id
    }

    role_map =
      case role do
        :initiator -> initiator
        :responder -> responder
      end

    Map.merge(same, role_map)
  end

  def create_link(base_url, params) do
    base_url
    |> URI.parse()
    |> Map.put(:query, URI.encode_query(params))
    |> URI.to_string()
  end

  defp sign_transaction_perform(
         to_sign,
         state,
         verify_hook \\ fn _tx, _state -> {:unsecure, nil} end
       ) do
    {:ok, create_bin_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    # returns #aetx
    tx = :aetx.deserialize_from_binary(create_bin_tx)

    case verify_hook.(tx, state) do
      {:unsecure, nonce_map} ->
        {"", nonce_map}

      {:ok, nonce_map} ->
        # bin = :aetx.serialize_to_binary(tx)
        bin = create_bin_tx
        bin_for_network = <<state.network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
        signed_create_tx = :aetx_sign.new(tx, [result_signed])

        {:aeser_api_encoder.encode(
           :transaction,
           :aetx_sign.serialize_to_binary(signed_create_tx)
         ), nonce_map}
    end
  end

  defp sign_transaction(to_sign, authenticator, state, method: method, logstring: logstring) do
    {enc_signed_create_tx, nonce_map} = sign_transaction_perform(to_sign, state, authenticator)
    response = %{jsonrpc: "2.0", method: method, params: %{tx: enc_signed_create_tx}}
    Logger.debug("=>#{inspect(logstring)} : #{inspect(response)} #{inspect(self())}", state.color)
    {response, nonce_map}
  end

  def process_message(
        %{
          "method" => "channels.info",
          "params" => %{"channel_id" => channel_id, "data" => %{"event" => "funding_locked"}}
        } = _message,
        state
      ) do
    {:ok, %__MODULE__{state | channel_id: channel_id}}
  end

  def process_message(
        %{"method" => "channels.sign.initiator_sign", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, &Validator.inspect_sign_request/2, state,
        method: "channels.initiator_sign",
        logstring: "initiator_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.sign.responder_sign", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, &Validator.inspect_sign_request/2, state,
        method: "channels.responder_sign",
        logstring: "responder_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.sign.deposit_tx", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.deposit_tx",
        logstring: "initiator_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.sign.deposit_ack", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.deposit_ack",
        logstring: "responder_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.sign.withdraw_tx", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.withdraw_tx",
        logstring: "initiator_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.sign.withdraw_ack", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.withdraw_ack",
        logstring: "responder_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  # def process_message(%{"method" => "channels.sign.responder_sign", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
  #   {response, nonce_map} = sign_transaction(to_sign, &Validator.inspect_sign_request/2, state, [method: "channels.responder_sign", logstring: "responder_sign"])
  #   {:reply, {:text, Poison.encode!(response)}, %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  # end

  def process_message(
        %{"method" => "channels.sign.shutdown_sign", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.shutdown_sign",
        logstring: "initiator_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{
          "method" => "channels.sign.shutdown_sign_ack",
          "params" => %{"data" => %{"tx" => to_sign}}
        } = _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, fn _a, _b -> {:ok, %{}} end, state,
        method: "channels.shutdown_sign_ack",
        logstring: "initiator_sign"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{
          "method" => "channels.sign.update",
          "params" => %{"data" => %{"tx" => to_sign, "updates" => update}}
        } = _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, &Validator.inspect_transfer_request/2, state,
        method: "channels.update",
        logstring: "channels.sign.update"
      )

    updated_nonce_map = Map.merge(state.nonce_map, nonce_map)
    {contract_owner, contract_pubkey} = extract_contract_info(update, updated_nonce_map, state)

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{
       state
       | nonce_map: updated_nonce_map,
         contract_owner: contract_owner,
         contract_pubkey: contract_pubkey
     }}
  end

  def process_get_contract_reponse(%{"return_value" => return_value}, state) do
    {:contract_bytearray, deserialized_return} = :aeser_api_encoder.decode(return_value)

    sophia_value =
      :aeso_compiler.to_sophia_value(
        to_charlist(File.read!(state.contract_file)),
        state.contract_fun,
        :ok,
        deserialized_return
      )

    # human_readable = :aeb_heap.from_binary(:aeso_compiler.sophia_type_to_typerep('string'), deserialized_return)
    # {:ok, term} = :aeb_heap.from_binary(:string, deserialized_return)
    # result = :aect_sophia.prepare_for_json(:string, term)
    # Logger.debug(
    # "contract call reply: #{inspect(deserialized_return)} type is #{return_type}, human: #{
    #   inspect(result)
    #   }", state.color
    # )

    {sophia_value, state}
  end

  def process_message(
        %{
          "method" => "channels.get.contract_call.reply",
          "params" => %{
            # "data" => %{"return_value" => return_value, "return_type" => _return_type}
            "data" => data
          }
        } = _message,
        state
      ) do
    {sophia_value, state_update} = process_get_contract_reponse(data, state)

    Logger.debug(
      "contract call async reply (as result of calling: #{inspect(state.contract_fun)}): #{
        inspect(sophia_value)
      }",
      state.color
    )

    {:ok, state_update}
  end

  def process_message(%{"channel_id" => _channel_id, "error" => _error_struct} = error, state) do
    Logger.error("<= error unprocessed message: #{inspect(error)}")
    {:ok, state}
  end

  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state)
      when id == pending_id do
    {_result, updated_state} =
      case state.sync_call do
        %SyncCall{response: response} ->
          case response do
            nil -> Logger.error("Not implemented received data is: #{inspect(query_reponse)}")
            _ -> response.(query_reponse, state)
          end

        %{} ->
          Logger.error("Unexpected id match: #{inspect(query_reponse)}")
          {:ok, state}
      end

    # TODO is this where sync_call should be modified or in responce.?
    {:ok, %__MODULE__{updated_state | sync_call: %{}}}
  end

  # wrong unexpected id in response.
  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state)
      when id != pending_id do
    Logger.error("<= Failed match id, response: #{inspect(query_reponse)} #{inspect(pending_id)}")
    {:ok, state}
  end

  def process_message(
        %{
          "method" => "channels.update",
          "params" => %{"channel_id" => channel_id, "data" => %{"state" => state_tx}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id do
    log_string =
      case state_tx == state.state_tx do
        true -> "unchanged, state is #{inspect(state_tx)}"
        false -> "updated, state is #{inspect(state_tx)} old was #{inspect(state.state_tx)}"
      end

    Logger.debug("= channels.update: " <> log_string, state.color)
    {:ok, %__MODULE__{state | state_tx: state_tx}}
  end

  defp compute_contract_address(contract_owner, nonce_map) do
    address_inter = :aect_contracts.compute_contract_pubkey(contract_owner, nonce_map[:round])
    :aeser_api_encoder.encode(:contract_pubkey, address_inter)
  end

  def extract_contract_info(update, nonce_map, state) do
    {contract_owner, contract_pubkey} =
      case update do
        [] ->
          # TODO needs to be reworked, need to be able to remove contracts
          {state.contract_owner.state.contract_pubkey}

        [entry] ->
          case Map.get(entry, "owner", nil) do
            # TODO needs to be reworked, need to be able to remove contracts
            nil ->
              {state.contract_owner, state.contract_pubkey}

            owner ->
              {:account_pubkey, decoded_pubkey} = :aeser_api_encoder.decode(owner)
              {owner, compute_contract_address(decoded_pubkey, nonce_map)}
          end
      end

    Logger.debug(
      "contract info: #{inspect(contract_owner)} #{inspect(contract_pubkey)}",
      state.color
    )

    {contract_owner, contract_pubkey}
  end

  def process_message(
        %{
          "method" => "channels.sign.update_ack",
          "params" => %{"data" => %{"tx" => to_sign, "updates" => update}}
        } = _message,
        state
      ) do
    {response, nonce_map} =
      sign_transaction(to_sign, &Validator.inspect_transfer_request/2, state,
        method: "channels.update_ack",
        logstring: "responder_sign_update"
      )

    updated_nonce_map = Map.merge(state.nonce_map, nonce_map)
    {contract_owner, contract_pubkey} = extract_contract_info(update, updated_nonce_map, state)

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{
       state
       | nonce_map: updated_nonce_map,
         contract_owner: contract_owner,
         contract_pubkey: contract_pubkey
     }}
  end

  def process_message(
        %{"method" => "channels.sign.update_ack", "params" => %{"data" => %{"tx" => to_sign}}} =
          _message,
        state
      ) do
    Logger.info("no update")

    {response, nonce_map} =
      sign_transaction(to_sign, &Validator.inspect_transfer_request/2, state,
        method: "channels.update_ack",
        logstring: "responder_sign_update"
      )

    {:reply, {:text, Poison.encode!(response)},
     %__MODULE__{state | nonce_map: Map.merge(state.nonce_map, nonce_map)}}
  end

  def process_message(
        %{"method" => "channels.info", "params" => %{"channel_id" => channel_id}} = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id do
    {:ok, state}
  end

  def process_message(
        %{
          "method" => "channels.on_chain_tx",
          "params" => %{"channel_id" => channel_id, "data" => %{"tx" => signed_tx}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id do
    Validator.verify_on_chain(signed_tx)
    {:ok, state}
  end

  def process_message(
        %{
          "method" => "channels.info",
          "params" => %{"channel_id" => channel_id, "data" => %{"event" => "open"}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id do
    Logger.debug("= CHANNEL OPEN/READY", state.color)
    {:ok, state}
  end

  def process_message(%{"method" => "channels.info"} = message, state) do
    Logger.debug("= channels info: #{inspect(message)}", state.color)
    {:ok, state}
  end

  def process_message(message, state) do
    Logger.error(
      "<= unprocessed message recieved by #{inspect(state.role)}. message: #{inspect(message)}"
    )

    {:ok, state}
  end
end
