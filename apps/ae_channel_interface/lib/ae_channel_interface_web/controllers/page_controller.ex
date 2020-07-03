defmodule AeChannelInterfaceWeb.PageController do
  use AeChannelInterfaceWeb, :controller

  alias ChannelService.OnChain

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def show(conn, _params) do
    {:ok, channels_list} = BackendServiceManager.get_channel_table()

    channels_with_info =
      Enum.map(channels_list, fn {id, {actual_channel_id, _}} -> get_channel_info(actual_channel_id) end)

    conn
    |> assign(:channels, channels_with_info)
    |> render("show.html")
  end

  defp get_channel_info({<<"ch_", _::binary>> = channel_id, _}) do
    channel_id
    |> OnChain.get_channel_info(SessionHolderHelper.ae_url_http())
  end

  defp get_channel_info(channel_id) do
    []
  end
end
