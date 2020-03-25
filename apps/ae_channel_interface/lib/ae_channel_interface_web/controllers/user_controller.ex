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

  # http://127.0.0.1:4000/connect/new?client_account=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610&channel_id=ch_263xZie6pTq7zXCFfyntnkScxG3sCW7CYiVLXWjqmxxtx6mh6n
  # this is a reestablish
  def new(conn, %{"client_account" => client_account, "port" => port, "channel_id" => channel_id} = params) do
    # {:ok, backend_runner_pid} = BackendServiceManager.start_channel({"bogus", :some_name})
    reestablish_port = String.to_integer(port)
    channel_config = SessionHolderHelper.custom_config(%{}, %{})
    BackendServiceManager.start_channel({:responder, channel_config, {channel_id, reestablish_port}, fn -> {client_account, "not for you to have"} end})
    json conn, %{account: public_key(), client_account: client_account, channel_id: channel_id, api_endpoint: "reestablish", client: params}
  end

  #TODO endpoint which allows custom configuration

  # http://127.0.0.1:4000/connect/new?client_account=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610
  # this is a brand new connection
  def new(conn, %{"client_account" => client_account, "port" => port} = params) do
    open_port = String.to_integer(port)
    channel_config = SessionHolderHelper.custom_config(%{}, %{port: open_port})
    basic_params = channel_config.(client_account, public_key())
    custom_params = channel_config.(client_account, public_key()).custom_param_fun.(:initiator, @ae_url)
    BackendServiceManager.start_channel({:responder, channel_config, {"", 0}, fn -> {client_account, "not for you to have"} end})
    json conn, %{account: public_key(), client_account: client_account, api_endpoint: "connect", client: params,  expected_initiator_configuration: %{basic: Map.from_struct(basic_params.basic_configuration), custom: custom_params}}
  end

  # Maybe phoenix error message is prettier :)
  # def new(conn, params) do
  #   json conn, %{message: ~s(you must provide your account to initate a session "/connect/new?client_account=ak_12123423..."), user_data: params}
  # end
end
