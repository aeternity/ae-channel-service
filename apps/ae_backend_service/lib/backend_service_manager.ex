defmodule BackendServiceManager do
  @moduledoc """
  ChannelInterface keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer
  require Logger

  defstruct pid_session_holder: nil

  # Client

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  def start_channel(params) do
    GenServer.call(__MODULE__, {:start_channel, params})
  end



  # Server
  def init({}) do
    {:ok, %__MODULE__{}}
  end

  defp is_reestablish(reestablish) do
    case reestablish do
      {"", 0} ->
        false
      _ -> true
    end
  end

  defp start_channel_local(
        {
          role,
          _config,
          {channel_id, reestablish_port} = reestablish,
          _keypair_initiator
        } = params
      )
      when role in [:initiator, :responder] do
    if is_reestablish(reestablish) do
      # only superview reestablished sessions, no way to relocate a fsm without channel_id and fsm_id
      Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, self()}])
    else
      BackendSession.start_link({params, self()})
    end
  end

  def handle_call({:start_channel, params}, _from, state) do
    {:ok, pid} = start_channel_local(params)
    {:reply, pid, state}
  end
end
