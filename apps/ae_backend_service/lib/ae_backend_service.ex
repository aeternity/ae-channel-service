defmodule AeBackendService do
  @moduledoc """
  ChannelInterface keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer;
  require Logger;

  defstruct pid_session_holder: nil

  #Client

  def start({_, name}) do
    # GenServer.start_link(__MODULE__, desc_pid, name: name)
    GenServer.start(__MODULE__, {})
  end

  def specify_session_holder(pid, socket_holder) do
    GenServer.call(pid, {:specify_session_holder, socket_holder})
  end

  #Server
  def init({}) do
    {:ok, %__MODULE__{}}
  end

  #TODO once we know the channel_id this process should register itself somewhere.

  def handle_call({:specify_session_holder, pid_session_holder}, _from, state) do
    {:reply, :ok, %__MODULE__{state | pid_session_holder: pid_session_holder}}
  end

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
