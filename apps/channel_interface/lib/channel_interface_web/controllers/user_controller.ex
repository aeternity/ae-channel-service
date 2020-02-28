defmodule ChannelInterfaceWeb.ConnectController do
  use ChannelInterfaceWeb, :controller
  require ChannelInterfaceWeb.SocketConnectorChannel
  alias ChannelInterfaceWeb.SocketConnectorChannel, as: SocketConnectorChannel

  def public_key() do
    {responder_pub_key, _responder_priv_key} = SocketConnectorChannel.keypair_responder()
    responder_pub_key
  end

  # http://127.0.0.1:4000/connect/new?client_account=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610&channel_id=ch_2WXxzsKzpxurFTg5WifeRNtSayssq5e1QWrCotdSTvvo2JNoHX
  # this is a reestablish
  def new(conn, %{"client_account" => client_account, "port" => port, "channel_id" => channel_id} = params) do
    SocketConnectorChannel.start_session_holder(:responder, port, channel_id, fn -> {client_account, "not for you to have"} end, fn -> SocketConnectorChannel.keypair_responder() end)
    json conn, %{account: public_key(), client_account: client_account, channel_id: channel_id, type: "reestablish", client: params}
  end

  # http://127.0.0.1:4000/connect/new?client_account=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610
  # this is a brand new connection
  def new(conn, %{"client_account" => client_account, "port" => port} = params) do
    SocketConnectorChannel.start_session_holder(:responder, port, "", fn -> {client_account, "not for you to have"} end, fn -> SocketConnectorChannel.keypair_responder() end)
    json conn, %{account: public_key(), client_account: client_account, type: "connect", client: params}
  end


  def new(conn, params) do
    json conn, %{message: ~s(you must provide your account to initate a session "/connect/new?client_account=ak_12123423..."), user_data: params}
  end
end
