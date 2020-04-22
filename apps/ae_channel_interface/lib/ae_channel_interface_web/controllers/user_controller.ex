defmodule AeChannelInterfaceWeb.ConnectController do
  use AeChannelInterfaceWeb, :controller
  require AeChannelInterfaceWeb.SocketConnectorChannel
  alias AeChannelInterfaceWeb.SocketConnectorChannel, as: SocketConnectorChannel

  require Logger
  require SessionHolderHelper

  @ae_url Application.get_env(:ae_socket_connector, :node)[:ae_url]

  def public_key() do
    {responder_pub_key, _responder_priv_key} = SocketConnectorChannel.keypair_responder()
    responder_pub_key
  end

  # http://127.0.0.1:4000/connect/new?initiator_id=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610&channel_id=ch_263xZie6pTq7zXCFfyntnkScxG3sCW7CYiVLXWjqmxxtx6mh6n
  # wscat --connect localhost:3014/channel?existing_channel_id=ch_s8RwBYpaPCPvUxvDsoLxH9KTgSV6EPGNjSYHfpbb4BL4qudgR&host=localhost&offchain_tx=tx_%2BQENCwH4h...&port=12341&protocol=json-rpc&role=initiator
  # this is a reestablish
  def new(
        conn,
        %{"initiator_id" => initiator_id, "port" => port, "existing_channel_id" => existing_channel_id} = params
      ) do
    # {:ok, backend_runner_pid} = BackendServiceManager.start_channel({"bogus", :some_name})
    reestablish_port = String.to_integer(port)
    channel_config = SessionHolderHelper.custom_config(%{}, %{})

    {:ok, _pid} =
      BackendServiceManager.start_channel(
        {:responder, channel_config, {existing_channel_id, reestablish_port},
         fn -> {initiator_id, "not for you to have"} end}
      )

    json(conn, %{
      responder_id: public_key(),
      initiator_id: initiator_id,
      existing_channel_id: existing_channel_id,
      api_endpoint: "connect/new",
      client: params
    })
  end

  # http://127.0.0.1:4000/connect/new?initiator_id=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610
  # wscat --connect 'localhost:3014/channel?channel_reserve=2&initiator_amount=70000000000000&initiator_id=ak_2MGLPW2CHTDXJhqFJezqSwYSNwbZokSKkG7wSbGtVmeyjGfHtm&lock_period=10&port=12340&protocol=json-rpc&push_amount=1&responder_amount=40000000000000&responder_id=ak_nQpnNuBPQwibGpSJmjAah6r3ktAB7pG9JHuaGWHgLKxaKqEvC&role=responder'
  # this is a brand new connection
  def new(conn, %{"initiator_id" => initiator_id, "port" => _port} = params_in) do
    params = for {key, value} <- params_in, into: %{}, do: {String.to_atom(key), value}

    # TODO this whole thing is due to to crazy construct of basic and custom parmas, should be kept merged
    {custom, basic} =
      Enum.reduce(Map.keys(Map.from_struct(%SocketConnector.WsConnection{})), {params, %{}}, fn key,
                                                                                                {cust_par, bas_par} ->
        case Map.get(params, key) do
          nil ->
            {Map.delete(cust_par, key), bas_par}

          value ->
            {Map.delete(cust_par, key), Map.put(bas_par, key, value)}
        end
      end)

    channel_config = SessionHolderHelper.custom_config(basic, custom)
    basic_params = channel_config.(initiator_id, public_key()).basic_configuration
    custom_params = channel_config.(initiator_id, public_key()).custom_param_fun.(:initiator, @ae_url)

    {:ok, _pid} =
      BackendServiceManager.start_channel(
        {:responder, channel_config, {"", 0}, fn -> {initiator_id, "not for you to have"} end}
      )

    json(conn, %{
      responder_id: public_key(),
      initiator_id: initiator_id,
      api_endpoint: "connect/new",
      client: params_in,
      expected_initiator_configuration: Map.merge(Map.from_struct(basic_params), custom_params)
    })
  end

  # Maybe phoenix error message is prettier :)
  # def new(conn, params) do
  #   json conn, %{message: ~s(you must provide your account to initate a session "/connect/new?initiator_id=ak_12123423..."), user_data: params}
  # end
end
