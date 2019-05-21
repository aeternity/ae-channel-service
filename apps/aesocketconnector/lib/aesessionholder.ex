defmodule AeSessionHolder do
  use GenServer
  require Logger

  @bc_url "ws://localhost:3014/channel"

  defstruct [
    pid: nil,
    color: nil,
    configuration: %AeSocketConnector{}
  ]

  def start_link(%AeSocketConnector{} = configuration, color) do
    GenServer.start_link(__MODULE__, {configuration, color})
  end

  def reestablish(pid) do
    GenServer.cast(pid, {:reestablish})
  end

  def run_action(pid, action) do
    GenServer.cast(pid, {:action, action})
  end

  #Server
  def init({%AeSocketConnector{} = configuration, color}) do
    {:ok, pid} = AeSocketConnector.start_link(:alice, configuration, @bc_url, color, self())
    {:ok, %__MODULE__{pid: pid, configuration: configuration, color: color}}
  end

  def handle_call({:connection_dropped, configuration}, _from, state) do
    # TODO, remove delay
    # give to other end to disconnect
    Process.sleep(1000)
    reestablish(self())
    {:reply, :ok, %__MODULE__{state | configuration: configuration}}
  end

  def handle_cast({:reestablish}, state) do
    Logger.debug "about to reestablish connection", [ansi_color: state.color]
    {:ok, pid} = AeSocketConnector.start_link(:alice, state.configuration, @bc_url, :reestablish, state.color, self())
    {:noreply, %__MODULE__{state | pid: pid}}
  end

  def handle_cast({:action, action}, state) do
    action.(state.pid)
    {:noreply, state}
  end

end



# {:ok, pid} = AeSocketConnector.start_link()

# AeSocketConnector.echo(pid, "Yo Homies!")
# AeSocketConnector.echo(pid, "This and That!")
# AeSocketConnector.echo(pid, "Can you please reply yourself?")
#
# Process.sleep(1000)
#
# AeSocketConnector.echo(pid, "Close the things!")
# Process.sleep(1500)

#
# {
#   "jsonrpc": "2.0",
#   "method": "channels.initiator_sign",
#   "params": {
#     "tx": "tx_+MsLAfhCuEA8qOUSomEv4vYDrI78VvYo5/hgXIXzHFftvIWVKP1P6N823VPgptGj6+8JgctKZNIHrRp/3dApg/3LEVleoOQOuIP4gTIBoQGxtXe80yfLOeVebAJr1qdKGzXebAZQxK5R76t1nkFbZoY/qiUiYAChAWccVUZGSUV1srSU9lFoIXEGY9hIk83S0jYDelTDPu6EhiRhOcqAAAIKAIYSMJzlQADAoKM+TsJdaNIdM7xXZj1ZNp3oP/mwHzIJHxa6ZaHRbFa/Ac8BpMU="
#   }
# }
#
# %{jsonrpc: "2.0",
#    method: "channels.initiator_sign",
#    params:
#    %{tx: "tx_yh0xNxVk6lkE+pajmjWYEqAqN0o9FKrwP/SwIT68ep7DdCbQhi1OB1YxCuj7diYqdmmLvEfwdoAyl485MOscCQ=="}}
