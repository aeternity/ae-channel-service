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
    GenServer.start_link(__MODULE__, {})
  end

  def start_channel(
        {
          role,
          _config,
          {_channel_id, _reestablish_port},
          _keypair_initiator
        } = params
      )
      when role in [:initiator, :responder] do
    {:ok, pid} = Supervisor.start_child(ChannelSupervisor.Supervisor, [params])
    pid
  end

  # Server
  def init({}) do
    {:ok, %__MODULE__{}}
  end
end
