defmodule AeChannelInterfaceWeb.PageControllerTest do
  use AeChannelInterfaceWeb.ConnCase

  @tag :web
  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
