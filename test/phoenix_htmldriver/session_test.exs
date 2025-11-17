defmodule PhoenixHtmldriver.SessionTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.{CookieJar, Session}

  @endpoint PhoenixHtmldriver.TestRouter

  setup do
    conn =
      Plug.Test.conn(:get, "/")
      |> put_in([Access.key!(:secret_key_base)], @endpoint.config(:secret_key_base))
      |> Plug.Conn.put_private(:phoenix_endpoint, @endpoint)

    %{conn: conn}
  end

  describe "new/2" do
    test "creates a new session from conn and visits path", %{conn: conn} do
      session = Session.new(conn, "/")

      assert %Session{} = session
      assert session.endpoint == @endpoint
      assert session.cookies == CookieJar.empty()
      assert session.path == "/"
      assert session.response.status == 200
      assert session.document != nil
    end

    test "raises when endpoint is not set" do
      conn = Plug.Test.conn(:get, "/")

      assert_raise RuntimeError, ~r/No endpoint found/, fn ->
        Session.new(conn, "/")
      end
    end

    test "preserves conn in session", %{conn: conn} do
      session = Session.new(conn, "/")

      assert session.conn == conn
    end
  end

  describe "get/2" do
    test "navigates to a new path within existing session", %{conn: conn} do
      session = Session.new(conn, "/")
      new_session = Session.get(session, "/home")

      assert %Session{} = new_session
      assert new_session.path == "/home"
      assert new_session.endpoint == @endpoint
      assert new_session.conn == conn
    end

    test "preserves cookies across requests", %{conn: conn} do
      # Visit a page that sets a cookie
      session = Session.new(conn, "/set-cookie")

      # Cookies should be extracted from the response
      assert session.cookies.cookies != %{}

      # Navigate to another page
      new_session = Session.get(session, "/")

      # Cookies should be preserved
      assert new_session.cookies == session.cookies
    end
  end

  describe "path/1" do
    test "returns the current path", %{conn: conn} do
      session = Session.new(conn, "/home")

      assert Session.path(session) == "/home"
    end
  end

  describe "html/1" do
    test "returns the response body", %{conn: conn} do
      session = Session.new(conn, "/")

      html = Session.html(session)

      assert html =~ "Welcome"
    end
  end

  describe "request/5" do
    test "follows redirects automatically", %{conn: conn} do
      session = Session.new(conn, "/redirect-to-home")

      # Should follow redirect and end up at /home
      assert session.path == "/home"
      assert session.response.status == 200
    end

    test "raises when too many redirects (max 5)", %{conn: conn} do
      assert_raise RuntimeError, ~r/Too many redirects/, fn ->
        Session.new(conn, "/infinite-redirect")
      end
    end

    test "merges cookies from redirects", %{conn: conn} do
      # Visit a page that redirects after setting a cookie
      session = Session.new(conn, "/redirect-with-cookie")

      # Should have cookies from the redirect chain
      assert session.cookies.cookies != %{}
    end

    test "supports GET requests with params", %{conn: conn} do
      session = Session.new(conn, "/")
      new_session = Session.request(session, :get, "/search", %{q: "test"})

      assert new_session.path == "/search"
      assert new_session.response.status == 200
    end

    test "supports POST requests", %{conn: conn} do
      session = Session.new(conn, "/")
      new_session = Session.request(session, :post, "/login", %{username: "alice"})

      assert new_session.response.status == 200
    end

    test "encodes GET params in query string", %{conn: conn} do
      session = Session.new(conn, "/")
      new_session = Session.request(session, :get, "/search", %{q: "test", page: "2"})

      # The request path should include query params
      assert new_session.response.request_path == "/search"
      # Query string should be in the original request
      assert new_session.response.query_string =~ "q=test"
      assert new_session.response.query_string =~ "page=2"
    end

    test "appends params to existing query string", %{conn: conn} do
      session = Session.new(conn, "/")
      new_session = Session.request(session, :get, "/search?filter=all", %{q: "test"})

      assert new_session.response.query_string =~ "filter=all"
      assert new_session.response.query_string =~ "q=test"
    end
  end

  describe "cookie handling" do
    test "starts with empty cookies", %{conn: conn} do
      session = Session.new(conn, "/")

      assert session.cookies == CookieJar.empty()
    end

    test "extracts cookies from response", %{conn: conn} do
      session = Session.new(conn, "/set-cookie")

      # Should have extracted cookies
      assert session.cookies.cookies != %{}
    end

    test "sends cookies in subsequent requests", %{conn: conn} do
      # First request sets a cookie
      session = Session.new(conn, "/set-cookie")
      cookies = session.cookies

      # Second request should send the cookie
      new_session = Session.get(session, "/check-cookie")

      # The session should still have the cookies
      assert new_session.cookies == cookies
    end

    test "merges new cookies with existing ones", %{conn: conn} do
      # First request sets cookie1
      session = Session.new(conn, "/set-cookie")
      initial_cookies = session.cookies

      # Second request sets cookie2
      new_session = Session.get(session, "/set-another-cookie")

      # Should have both cookies
      assert map_size(new_session.cookies.cookies) > map_size(initial_cookies.cookies)
    end

    test "handles cookie deletion (max_age=0)", %{conn: conn} do
      # First request sets a cookie
      session = Session.new(conn, "/set-deletable-cookie")
      assert session.cookies.cookies != %{}
      assert session.cookies.cookies["deletable_cookie"] != nil

      # Second request deletes the cookie
      new_session = Session.get(session, "/delete-cookie")

      # Cookie should be removed
      assert new_session.cookies == CookieJar.empty()
    end
  end
end
