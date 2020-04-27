defmodule AeChannelInterfaceWeb.PageController do
  use AeChannelInterfaceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def show(conn, _params) do
    {:ok, channels_list} = BackendServiceManager.get_channel_table()
    active_channels = Enum.map(channels_list, fn {k, {{channel_id, _num}, _}} -> {k, channel_id} end)
    render(conn, "show.html", active_channels: active_channels)
  end
end
