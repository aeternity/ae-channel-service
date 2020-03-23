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



  defstruct pid_session_holder: nil,
            pid_backend_manager: nil

  #Client

  def start_link({params, pid_manager}) do
    GenServer.start_link(__MODULE__, {params, pid_manager})
  end

  defp log_callback({type, message}) do
    Logger.info(
      "backend service: #{inspect({type, message})} pid is: #{inspect(self())}",
      ansi_color: Map.get(message, :color, nil)
    )
  end

  #Server
  def init({{role, channel_config, {_channel_id, _reestablish_port} = reestablish, initiator_keypair} = params, pid_manager}) do
    Logger.info("Starting backend session #{inspect params} pid is #{inspect self()}")
    {:ok, pid} = SessionHolderHelper.start_session_holder(role, channel_config, reestablish, initiator_keypair, fn -> keypair_responder() end, SessionHolderHelper.connection_callback(self(), :blue, &log_callback/1))
    {:ok, %__MODULE__{pid_session_holder: pid, pid_backend_manager: pid_manager}}
  end

  #TODO once we know the channel_id this process should register itself somewhere.
  def handle_cast({:connection_update, {_status, _reason} = _update}, state) do
    {:noreply, state}
  end

  # TODO backend just happily signs
  def handle_cast({:match_jobs, {:sign_approve, _round, _round_initiator, method, _channel_id}, to_sign} = _message, state) do
    signed = SessionHolder.sign_message(state.pid_session_holder, to_sign)
    fun = &SocketConnector.send_signed_message(&1, method, signed)
    SessionHolder.run_action(state.pid_session_holder, fun)

    if method == "channels.sign.responder_sign" do

    end

    {:noreply, state}
  end

  def handle_cast(message, socket) do
    Logger.warn("unprocessed message received in backend #{inspect(message)}")
    {:noreply, socket}
  end
end
