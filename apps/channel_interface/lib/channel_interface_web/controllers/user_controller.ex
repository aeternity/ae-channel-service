defmodule ChannelInterfaceWeb.ConnectController do
  use ChannelInterfaceWeb, :controller
  require ChannelInterfaceWeb.SocketConnectorChannel
  alias ChannelInterfaceWeb.SocketConnectorChannel, as: SocketConnectorChannel

  def keypair_initator(client_account) do
    {client_account, "not for you to have"}
  end

  # this is a reestablish
  # def new(conn, %{"client_account" => client_account, "port" => port, "channel_id" => channel_id} = params) do
  #   SocketConnectorChannel.start_session_holder(:responder, port, 1, fn -> {client_account, "not for you to have"} end, fn -> SocketConnectorChannel.keypair_responder() end)
  #   json conn, %{account: "ak_account", client: params, client_account: client_account}
  # end

  # http://127.0.0.1:4000/connect/new?client_account=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610
  # this is a brand new connection
  def new(conn, %{"client_account" => client_account, "port" => port} = params) do
    SocketConnectorChannel.start_session_holder(:responder, port, "1", fn -> {client_account, "not for you to have"} end, fn -> SocketConnectorChannel.keypair_responder() end)
    json conn, %{account: "ak_account", client: params, client_account: client_account}
  end


  def new(conn, params) do
    json conn, %{message: ~s(you must provide you account to initate a session "/connect/new?client_account=ak_12123423..."), user_data: params}
  end
end
