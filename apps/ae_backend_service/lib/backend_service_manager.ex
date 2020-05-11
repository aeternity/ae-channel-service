defmodule BackendServiceManager do
  @moduledoc """
  ChannelInterface keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer
  require Logger

  defstruct channel_id_table: %{}

  # Client

  # for testing
  def start_link(%{"name" => name}) do
    GenServer.start_link(__MODULE__, {}, name: name)
  end

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

  def get_channel_table() do
    GenServer.call(__MODULE__, :get_channel_table)
  end

  def set_channel_id(pid, identifier, channel_id) do
    GenServer.call(pid, {:set_channel_id, identifier, channel_id})
  end

  def remove_channel_id(pid, identifier) do
    GenServer.call(pid, {:remove_channel_id, identifier})
  end

  # Server
  def init({}) do
    GenServer.cast(self(), {:restart_channels})
    {:ok, %__MODULE__{channel_id_table: %{}}}
  end

  defp is_reestablish(reestablish) do
    case reestablish do
      {"", 0} ->
        false

      _ ->
        true
    end
  end

  def is_already_started(channel_id_table, {channel_id, _port}) do
    case for {_identifier, {{existing_channel_id, _existing_port}, pid}} <- channel_id_table,
             channel_id == existing_channel_id,
             do: pid do
      [pid] -> pid
      [] -> nil
    end
  end

  @default_port 1599
  def handle_cast({:restart_channels}, state) do
    {pub, _priv} = account_fun = Application.get_env(:ae_socket_connector, :accounts)[:responder]
    self = self()
    channel_config = SessionHolderHelper.custom_config(%{}, %{})

    spawn(fn ->
      Enum.map(SessionHolderHelper.list_channel_ids(:responder, pub), fn channel_id ->
        return =
          {:ok, _pid} =
          GenServer.call(
            self,
            {:start_channel, {:responder, channel_config, {channel_id, @default_port}, fn -> account_fun end}}
          )

        Logger.debug("Starting old channel #{inspect({channel_id, return})}")
      end)
    end)

    {:noreply, state}
  end

  def handle_call({:get_channel_id, identifier}, _from, state) do
    Logger.info("got channel id: #{inspect(Map.get(state.channel_id_table, identifier, {"", 0}))}")
    {reestablish, _pid} = Map.get(state.channel_id_table, identifier, {{"", 0}, nil})
    {:reply, reestablish, state}
  end

  def handle_call({:set_channel_id, identifier, reestablish}, from, state) do
    Logger.info("Channel populated with channel_id #{inspect({identifier, reestablish})}")

    {:reply, :ok,
     %__MODULE__{state | channel_id_table: Map.put(state.channel_id_table, identifier, {reestablish, from})}}
  end

  def handle_call({:remove_channel_id, identifier}, _from, state) do
    Logger.info(
      "Channel with identifier #{inspect(identifier)} removed from channel_table entry was #{
        inspect(Map.get(state.channel_id_table, identifier, :no_entry))
      }"
    )

    {:reply, :ok, %__MODULE__{state | channel_id_table: Map.delete(state.channel_id_table, identifier)}}
  end

  def handle_call({:start_channel, {_role, _config, reestablish, _keypair_initiator} = params}, _from, state) do
    identifier = :erlang.unique_integer([:monotonic])

    case is_reestablish(reestablish) do
      true ->
        case is_already_started(state.channel_id_table, reestablish) do
          nil ->
            {:ok, pid} = Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, {self(), identifier}}])
            Process.monitor(pid)

            {:reply, {:ok, pid},
             %__MODULE__{state | channel_id_table: Map.put(state.channel_id_table, identifier, {reestablish, pid})}}

          pid ->
            {:reply, {:ok, pid}, state}
        end

      false ->
        {:ok, pid} = Supervisor.start_child(ChannelSupervisor.Supervisor, [{params, {self(), identifier}}])
        Process.monitor(pid)
        {:reply, {:ok, pid}, state}
    end
  end

  def handle_call(:get_channel_table, _from, state) do
    {:reply, {:ok, state.channel_id_table}, state}
  end
end
