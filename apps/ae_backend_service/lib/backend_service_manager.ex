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

  defp start_channel_local(
        {
          role,
          _config,
          {_channel_id, _reestablish_port},
          _keypair_initiator
        } = params
      )
      when role in [:initiator, :responder] do
    # TODO only supervise reestablish - and maybe not those either...
    Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, self()}])
  end

  def handle_call({:start_channel, params}, _from, state) do
    {:ok, pid} = start_channel_local(params)
    {:reply, pid, state}
  end
end
