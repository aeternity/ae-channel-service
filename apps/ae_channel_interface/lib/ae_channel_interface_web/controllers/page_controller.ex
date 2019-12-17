defmodule AeChannelInterfaceWeb.PageController do
  use AeChannelInterfaceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
