defmodule SocketConnector do
  use WebSockex
  require Logger

  @socket_ping_intervall 50

  @persist_keys [:pub_key, :role, :session, :fsm_id, :channel_id, :round_and_updates, :pending_round_and_update, :ws_base, :network_id]

  defstruct pub_key: nil,
            role: nil,
            # WsConnection
            session: %{},
            fsm_id: nil,
            channel_id: nil,
            round_and_updates: %{},
            pending_round_and_update: %{},
            pending_id: nil,
            color: nil,
            # SyncCall{},
            sync_call: %{},
            ws_manager_pid: nil,
            network_id: nil,
            ws_base: nil,
            # {round => %Update{}},
            contract_call_in_flight: nil,
            contract_call_in_flight_round: nil,
            timer_reference: nil,
            socket_ping_intervall: @socket_ping_intervall,
            connection_callbacks: nil

  defmodule(Update,
    do:
      defstruct(
        updates: nil,
        tx: nil,
        state_tx: nil,
        contract_call: nil,
        round_initiator: nil,
        poi: nil
      )
  )

  defmodule(ConnectionCallbacks,
    do:
      defstruct(
        sign_approve: nil,
        channels_update: nil,
        channels_info: nil,
        on_chain: nil,
        connection_update: nil
      )
  )

  defmodule(WsConnection,
    do:
      defstruct(
        initiator_id: nil,
        responder_id: nil,
        initiator_amount: nil,
        responder_amount: nil,
        custom_param_fun: nil
      )
  )

  # TODO bad naming
  defmodule(SyncCall,
    do:
      defstruct(
        request: nil,
        response: nil
      )
  )

  def start_link(
        %{
          pub_key: _pub_key,
          session: session,
          role: role
        } = state_channel_context,
        ws_base,
        network_id,
        connection_callbacks,
        color,
        ws_manager_pid
      ) do
    session_map = init_map(session, role, ws_base)

    ws_url = create_link(ws_base, session_map)
    Logger.debug("start_link #{inspect(ws_url)}", ansi_color: color)

    {:ok, pid} =
      WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{
        struct(__MODULE__, state_channel_context)
        | ws_manager_pid: ws_manager_pid,
          ws_base: ws_base,
          network_id: network_id,
          timer_reference: nil,
          connection_callbacks: connection_callbacks,
          color: [ansi_color: color]
      })

    Logger.debug("started link pid is #{inspect(pid)}", ansi_color: color)
    start_ping(pid)
    {:ok, pid}
  end

  def start_link(
        :reestablish,
        %{
          pub_key: _pub_key,
          role: role,
          channel_id: channel_id,
          round_and_updates: round_and_updates,
          ws_base: ws_base,
          pending_round_and_update: pending_round_and_update,
          fsm_id: fsm_id,
        } = state_channel_context,
        port,
        connection_callbacks,
        color,
        ws_manager_pid
      ) do
    {_round, %Update{state_tx: state_tx}} =
      case {!Enum.empty?(pending_round_and_update), !Enum.empty?(round_and_updates)} do
        {true, _} -> Enum.max(pending_round_and_update)
        {false, true} -> Enum.max(round_and_updates)
        {false, false} -> throw "cannot reestablish no saved state avaliable"
      end

    session_map = init_reestablish_map(channel_id, fsm_id, state_tx, role, ws_base, port)
    ws_url = create_link(state_channel_context.ws_base, session_map)

    Logger.debug("start_link reestablish url: #{inspect(ws_url)}",
      ansi_color: color
    )

    {:ok, pid} =
      WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{
        struct(__MODULE__, state_channel_context)
        | ws_manager_pid: ws_manager_pid,
          timer_reference: nil,
          connection_callbacks: connection_callbacks,
          color: [ansi_color: color]
      })

    Logger.debug("start_link reestablish pid: #{inspect(pid)}",
      ansi_color: color
    )

    start_ping(pid)
    {:ok, pid}

    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end

  # move this and to another file
  def create_solo_close_tx(pub_key, channel_id, state_tx, poienc, nonce, ttl) do
    {_tag, channel} = :aeser_api_encoder.decode(channel_id)
    {:account_pubkey, puk_key_decoded} = :aeser_api_encoder.decode(pub_key)
    {_tag, poiser} = :aeser_api_encoder.decode(poienc)
    poi = :aec_trees.deserialize_poi(poiser)
    {:transaction, binary} = :aeser_api_encoder.decode(state_tx)

    {:ok, aetx} =
      :aesc_close_solo_tx.new(%{
        channel_id: :aeser_id.create(:channel, channel),
        from_id: :aeser_id.create(:account, puk_key_decoded),
        payload: binary,
        # payload: <<>>,
        poi: poi,
        ttl: ttl,
        fee: 300_000 * 1_000_000,
        nonce: nonce
      })

    aetx
  end

  @spec request_state(pid) :: :ok
  def request_state(pid) do
    WebSockex.cast(pid, {:sync_state})
  end

  @spec close_connection(pid) :: :ok
  def close_connection(pid) do
    WebSockex.cast(pid, {:close_connection})
  end

  @spec start_ping(pid) :: :ok
  def start_ping(pid) do
    WebSockex.cast(pid, {:ping})
  end

  @spec close_solo(pid) :: :ok
  def close_solo(pid) do
    WebSockex.cast(pid, {:close_solo})
  end

  @spec initiate_transfer(pid, integer) :: :ok
  def initiate_transfer(pid, amount) do
    WebSockex.cast(pid, {:transfer, amount})
  end

  @spec abort(pid, String.t(), integer, String.t()) :: :ok
  def abort(pid, method, abort_code, abort_message) do
    WebSockex.cast(pid, {:abort, method, abort_code, abort_message})
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

  @spec new_contract(pid, {binary(), String.t(), map()}, integer) :: :ok
  def new_contract(pid, contract, amount \\ 0) do
    WebSockex.cast(pid, {:new_contract, contract, amount})
  end

  @spec call_contract(pid, {binary, String.t(), map()}, binary(), binary(), integer) :: :ok
  def call_contract(pid, contract, fun, args, amount \\ 0) do
    WebSockex.cast(pid, {:call_contract, contract, fun, args, amount})
  end

  @spec get_contract_reponse(pid, {binary(), String.t(), map()}, binary(), pid) :: :ok
  def get_contract_reponse(pid, contract, fun, from \\ nil) do
    WebSockex.cast(pid, {:get_contract_reponse, contract, fun, from})
  end

  @spec get_poi(pid, pid) :: :ok
  def get_poi(pid, from \\ nil) do
    WebSockex.cast(pid, {:get_poi, from})
  end

  @spec slash(pid, pid) :: :ok
  def slash(pid, from \\ nil) do
    WebSockex.cast(pid, {:slash, from})
  end

  @spec settle(pid, pid) :: :ok
  def settle(pid, from \\ nil) do
    WebSockex.cast(pid, {:settle, from})
  end

  @spec send_signed_message(pid, String.t(), <<>>) :: :ok
  def send_signed_message(pid, method, payload) do
    WebSockex.cast(pid, {:signed_payload, method, payload})
  end

  # Server side

  def terminate(reason, _state)
      when reason in [{:local, :normal}, {:remote, :closed}, {:remote, 1000, ""}] do
    # silent, all good
    exit(:normal)
  end

  def terminate(reason, state) do
    super(reason, state)
  end

  def handle_connect(conn, state) do
    Logger.info("Connected! #{inspect(conn)} #{inspect(self())}", state.color)
    produce_callback(:connection_update, {:connected, nil}, state)
    {:ok, state}
  end

  def handle_cast({:ping}, state) do
    get_timer = fn timer ->
      case timer do
        nil ->
          {:ok, t_ref} =
            :timer.apply_interval(
              :timer.seconds(state.socket_ping_intervall),
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

  def handle_cast({:close_connection}, state) do
    {:close, state}
  end

  def handle_cast({:close_solo}, state) do
    request = build_request("channels.close_solo", %{})
    Logger.info("=> close_solo #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:sync_state}, state) do
    sync_state(state)
    {:ok, state}
  end

  def handle_cast({:transfer, amount}, state) do
    sync_call = %SyncCall{request: request} = transfer_from(amount, state)

    Logger.info("=> transfer #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{state | pending_id: Map.get(sync_call, :id, nil), sync_call: sync_call}}
  end

  def handle_cast({:abort, method, abort_code, _abort_message}, state) do
    request = build_message(method, %{error: abort_code})
    Logger.info("=> abort #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:deposit, amount}, state) do
    request =
      build_request("channels.deposit", %{
        amount: amount
      })

    Logger.info("=> deposit #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:withdraw, amount}, state) do
    request =
      build_request("channels.withdraw", %{
        amount: amount
      })

    Logger.info("=> withdraw #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:query_funds, from_pid}, state) do
    sync_call = %SyncCall{request: request} = request_funds(state, from_pid)

    Logger.info("=> query_funds #{inspect(request)}", state.color)

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
    request = build_request("channels.shutdown")
    Logger.info("=> shutdown #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:leave, {}}, state) do
    request = build_request("channels.leave")
    Logger.info("=> leave #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  def handle_cast({:new_contract, {_pub_key, contract_file, %{backend: backend} = config}, amount}, state) do
    {:ok, map} = :aeso_compiler.file(contract_file, [{:backend, backend}])
    encoded_bytecode = :aeser_api_encoder.encode(:contract_bytearray, :aect_sophia.serialize(map, 3))

    {:ok, call_data} = :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'init', [], [{:backend, backend}])

    encoded_calldata = :aeser_api_encoder.encode(:contract_bytearray, call_data)
    request = new_contract_req(%{code: encoded_bytecode, call_data: encoded_calldata, deposit: amount, abi_version: config.abi_version, vm_version: config.vm_version})
    Logger.info("=> new contract #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)}, %__MODULE__{state | pending_id: Map.get(request, :id, nil)}}
  end

  defp transfer_from(amount, state) do
    case state.role do
      :initiator ->
        transfer_amount(
          state.session.basic_configuration.initiator_id,
          state.session.basic_configuration.responder_id,
          amount
        )

      :responder ->
        transfer_amount(
          state.session.basic_configuration.responder_id,
          state.session.basic_configuration.initiator_id,
          amount
        )
    end
  end

  # returns all the contracts which mathes... remember same contract can be deploy several times.
  def calculate_contract_address({owner, contract_file, config}, updates) do
    {:ok, map} = :aeso_compiler.file(contract_file, [{:backend, config.backend}])

    encoded_bytecode = :aeser_api_encoder.encode(:contract_bytearray, :aect_sophia.serialize(map, 3))

    {:account_pubkey, contract_owner} = :aeser_api_encoder.decode(owner)
    # beware this code assumes that length(updates) == 1
    for {round,
         %Update{
           updates: [
             %{
               "op" => "OffChainNewContract",
               "owner" => ^owner,
               "code" => ^encoded_bytecode
             }
           ]
         }} <- updates,
        do:
          {round,
           :aeser_api_encoder.encode(
             :contract_pubkey,
             :aect_contracts.compute_contract_pubkey(contract_owner, round)
           )}
  end

  def find_contract_calls(caller, contract_pubkey, updates) do
    Logger.debug("Looking for contract with #{inspect(contract_pubkey)} caller #{inspect(caller)}")

    for {round,
         %Update{
           updates: [
             %{
               "op" => "OffChainCallContract",
               "contract_id" => ^contract_pubkey,
               "caller_id" => ^caller
             }
           ]
         }} <- updates,
        do: round
  end

  # get inspiration here: https://github.com/aeternity/aesophia/blob/master/test/aeso_abi_tests.erl#L99
  # TODO should we expose round to the client, or some helper to get all contracts back.
  # example [int, string]: :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), 'main', ['2', '\"foobar\"']
  def handle_cast({:call_contract, {pub_key, contract_file, config} = contract, fun, args, amount}, state) do
    {:ok, call_data} = :aeso_compiler.create_calldata(to_charlist(File.read!(contract_file)), fun, args, [{:backend, config.backend}])

    contract_list = calculate_contract_address(contract, state.round_and_updates)

    [{_max_round, contract_pubkey} | _t] =
      Enum.sort(contract_list, fn {round_1, _b}, {round_2, _b2} -> round_1 > round_2 end)

    encoded_calldata = :aeser_api_encoder.encode(:contract_bytearray, call_data)
    contract_call_in_flight = {encoded_calldata, contract_pubkey, fun, args, contract}

    request = call_contract_req(contract_pubkey, config.abi_version, encoded_calldata, amount)
    Logger.info("=> call contract #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         contract_call_in_flight: contract_call_in_flight
     }}
  end

  # TODO we know what fun was called. Allow this to get older results?
  def handle_cast({:get_contract_reponse, contract, _fun, from_pid}, state) do
    contract_list = calculate_contract_address(contract, state.round_and_updates)

    [{_max_round, contract_pubkey} | _t] = Enum.sort(contract_list, fn {a, _b}, {a2, _b2} -> a > a2 end)

    rounds = find_contract_calls(state.pub_key, contract_pubkey, state.round_and_updates)
    # TODO now we per default get the last call, until we expose round to client.
    max_round = Enum.max(rounds)

    sync_call =
      %SyncCall{request: request} =
      get_contract_response_query(
        contract_pubkey,
        state.pub_key,
        max_round,
        from_pid
      )

    Logger.info("=> get contract #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         contract_call_in_flight_round: max_round,
         sync_call: sync_call
     }}
  end

  def handle_cast({:get_poi, from_pid}, state) do
    # contract_list = calculate_contract_address({pub_key, contract_file}, state.round_and_updates)

    sync_call =
      %SyncCall{request: request} =
      get_poi_response_query(
        [
          state.session.basic_configuration.initiator_id,
          state.session.basic_configuration.responder_id
        ],
        [],
        from_pid
      )

    Logger.info("=> get poi #{inspect(request)}", state.color)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         sync_call: sync_call
     }}
  end

  def handle_cast({:slash, from_pid}, state) do
    sync_call = %SyncCall{request: request} = slash_query(from_pid)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         sync_call: sync_call
     }}
  end

  def handle_cast({:settle, from_pid}, state) do
    sync_call = %SyncCall{request: request} = settle_query(from_pid)

    {:reply, {:text, Poison.encode!(request)},
     %__MODULE__{
       state
       | pending_id: Map.get(request, :id, nil),
         sync_call: sync_call
     }}
  end

  def handle_cast(
        {:signed_payload, method, signed_payload},
        %__MODULE__{pending_round_and_update: pending_round_and_update} = state
      )
      when pending_round_and_update != %{} do
    [{round, update}] = Map.to_list(state.pending_round_and_update)

    {:reply, {:text, Poison.encode!(build_message(method, %{signed_tx: signed_payload}))},
     %__MODULE__{state | pending_round_and_update: %{round => %Update{update | state_tx: signed_payload}}}}
  end

  def handle_cast(
        {:signed_payload, method, signed_payload},
        state
      ) do
    {:reply, {:text, Poison.encode!(build_message(method, %{signed_tx: signed_payload}))}, state}
  end

  def build_request(method, params \\ %{}) do
    default_params =
      case method do
        # here we could do custom thing e.g. simpler method names
        # "channels.get.balances" -> %{jsonrpc: "2.0", method: method}
        _ -> %{}
      end

    %{params: Map.merge(default_params, params), method: method, jsonrpc: "2.0"}
  end

  def build_message(method, params \\ %{}) do
    string_replace = ".sign"

    {reply_method, reply_params} =
      case String.contains?(method, string_replace) do
        true ->
          {String.replace(method, string_replace, ""), %{}}

        false ->
          throw("this is not a sign request method. Method is: #{inspect(method)}")
      end

    %{params: Map.merge(reply_params, params), method: reply_method, jsonrpc: "2.0"}
  end

  # async methods are suffixed with .reply, the same pattern is used here for increased readabiliy
  def process_response(method, from_pid) do
    case method <> ".reply" do
      "channels.get.contract_call.reply" ->
        fn %{"result" => result}, state ->
          {result, state_updated} = process_get_contract_reponse(result, state)
          GenServer.reply(from_pid, result)
          {result, state_updated}
        end

      "channels.get.poi.reply" ->
        fn %{"result" => result}, state ->
          {result, state_updated} = process_get_poi_response(result, state)
          GenServer.reply(from_pid, result)
          {result, state_updated}
        end

      "channels.get.balances.reply" ->
        fn %{"result" => result}, state ->
          GenServer.reply(from_pid, result)
          {result, state}
        end

      "channels.get.offchain_state.reply" ->
        fn %{"result" => result}, state ->
          GenServer.reply(from_pid, result)
          {result, state}
        end

      "channels.slash.reply" ->
        fn %{"result" => result}, state ->
          GenServer.reply(from_pid, result)
          {result, state}
        end

      "channels.sign.settle_sign.reply" ->
        fn %{"result" => result}, state ->
          {result, state_updated} = process_get_settle_reponse(result, state)
          GenServer.reply(from_pid, result)
          {result, state_updated}
        end
    end
  end

  # https://github.com/aeternity/protocol/blob/master/node/api/examples/channels/json-rpc/sc_ws_close_mutual.md#initiator-----node-5
  def request_funds(state, from_pid) do
    %WsConnection{initiator_id: initiator, responder_id: responder} = state.session.basic_configuration

    make_sync(
      from_pid,
      %SyncCall{
        request:
          build_request("channels.get.balances", %{
            accounts: [initiator, responder]
          }),
        response: process_response("channels.get.balances", from_pid)
      }
    )
  end

  def transfer_amount(from, to, amount) do
    %SyncCall{
      request:
        build_request("channels.update.new", %{
          from: from,
          to: to,
          amount: amount
        }),
      response: nil
    }
  end

  def get_offchain_state_query(from_pid) do
    make_sync(from_pid, %SyncCall{
      request: build_request("channels.get.offchain_state"),
      response: process_response("channels.get.offchain_state", from_pid)
    })
  end

  def new_contract_req(map) do
    build_request("channels.update.new_contract", map)
  end

  def call_contract_req(address, abi_version, call_data, amount) do
    build_request("channels.update.call_contract", %{
      abi_version: abi_version,
      amount: amount,
      call_data: call_data,
      contract_id: address
    })
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

  def get_poi_response_query(accounts, contracts, from_pid) do
    make_sync(
      from_pid,
      %SyncCall{
        request:
          build_request("channels.get.poi", %{
            accounts: accounts,
            contracts: contracts
          }),
        response: process_response("channels.get.poi", from_pid)
      }
    )
  end

  def slash_query(from_pid) do
    make_sync(
      from_pid,
      %SyncCall{
        request: build_request("channels.slash"),
        response: process_response("channels.slash", from_pid)
      }
    )
  end

  def settle_query(from_pid) do
    make_sync(
      from_pid,
      %SyncCall{
        request: build_request("channels.settle"),
        response: process_response("channels.sign.settle_sign", from_pid)
      }
    )
  end

  def get_contract_response_query(address, caller, round, from_pid) do
    make_sync(
      from_pid,
      %SyncCall{
        request:
          build_request("channels.get.contract_call", %{
            caller_id: caller,
            contract_id: address,
            round: round
          }),
        response: process_response("channels.get.contract_call", from_pid)
      }
    )
  end

  def handle_frame({:text, msg}, state) do
    message = Poison.decode!(msg)

    Logger.info("Received Message: #{inspect(msg)} #{inspect(message)} #{inspect(self())}", state.color)
    process_message(message, state)
  end

  def sync_state(state) do
    sync_state = Enum.reduce(@persist_keys, %{}, fn(key, acc) -> Map.put(acc, key, Map.get(state, key)) end)
    GenServer.cast(state.ws_manager_pid, {:state_tx_update, sync_state})
  end

  defp clean_and_exit(state, reason) do
    :timer.cancel(state.timer_reference)
    produce_callback(:connection_update, {:disconnected, reason}, state)
    sync_state(state)
  end

  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local close with reason: #{inspect(reason)}", state.color)
    clean_and_exit(state, reason)
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    Logger.info("disconnecting... #{inspect({self(), state})}", state.color)
    clean_and_exit(state, nil)
    super(disconnect_map, state)
  end

  # ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=responder
  # ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&host=localhost&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=initiator
  def init_reestablish_map(channel_id, fsm_id, offchain_tx, role, _host_url, port) do
    same = %{
      existing_channel_id: channel_id,
      existing_fsm_id: fsm_id,
      offchain_tx: offchain_tx,
      protocol: "json-rpc",
      port: port,
      role: role
    }

    role_map =
      case role do
        :initiator ->
          # TODO Workaound to be able to connect to node
          # %URI{host: host} = URI.parse(host_url)
          # %{host: host}
          %{host: "localhost"}

        _ ->
          %{}
      end

    Map.merge(same, role_map)
  end

  def init_map(
        %{basic_configuration: basic_configuration, custom_param_fun: custom_param_fun},
        role,
        host_url
      ) do
    custom = custom_param_fun.(role, host_url)
    same = Map.from_struct(basic_configuration)
    Map.merge(same, custom)
  end

  def create_link(base_url, params) do
    base_url
    |> URI.parse()
    |> Map.put(:query, URI.encode_query(params))
    |> URI.to_string()
  end

  # these doesn't contain round...
  def process_message(
        %{
          "method" => method,
          "params" => %{"data" => %{"signed_tx" => to_sign}}
        } = _message,
        state
      )
      when method in [
             "channels.sign.close_solo_sign",
             "channels.sign.slash_tx",
             "channels.sign.settle_sign",
             "channels.sign.shutdown_sign",
             "channels.sign.shutdown_sign_ack"
           ] do

    Validator.notify_sign_transaction(to_sign, method, state)
    {:ok, state}
  end

  @self [
    "channels.sign.update",
    "channels.sign.initiator_sign",
    "channels.sign.deposit_tx",
    "channels.sign.withdraw_tx"
  ]
  @other [
    "channels.sign.update_ack",
    "channels.sign.responder_sign",
    "channels.sign.deposit_ack",
    "channels.sign.withdraw_ack"
  ]

  def process_message(
        %{
          "method" => method,
          "params" => %{"data" => %{"signed_tx" => to_sign, "updates" => updates}}
        } = _message,
        state
      )
      when method in @other
      when method in @self do
    round_initiator =
      case {method in @self, method in @other} do
        {true, false} -> :self
        {false, true} -> :other
        _ -> throw("no matching method, can not happen")
      end

    pending_update = %Update{
      updates: updates,
      tx: to_sign,
      contract_call: state.contract_call_in_flight,
      round_initiator: round_initiator
    }

    Validator.notify_sign_transaction(pending_update, method, state)

    {:ok,
     %__MODULE__{
       state
       | pending_round_and_update: %{
           #  TODO not sure on state_tx naming here...
           Validator.get_state_round(to_sign) => %Update{pending_update | state_tx: nil}
         }
     }}
  end

  def process_get_settle_reponse(
        %{"signed_tx" => _signed_tx} = _data,
        state
      ) do
    {:not_implemented, state}
  end

  def process_get_contract_reponse(
        %{"return_value" => return_value, "contract_id" => _contract_id} = _data,
        state
      ) do
    {:contract_bytearray, deserialized_return} = :aeser_api_encoder.decode(return_value)

    %Update{contract_call: {_encoded_calldata, _contract_pubkey, fun, _args, {pub_key, contract_file, config}}} =
      Map.get(state.round_and_updates, state.contract_call_in_flight_round)

    # TODO well consider using contract_id. If this user called the contract the function is in the state.round_and_updates
    sophia_value =
      :aeso_compiler.to_sophia_value(
        to_charlist(File.read!(contract_file)),
        fun,
        :ok,
        deserialized_return, [{:backend, config.backend}]
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
      "contract call async reply (as result of calling: not present): #{inspect(sophia_value)}",
      state.color
    )

    {:ok, state_update}
  end

  def process_message(
        %{
          "method" => "channels.get.poi.reply",
          "params" => %{
            # "data" => %{"return_value" => return_value, "return_type" => _return_type}
            "data" => data
          }
        } = _message,
        state
      ) do
    {return, state_update} = process_get_poi_response(data, state)

    Logger.debug(
      "poi call async reply : #{inspect(return)}",
      state.color
    )

    {:ok, state_update}
  end

  def process_get_poi_response(
        %{"poi" => poi} = _data,
        state
      ) do
    {round, %Update{} = update} = Enum.max(state.round_and_updates)
    update_new = Map.put(update, :poi, poi)

    {poi, %__MODULE__{state | round_and_updates: Map.put(state.round_and_updates, round, update_new)}}
  end

  def process_message(%{"channel_id" => _channel_id, "error" => _error_struct} = error, state) do
    Logger.error("error")
    Logger.info("<= error unprocessed message: #{inspect(error)}", state.color)
    {:error, state}
  end

  # This is where we get syncrouns responses back
  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state)
      when id == pending_id do
    {_result, updated_state} =
      case state.sync_call do
        %SyncCall{response: response} ->
          case response do
            nil ->
              Logger.error("Not implemented received data is: #{inspect(query_reponse)}")
              {:error, state}

            _ ->
              response.(query_reponse, state)
          end

        %{} ->
          Logger.error("Unexpected id match: #{inspect(query_reponse)}")
          {:ok, state}
      end

    {:ok, %__MODULE__{updated_state | sync_call: %{}}}
  end

  # wrong unexpected id in response.
  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state)
      when id != pending_id do
    Logger.error("<= Failed match id, response: #{inspect(query_reponse)} pending id is: #{inspect(pending_id)}")

    {:error, state}
  end

  def check_updated(state_tx, pending_map) do
    round = Validator.get_state_round(state_tx)

    case Map.get(pending_map, round) do
      nil ->
        # Once the pending is well designed we should likely never end up here.
        %{round => %Update{state_tx: state_tx}}

      update ->
        # state_tx == update.state_tx, should match only when the pending payload was cosigned.
        %{round => %Update{update | state_tx: state_tx}}
    end
  end

  def produce_callback(type, state, round, method)
      when type in [:channels_update, :channels_info, :on_chain] do
    case state.connection_callbacks do
      nil ->
        :ok

      _ ->
        %Update{round_initiator: round_initiator} =
          Map.get(state.pending_round_and_update, round, %Update{round_initiator: :transient})

        callback = Map.get(state.connection_callbacks, type)
        callback.(round_initiator, round, method)
        :ok
    end
  end

  def produce_callback(:connection_update, {action, reason}, state) do
    case state.connection_callbacks do
      nil ->
        :ok
      _ ->
        callback = Map.get(state.connection_callbacks, :connection_update)
        callback.(action, reason)
        :ok
    end
  end

  def process_message(
        %{
          "method" => method,
          "params" => %{"channel_id" => channel_id, "data" => %{"state" => state_tx}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when method in ["channels.leave", "channels.update"]
      when channel_id == current_channel_id do
    updates = check_updated(state_tx, state.pending_round_and_update)

    Logger.debug(
      "Map length #{inspect(length(Map.to_list(state.round_and_updates)))} round is: #{
        Validator.get_state_round(state_tx)
      } update is: #{inspect(updates != %{})}",
      state.color
    )

    produce_callback(:channels_update, state, Validator.get_state_round(state_tx), method)

    new_state = %__MODULE__{
      state
      | round_and_updates: Map.merge(state.round_and_updates, updates),
        pending_round_and_update: %{}
    }

    {:ok, new_state}
  end

  def process_message(
        %{
          "method" => "channels.conflict" = method,
          "params" => %{
            "channel_id" => channel_id,
            "data" => %{"round" => round, "channel_id" => channel_id2}
          }
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id and channel_id == channel_id2 do
    # The conflist arised on the upcoming round which is + 1
    produce_callback(:channels_update, state, round + 1, method)
    {:ok, state}
  end

  defmacro is_first_update(stored_id, new_id) do
    quote do
      unquote(stored_id) == nil and unquote(new_id) != nil
    end
  end


  # %{"jsonrpc" => "2.0", "method" => "channels.info", "params" => %{"channel_id" => nil, "data" => %{"event" => "fsm_up", "fsm_id" => "ba_fVV9rUl9X6OG/fzAbSsxIjQCqwaPlgxNCgJWIF3cIvOqliqv"}}, "version" => 1}

  def process_message(
        %{
          "method" => "channels.info",
          "params" => %{"channel_id" => _channel_id, "data" => %{"event" => "fsm_up" = event, "fsm_id" => fsm_id}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      do
      # TODO https://github.com/aeternity/aeternity/issues/3027
      # when channel_id == current_channel_id or is_first_update(current_channel_id, channel_id) do
    produce_callback(:channels_info, state, 0, event)
    # manual sync, this is particullary intersting, this is needed for future reconnects

    # TODO https://github.com/aeternity/aeternity/issues/3027
    # new_state = %__MODULE__{state | channel_id: channel_id, fsm_id: fsm_id}
    new_state = %__MODULE__{state | fsm_id: fsm_id}
    sync_state(new_state)
    {:ok, new_state}
  end

  def process_message(
        %{
          "method" => "channels.info",
          "params" => %{"channel_id" => channel_id, "data" => %{"event" => event}}
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id or is_first_update(current_channel_id, channel_id) do
    produce_callback(:channels_info, state, 0, event)
    new_state = %__MODULE__{state | channel_id: channel_id}
    sync_state(new_state)
    {:ok, new_state}
  end

  def process_message(
        %{"method" => "channels.info", "params" => %{"channel_id" => channel_id}} = message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id do
    Logger.debug("channels.info: #{inspect(message)}", state.color)
    {:error, state}
  end

  def process_message(
        %{
          "method" => "channels.on_chain_tx",
          "params" => %{
            "channel_id" => channel_id,
            "data" => %{"tx" => signed_tx, "info" => info}
          }
        } = _message,
        %__MODULE__{channel_id: current_channel_id} = state
      )
      when channel_id == current_channel_id or is_first_update(current_channel_id, channel_id) do
    # Produces some logging output.
    produce_callback(:on_chain, state, 0, info)
    Validator.verify_on_chain(signed_tx, state.ws_base)
    {:ok, %__MODULE__{state | channel_id: channel_id}}
  end

  def process_message(message, state) do
    Logger.error("<= unprocessed message recieved by #{inspect(state.role)}. message: #{inspect(message)}")

    {:ok, state}
  end
end
