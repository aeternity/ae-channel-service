defmodule BackendServiceManager do
  @moduledoc """
  ChannelInterface keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer
  require Logger

  defstruct pid_session_holder: nil,
            channel_id_table: %{}

  # Client

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  # only one instance of the manager.
  def start_channel(params) do
    GenServer.call(__MODULE__, {:start_channel, params})
  end

  def get_channel_id(pid, identifier) do
    GenServer.call(pid, {:get_channel_id, identifier})
  end

  def set_channel_id(pid, identifier, channel_id) do
    GenServer.call(pid, {:set_channel_id, identifier, channel_id})
  end


  # Server
  def init({}) do
    {:ok, %__MODULE__{channel_id_table: %{}}}
  end

  defp is_reestablish(reestablish) do
    case reestablish do
      {"", 0} ->
        false
      _ -> true
    end
  end

  # defp start_channel_local(
  #       {
  #         role,
  #         _config,
  #         {channel_id, reestablish_port} = reestablish,
  #         _keypair_initiator
  #       } = params
  #     )
  #     when role in [:initiator, :responder] do
  #   identifier = :erlang.unique_integer([:monotonic])
  #   if is_reestablish(reestablish) do
  #     # only superview reestablished sessions, no way to relocate a fsm without channel_id and fsm_id
  #     Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, {self()}, identifier}])

  #   # else
  #   #   BackendSession.start_link({params, self()})
  #   # end
  # end

  def handle_call({:get_channel_id, identifier}, _from, state) do
    Logger.info("got channel id: #{inspect Map.get(state.channel_id_table, identifier, {"", 0})}")
    {:reply, Map.get(state.channel_id_table, identifier, {"", 0}), state}
  end

  def handle_call({:set_channel_id, identifier, reestablish}, _from, state) do
    Logger.info("Channel poulated with channel_id #{inspect {reestablish, identifier}}")
    {:reply, :ok, %__MODULE__{state | channel_id_table: Map.put(state.channel_id_table, identifier, reestablish)}}
  end

  def handle_call({:start_channel, {_role, _config, reestablish, _keypair_initiator} = params}, _from, state) do
    # {:ok, pid} = start_channel_local(params)
    identifier = :erlang.unique_integer([:monotonic])
    {:ok, pid} = Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, {self(), identifier}}])
    case is_reestablish(reestablish) do
      true ->
        {:reply, pid, %__MODULE__{state | channel_id_table: Map.put(state.channel_id_table, identifier, reestablish)}}
      false ->
        {:reply, pid, state}
    end
  end
end
