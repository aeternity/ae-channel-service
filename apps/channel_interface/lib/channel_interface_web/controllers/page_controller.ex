defmodule ChannelInterfaceWeb.PageController do
  use ChannelInterfaceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
