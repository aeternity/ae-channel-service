defmodule BackendSession do
  @moduledoc """
  BackendSession keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer;
  require Logger;

  defmacro keypair_initiator, do: Application.get_env(:ae_socket_connector, :accounts)[:initiator]
  defmacro keypair_responder, do: Application.get_env(:ae_socket_connector, :accounts)[:responder]

  defmacro ae_url, do: Application.get_env(:ae_socket_connector, :node)[:ae_url]

  defmacro network_id, do: Application.get_env(:ae_socket_connector, :node)[:network_id]



  defstruct pid_session_holder: nil

  #Client

  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  #Server
  def init({role, channel_config, {_channel_id, _reestablish_port} = reestablish, initiator_keypair} = params) do
    Logger.info("Starting backend session #{inspect params} pid is #{inspect self()}")
    {:ok, pid} = SessionHolderHelper.start_session_holder(role, channel_config, reestablish, initiator_keypair, fn -> keypair_responder() end, SessionHolderHelper.connection_callback(self(), "yellow"))
    {:ok, %__MODULE__{pid_session_holder: pid}}
  end

  #TODO once we know the channel_id this process should register itself somewhere.
  def handle_cast({:connection_update, {_status, _reason} = update}, state) do
    Logger.info("Connection update in backend, #{inspect update}")
    {:noreply, state}
  end

  # TODO backend just happily signs
  def handle_cast({:match_jobs, {:sign_approve, _round, method}, to_sign} = message, state) do
    Logger.info("Sign request in backend #{inspect(message)}")
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)

    {:noreply, state}
  end

  def handle_cast(message, socket) do
    Logger.warn("unprocessed message received in backend #{inspect(message)}")
    {:noreply, socket}
  end
end
