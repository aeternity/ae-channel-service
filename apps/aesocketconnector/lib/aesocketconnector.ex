defmodule AeSocketConnector do
  use WebSockex
  require Logger

# inspiration https://github.com/aeternity/protocol/blob/057815233d72af035c13a13e8fb4d0e26515c2fc/node/api/examples/channels/json-rpc/sc_ws_basic_open_close.md

  defstruct [
    pub_key: nil,
    priv_key: nil,
    role: nil,
    session: %{}, # WsConnection{},
    color: nil,
    channel_id: nil,
    pending_id: nil,
    ws_manager_pid: nil,
    state_tx: nil,
  ]


  defmodule WsConnection, do: defstruct [
    initiator: nil,
    responder: nil,
    initiator_amount: nil,
    responder_amount: nil
  ]

  @network_id "my_test"

  def start_link(_name, %__MODULE__{pub_key: _pub_key, priv_key: _priv_key, session: %WsConnection{initiator: initiator, responder: responder, initiator_amount: initiator_amount, responder_amount: responder_amount}, role: role} = state_channel_context, ws_base, color, ws_manager_pid) do
    initiator_id = :aeser_api_encoder.encode(:account_pubkey, initiator)
    responder_id = :aeser_api_encoder.encode(:account_pubkey, responder)
    session_map = init_map(initiator_id, responder_id, initiator_amount, responder_amount, role)
    ws_url = create_link(ws_base, session_map)
    Logger.debug "start_link #{inspect ws_url}", [ansi_color: color]
    WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{state_channel_context | ws_manager_pid: ws_manager_pid, color: [ansi_color: color]})
    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end

  def start_link(_name, %__MODULE__{state_tx: nil}, _ws_base, :reestablish, color, _ws_manager_pid) do
    Logger.error "cannot reconnect", [ansi_color: color]
    {:ok, nil}
    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
  end


  def start_link(_name, %__MODULE__{pub_key: _pub_key, role: role, channel_id: channel_id, state_tx: state_tx} = state_channel_context, ws_base, :reestablish, color, ws_manager_pid) do
    session_map = init_reestablish_map(channel_id, state_tx, role)
    ws_url = create_link(ws_base, session_map)
    Logger.debug "start_link reestablish #{inspect ws_url}", [ansi_color: color]
    WebSockex.start_link(ws_url, __MODULE__, %__MODULE__{state_channel_context | ws_manager_pid: ws_manager_pid, color: [ansi_color: color]})
    # WebSockex.start_link(ws_url, __MODULE__, %{priv_key: priv_key, pub_key: pub_key, role: role, session: state_channel_context, color: [ansi_color: color]}, name: name)
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

  @spec query_funds(pid) :: :ok
  def query_funds(pid) do
    WebSockex.cast(pid, {:query_funds, {}})
  end

  @spec get_offchain_state(pid) :: :ok
  def get_offchain_state(pid) do
    WebSockex.cast(pid, {:get_offchain_state, {}})
  end

  @spec shutdown(pid) :: :ok
  def shutdown(pid) do
    WebSockex.cast(pid, {:shutdown, {}})
  end

  @spec leave(pid) :: :ok
  def leave(pid) do
    WebSockex.cast(pid, {:leave, {}})
  end

# server side

  def handle_connect(_conn, state) do
    # Logger.info("Connected! #{inspect conn}")
    {:ok, state}
  end

  def handle_cast({:transfer, amount}, state) do
    transfer = transfer_amount(state.session.initiator, state.session.responder, amount)
    Logger.info("=> transfer #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:deposit, amount}, state) do
    transfer = deposit(amount)
    Logger.info("=> deposit #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:withdraw, amount}, state) do
    transfer = withdraw(amount)
    Logger.info("=> withdraw #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:query_funds, {}}, state) do
    transfer = request_funds(state)
    Logger.info("=> query funds #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:get_offchain_state, {}}, state) do
    transfer = get_offchain_state()
    Logger.info("=> get_offchain_state #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:shutdown, {}}, state) do
    transfer = shutdown()
    Logger.info("=> shutdown #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end

  def handle_cast({:leave, {}}, state) do
    transfer = leave()
    Logger.info("=> leave #{inspect transfer}", state.color)
    {:reply, {:text, Poison.encode!(transfer)}, %__MODULE__{state | pending_id: Map.get(transfer, :id, nil)}}
  end


  # https://github.com/aeternity/protocol/blob/master/node/api/examples/channels/json-rpc/sc_ws_close_mutual.md#initiator-----node-5
  def request_funds(state) do
    %WsConnection{initiator: initiator, responder: responder} = state.session
    account_initiator = :aeser_api_encoder.encode(:account_pubkey, initiator)
    account_responder = :aeser_api_encoder.encode(:account_pubkey, responder)
    %{jsonrpc: "2.0", id: :erlang.unique_integer([:monotonic]), method: "channels.get.balances", params: %{accounts: [account_initiator, account_responder]}}
  end

  # TODO only possible on one direction!
  def transfer_amount(from, to, amount) do
    account_from = :aeser_api_encoder.encode(:account_pubkey, from)
    account_to = :aeser_api_encoder.encode(:account_pubkey, to)
    %{
      jsonrpc: "2.0",
      id: :erlang.unique_integer([:monotonic]),
      method: "channels.update.new",
      params: %{
        from: account_from,
        to: account_to,
        amount: amount
      }
    }
  end

  def get_offchain_state() do
    %{
      id: :erlang.unique_integer([:monotonic]),
      jsonrpc: "2.0",
      method: "channels.get.offchain_state",
      params: %{}
    }
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


  # def handle_frame({:text, "Can you please reply yourself?" = msg}, state) do
  #   Logger.info("Received Message: #{msg}")
  #   msg = "Sure can!"
  #   Logger.info("Sending message: #{msg}")
  #   {:reply, {:text, msg}, state}
  # end
  #
  #
  # def handle_frame({:text, "Can you please reply yourself?" = msg}, state) do
  #   Logger.info("Received Message: #{msg}")
  #   msg = "Sure can!"
  #   Logger.info("Sending message: #{msg}")
  #   {:reply, {:text, msg}, state}
  # end
  #
  # def handle_frame({:text, "Close the things!" = msg}, state) do
  #   Logger.info("Received Message: #{msg}")
  #   {:close, state}
  # end

  def handle_frame({:text, msg}, state) do
    message = Poison.decode!(msg)
    # Logger.info("Received Message: #{inspect msg} #{inspect message} #{inspect self()}")
    process_message(message, state)
    # {:ok, state}
  end

  def handle_disconnect(%{reason: {:local, reason}}, state) do
    Logger.info("Local close with reason: #{inspect(reason)}", state.color)
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    Logger.info("disconnected...", state.color)
    GenServer.call(state.ws_manager_pid, {:connection_dropped, state})
    super(disconnect_map, state)
  end

# ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=responder
# ws://localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&host=localhost&offchain_tx=tx_%2BQENCwH4hLhAP%2BEiPpXFO80MdqGnw6GkaAYpOHCvcP%2FKBKJZ5IIicYBItA9s95zZA%2BRX1DNNheorlbZYKHctN3ZyvKnsFa7HDrhAYqWNrW8oDAaLj0JCUeW0NfNNhs4dKDJoHuuCdWhnX4r802c5ZAFKV7EV%2FmHihVXzgLyaRaI%2FSVw2KS%2Bz471bAriD%2BIEyAaEBsbV3vNMnyznlXmwCa9anShs13mwGUMSuUe%2BrdZ5BW2aGP6olImAAoQFnHFVGRklFdbK0lPZRaCFxBmPYSJPN0tI2A3pUwz7uhIYkYTnKgAACCgCGEjCc5UAAwKCjPk7CXWjSHTO8V2Y9WTad6D%2F5sB8yCR8WumWh0WxWvwdz6zEk&port=12341&protocol=json-rpc&role=initiator
  def init_reestablish_map(channel_id, offchain_tx, role) do
    initiator = %{host: "localhost", role: "initiator"}
    responder = %{role: "responder"}
    same =
    %{
      existing_channel_id: channel_id,
      offchain_tx: offchain_tx,
      protocol: "json-rpc",
      port: "12341",
    }
    role_map = case role do
      :initiator -> initiator
      :responder -> responder
    end
    Map.merge(same, role_map)
  end

  def init_map(initiator_id, responder_id, initiator_amount, responder_amount, role) do
    initiator = %{host: "localhost", role: "initiator"}
    responder = %{role: "responder"}
    same =
      %{
      channel_reserve: "2",
      initiator_amount: initiator_amount,
      initiator_id: initiator_id,
      lock_period: "10",
      port: "12340",
      protocol: "json-rpc",
      push_amount: "1",
      responder_amount: responder_amount,
      responder_id: responder_id}
    role_map = case role do
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

  defp sign_transaction_perform(to_sign, state, verify_hook \\ fn(_tx, _state) -> :unsecure end) do
    {:ok, create_bin_tx} = :aeser_api_encoder.safe_decode(:transaction, to_sign)
    tx = :aetx.deserialize_from_binary(create_bin_tx) # returns #aetx
    case verify_hook.(tx, state) do
      :unsecure ->
        ""
      :ok ->
      # bin = :aetx.serialize_to_binary(tx)
        bin = create_bin_tx
        bin_for_network = <<@network_id::binary, bin::binary>>
        result_signed = :enacl.sign_detached(bin_for_network, state.priv_key)
        signed_create_tx = :aetx_sign.new(tx, [result_signed])
        :aeser_api_encoder.encode(:transaction, :aetx_sign.serialize_to_binary(signed_create_tx))
    end
  end

  defp sign_transaction(to_sign, authenticator, state, [method: method, logstring: logstring]) do
    enc_signed_create_tx = sign_transaction_perform(to_sign, state, authenticator)
    response = %{jsonrpc: "2.0", method: method, params: %{tx: enc_signed_create_tx}}
    Logger.debug "=>#{inspect logstring} : #{inspect response} #{inspect self()}", state.color
    response
  end

  # shot this curl to check wheater onchain is alright....
  defp verify_on_chain(tx) do
    {:ok, signed_tx} = :aeser_api_encoder.safe_decode(:transaction, tx)
    deserialized_tx = :aetx_sign.deserialize_from_binary(signed_tx)
    tx_hash = :aetx_sign.hash(deserialized_tx)
    serialized_hash = :aeser_api_encoder.encode(:tx_hash, tx_hash)
    url_to_check = "http://localhost:3013/v2/transactions/" <> URI.encode(serialized_hash)
    Logger.debug "url to check: curl #{inspect url_to_check}"
  end

  def process_message(%{"method" => "channels.info", "params" => %{"channel_id" => channel_id, "data" => %{"event" => "funding_locked"}}} = _message, state) do
    {:ok, %__MODULE__{state | channel_id: channel_id}}
  end

  def process_message(%{"method" => "channels.sign.initiator_sign", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, &AeValidator.inspect_sign_request/2, state, [method: "channels.initiator_sign", logstring: "initiator_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.responder_sign", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, &AeValidator.inspect_sign_request/2, state, [method: "channels.responder_sign", logstring: "responder_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.deposit_tx", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.deposit_tx", logstring: "initiator_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.deposit_ack", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.deposit_ack", logstring: "responder_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.withdraw_tx", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.withdraw_tx", logstring: "initiator_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.withdraw_ack", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.withdraw_ack", logstring: "responder_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  # def process_message(%{"method" => "channels.sign.responder_sign", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
  #   response = sign_transaction(to_sign, &AeValidator.inspect_sign_request/2, state, [method: "channels.responder_sign", logstring: "responder_sign"])
  #   {:reply, {:text, Poison.encode!(response)}, state}
  # end

  def process_message(%{"method" => "channels.sign.shutdown_sign", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.shutdown_sign", logstring: "initiator_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.shutdown_sign_ack", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, (fn(_a, _b) -> :ok end), state, [method: "channels.shutdown_sign_ack", logstring: "initiator_sign"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.sign.update", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, &AeValidator.inspect_transfer_request/2, state, [method: "channels.update", logstring: "initiator_sign_update"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"channel_id" => _channel_id, "error" => _error_struct} = error, state) do
    Logger.error "<= error unprocessed message: #{inspect error}"
    {:ok, state}
  end

  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state) when (id == pending_id)  do
    Logger.info "<= matched id, response: #{inspect query_reponse}", state.color
    {:ok, state}
  end

  # wrong unexpected id in response.
  def process_message(%{"id" => id} = query_reponse, %__MODULE__{pending_id: pending_id} = state) when (id != pending_id)  do
    Logger.error "<= Failed match id, response: #{inspect query_reponse} #{inspect pending_id}"
    {:ok, state}
  end

  def process_message(%{"method" => "channels.update", "params" => %{"channel_id" => channel_id, "data" => %{"state" => state_tx}}} = _message, %__MODULE__{channel_id: current_channel_id} = state) when (channel_id == current_channel_id) do
    log_string =
      case (state_tx == state.state_tx) do
        true -> "unchanged, state is #{inspect state_tx}"
        false -> "updated, state is #{inspect state_tx} old was #{inspect state.state_tx}"
      end
    Logger.debug("= channels.update: " <> log_string, state.color)
    {:ok, %__MODULE__{state | state_tx: state_tx}}
  end

  def process_message(%{"method" => "channels.sign.update_ack", "params" => %{"data" => %{"tx" => to_sign}}} = _message, state) do
    response = sign_transaction(to_sign, &AeValidator.inspect_transfer_request/2, state, [method: "channels.update_ack", logstring: "responder_sign_update"])
    {:reply, {:text, Poison.encode!(response)}, state}
  end

  def process_message(%{"method" => "channels.info", "params" => %{"channel_id" => channel_id}} = _message, %__MODULE__{channel_id: current_channel_id} = state) when (channel_id == current_channel_id) do
    {:ok, state}
  end

  def process_message(%{"method" => "channels.on_chain_tx", "params" => %{"channel_id" => channel_id, "data" => %{"tx" => signed_tx}}} = _message, %__MODULE__{channel_id: current_channel_id} = state) when (channel_id == current_channel_id) do
    verify_on_chain(signed_tx)
    {:ok, state}
  end

  def process_message(%{"method" => "channels.info", "params" => %{"channel_id" => channel_id, "data" => %{"event" => "open"}}} = _message, %__MODULE__{channel_id: current_channel_id} = state) when (channel_id == current_channel_id) do
    Logger.debug "= CHANNEL OPEN/READY", state.color
    {:ok, state}
  end

  def process_message(%{"method" => "channels.info"} = message, state) do
    Logger.debug "= channels info: #{inspect message}", state.color
    {:ok, state}
  end

  def process_message(message, state) do
    Logger.error "<= unprocessed message recieved by #{inspect state.role}. message: #{inspect message}"
    {:ok, state}
  end
end
