defmodule PhoenixHtmldriver.UseMacroTest do
  use ExUnit.Case

  @endpoint PhoenixHtmldriver.TestRouter

  use PhoenixHtmldriver

  describe "use PhoenixHtmldriver with auto-configuration" do
    test "automatically provides conn with endpoint configured", %{conn: conn} do
      assert conn.private[:phoenix_endpoint] == @endpoint
    end

    test "can visit a page without manual setup", %{conn: conn} do
      session = visit(conn, "/home")

      assert session.endpoint == @endpoint
      assert_text(session, "Welcome Home")
    end

    test "can chain operations", %{conn: conn} do
      visit(conn, "/home")
      |> assert_text("Welcome Home")
      |> assert_selector("h1")
      |> click_link("#about-link")
      |> assert_text("About Page")
    end
  end

  describe "use PhoenixHtmldriver without ConnCase" do
    test "works with manually created conn", %{conn: conn} do
      # Conn is automatically created by the macro
      assert %Plug.Conn{} = conn
      assert conn.private[:phoenix_endpoint] == @endpoint

      session = visit(conn, "/home")
      assert_text(session, "Welcome Home")
    end
  end
end
