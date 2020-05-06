defmodule AeChannelInterfaceWeb.Router do
  use AeChannelInterfaceWeb, :router

  pipeline :browser do
    plug(CORSPlug, origin: "*")
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AeChannelInterfaceWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/channels", PageController, :show)
    resources("/connect", ConnectController, only: [:new])
  end

  # Other scopes may use custom stacks.
  # scope "/api", AeChannelInterfaceWeb do
  #   pipe_through :api
  # end
end
