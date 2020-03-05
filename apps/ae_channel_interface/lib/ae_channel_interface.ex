defmodule ChannelInterface do
  @moduledoc """
  ChannelInterface keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use GenServer;
  require Logger;

  defstruct [
    ets_id_to_raw: nil, desc_pid: nil,
    ets_id_to_unpacked: nil
  ]

  #Client

  def start({_, name}) do
    # GenServer.start_link(__MODULE__, desc_pid, name: name)
    GenServer.start(__MODULE__, {}, name: name)
  end

  #Server
  def init({}) do
    # id_to_raw = :ets.new(CacheTableRaw, [:set, :private])
    # id_to_unpacked = :ets.new(CacheTableUnpacked, [:set, :private])
    # {:ok, %__MODULE__{ets_id_to_raw: id_to_raw, ets_id_to_unpacked: id_to_unpacked, desc_pid: desc_pid}}
    {:ok, %__MODULE__{}}
  end

  def handle_cast({:connection_update, {status, _reason} = update}, socket) do
    Logger.info("Connection update in controller, #{inspect update}")
    # push(socket, "shout", %{message: inspect(update), name: "bot"})
    # push(socket, Atom.to_string(status), %{})
    {:noreply, socket}
  end

  def handle_cast({:match_jobs, {:sign_approve, _round, method}, to_sign} = message, socket) do
    Logger.info("Sign request in controller #{inspect(message)}")
    # push(socket, "sign", %{message: inspect(message), method: method, to_sign: to_sign})
    # push(socket, "shout", %{message: inspect(message), name: "bot"})
    # broadcast socket, "shout", %{message: inspect(message), name: "bot2"}
    {:noreply, socket}
  end

  def handle_cast(message, socket) do
    # push(socket, "shout", %{message: inspect(message), name: "bot"})
    {:noreply, socket}
  end

end
