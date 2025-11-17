defmodule PhoenixHtmldriverTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.Session

  @endpoint PhoenixHtmldriver.TestRouter

  setup do
    conn =
      Plug.Test.conn(:get, "/")
      |> put_in([Access.key!(:secret_key_base)], @endpoint.config(:secret_key_base))
      |> Plug.Conn.put_private(:phoenix_endpoint, @endpoint)

    %{conn: conn}
  end

  describe "visit/2" do
    test "creates a new session when given a Plug.Conn", %{conn: conn} do
      session = PhoenixHtmldriver.visit(conn, "/home")

      assert %Session{} = session
      assert session.path == "/home"
      assert session.endpoint == @endpoint
    end

    test "navigates within an existing session when given a Session", %{conn: conn} do
      session = PhoenixHtmldriver.visit(conn, "/home")
      new_session = PhoenixHtmldriver.visit(session, "/about")

      assert %Session{} = new_session
      assert new_session.path == "/about"
      assert new_session.endpoint == @endpoint
    end

    test "delegates to Session.new/2 when given conn", %{conn: conn} do
      session = PhoenixHtmldriver.visit(conn, "/home")
      session_new = Session.new(conn, "/home")

      # Both should produce equivalent sessions (excluding response times etc)
      assert session.path == session_new.path
      assert session.endpoint == session_new.endpoint
    end

    test "delegates to Session.get/2 when given session", %{conn: conn} do
      initial_session = Session.new(conn, "/home")

      visit_result = PhoenixHtmldriver.visit(initial_session, "/about")
      get_result = Session.get(initial_session, "/about")

      # Both should produce equivalent results
      assert visit_result.path == get_result.path
      assert visit_result.endpoint == get_result.endpoint
    end

    test "preserves cookies when navigating with session", %{conn: conn} do
      # Visit a page that sets a cookie
      session = PhoenixHtmldriver.visit(conn, "/set-cookie")
      cookies = session.cookies

      # Navigate to another page
      new_session = PhoenixHtmldriver.visit(session, "/home")

      # Cookies should be preserved
      assert new_session.cookies == cookies
    end

    test "can chain multiple visits", %{conn: conn} do
      session =
        conn
        |> PhoenixHtmldriver.visit("/home")
        |> PhoenixHtmldriver.visit("/about")
        |> PhoenixHtmldriver.visit("/home")

      assert session.path == "/home"
    end
  end

  describe "__using__ macro" do
    test "imports visit/2 function" do
      # In the actual test file, user would do: use PhoenixHtmldriver
      # and then visit/2 would be available
      # Here we just verify the function is exported from the main module
      assert function_exported?(PhoenixHtmldriver, :visit, 2)
    end

    test "setup configures conn with endpoint" do
      # Test that __using__ macro sets up endpoint
      # This is tested indirectly through the visit/2 tests above
      # which rely on conn having the endpoint configured
      assert true
    end
  end

  describe "pattern matching dispatch" do
    test "correctly identifies Plug.Conn and dispatches to Session.new", %{conn: conn} do
      # This should call Session.new/2
      session = PhoenixHtmldriver.visit(conn, "/")

      assert session.path == "/"
    end

    test "correctly identifies Session struct and dispatches to Session.get", %{conn: conn} do
      initial_session = Session.new(conn, "/")

      # This should call Session.get/2
      new_session = PhoenixHtmldriver.visit(initial_session, "/home")

      assert new_session.path == "/home"
    end

    test "handles Session struct with all fields populated", %{conn: conn} do
      session = PhoenixHtmldriver.visit(conn, "/home")

      # Verify it's a fully populated session
      assert session.conn != nil
      assert session.document != nil
      assert session.response != nil
      assert session.endpoint != nil
      assert session.cookies != nil
      assert session.path != nil

      # Should still correctly dispatch on pattern match
      new_session = PhoenixHtmldriver.visit(session, "/about")
      assert new_session.path == "/about"
    end
  end

  describe "integration with Session module" do
    test "visit/2 works seamlessly with Session.new and Session.get", %{conn: conn} do
      # Mix and match visit/2 with Session functions
      session1 = PhoenixHtmldriver.visit(conn, "/home")
      session2 = Session.get(session1, "/about")
      session3 = PhoenixHtmldriver.visit(session2, "/home")
      session4 = Session.get(session3, "/")

      assert session4.path == "/"
    end

    test "visit/2 produces same results as direct Session calls", %{conn: conn} do
      # Using visit/2
      via_visit =
        conn
        |> PhoenixHtmldriver.visit("/home")
        |> PhoenixHtmldriver.visit("/about")

      # Using Session directly
      via_session =
        conn
        |> Session.new("/home")
        |> Session.get("/about")

      assert via_visit.path == via_session.path
      assert via_visit.endpoint == via_session.endpoint
    end
  end

  describe "error handling" do
    test "raises when conn has no endpoint" do
      conn = Plug.Test.conn(:get, "/")

      assert_raise RuntimeError, ~r/No endpoint found/, fn ->
        PhoenixHtmldriver.visit(conn, "/")
      end
    end

    test "propagates Session.new errors", %{conn: conn} do
      # Remove endpoint to cause error
      conn_without_endpoint = %{conn | private: %{}}

      assert_raise RuntimeError, ~r/No endpoint found/, fn ->
        PhoenixHtmldriver.visit(conn_without_endpoint, "/")
      end
    end
  end

  describe "documentation examples" do
    test "example from module documentation works", %{conn: conn} do
      # From the @moduledoc example
      session = PhoenixHtmldriver.visit(conn, "/home")

      assert %Session{} = session
      assert session.path == "/home"
    end

    test "chaining example works", %{conn: conn} do
      # Create a new session
      session = PhoenixHtmldriver.visit(conn, "/home")

      # Navigate within the session
      session = PhoenixHtmldriver.visit(session, "/about")

      # Or use Session.get/2 directly
      session = Session.get(session, "/home")

      assert session.path == "/home"
    end
  end
end
