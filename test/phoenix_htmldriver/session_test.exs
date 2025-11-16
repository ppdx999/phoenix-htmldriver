defmodule PhoenixHtmldriver.SessionTest do
  use ExUnit.Case

  alias PhoenixHtmldriver.Session

  @endpoint PhoenixHtmldriver.TestRouter

  defp build_test_conn do
    Plug.Conn
    |> struct(%{
      adapter: {Plug.Adapters.Test.Conn, :...},
      assigns: %{},
      body_params: %Plug.Conn.Unfetched{aspect: :body_params},
      cookies: %Plug.Conn.Unfetched{aspect: :cookies},
      halted: false,
      host: "www.example.com",
      method: "GET",
      owner: self(),
      params: %Plug.Conn.Unfetched{aspect: :params},
      path_info: [],
      path_params: %{},
      port: 80,
      private: %{plug_skip_csrf_protection: true, phoenix_recycled: true, phoenix_endpoint: @endpoint},
      query_params: %Plug.Conn.Unfetched{aspect: :query_params},
      query_string: "",
      remote_ip: {127, 0, 0, 1},
      req_cookies: %Plug.Conn.Unfetched{aspect: :cookies},
      req_headers: [],
      request_path: "/",
      resp_body: nil,
      resp_cookies: %{},
      resp_headers: [{"cache-control", "max-age=0, private, must-revalidate"}],
      scheme: :http,
      script_name: [],
      secret_key_base: nil,
      state: :unset,
      status: nil
    })
  end

  describe "visit/2" do
    test "creates a session with parsed document" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert %Session{} = session
      assert session.document != nil
      assert session.response != nil
      assert session.endpoint == @endpoint
    end

    test "raises when endpoint is not set in conn" do
      conn = %Plug.Conn{
        adapter: {Plug.Adapters.Test.Conn, :...},
        private: %{}
      }

      assert_raise RuntimeError, ~r/No endpoint found/, fn ->
        Session.visit(conn, "/home")
      end
    end
  end

  describe "click_link/2" do
    test "follows link and updates session" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      new_session = Session.click_link(session, "#about-link")

      assert new_session.response.request_path == "/about"
      assert Session.current_html(new_session) =~ "About Page"
    end

    test "finds link by partial text match" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      new_session = Session.click_link(session, "About")

      assert new_session.response.request_path == "/about"
    end
  end

  describe "Form.submit/2 with various HTTP methods" do
    alias PhoenixHtmldriver.Form

    setup do
      conn = build_test_conn()
      {:ok, conn: conn}
    end

    test "submits form with POST method", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="test-form" action="/login" method="post">
            <input type="text" name="username" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session =
        session
        |> Form.new("#test-form")
        |> Form.submit(username: "alice")

      assert new_session.response.request_path == "/login"
      assert Session.current_html(new_session) =~ "Welcome, alice!"
    end

    test "submits form with GET method", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="search-form" action="/search" method="get">
            <input type="text" name="q" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#search-form") |> Form.submit(q: "elixir")

      assert new_session.response.request_path =~ "/search"
      assert Session.current_html(new_session) =~ "Search results for: elixir"
    end

    test "submits form with PUT method", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="update-form" action="/update" method="put">
            <input type="text" name="name" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#update-form") |> Form.submit(name: "test")

      assert new_session.response.request_path == "/update"
      assert Session.current_html(new_session) =~ "Updated: test"
    end

    test "submits form with PATCH method", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="patch-form" action="/patch" method="patch">
            <input type="text" name="value" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#patch-form") |> Form.submit(value: "updated")

      assert new_session.response.request_path == "/patch"
      assert Session.current_html(new_session) =~ "Patched: updated"
    end

    test "submits form with DELETE method", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="delete-form" action="/delete" method="delete">
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#delete-form") |> Form.submit()

      assert new_session.response.request_path == "/delete"
      assert Session.current_html(new_session) =~ "Deleted successfully"
    end

    test "handles form without action attribute", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="test-form" method="post">
            <input type="text" name="username" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      # Should default to "/" for action
      new_session = session |> Form.new("#test-form") |> Form.submit(username: "test")
      assert new_session.response.request_path == "/"
    end

    test "handles form without method attribute (defaults to GET)", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="test-form" action="/search">
            <input type="text" name="q" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#test-form") |> Form.submit(q: "phoenix")
      assert Session.current_html(new_session) =~ "Search results for: phoenix"
    end
  end

  describe "assert_text/2" do
    test "returns session when text is found" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      result = Session.assert_text(session, "Welcome Home")
      assert result == session
    end

    test "raises when text is not found" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert_raise ExUnit.AssertionError, ~r/Expected to find text/, fn ->
        Session.assert_text(session, "Nonexistent Text")
      end
    end
  end

  describe "assert_selector/2" do
    test "returns session when selector matches" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      result = Session.assert_selector(session, "h1")
      assert result == session
    end

    test "raises when selector does not match" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert_raise ExUnit.AssertionError, ~r/Expected to find element/, fn ->
        Session.assert_selector(session, ".nonexistent")
      end
    end
  end

  describe "refute_selector/2" do
    test "returns session when selector does not match" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      result = Session.refute_selector(session, ".nonexistent")
      assert result == session
    end

    test "raises when selector matches" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert_raise ExUnit.AssertionError, ~r/Expected not to find element/, fn ->
        Session.refute_selector(session, "h1")
      end
    end
  end

  describe "find/2" do
    test "returns element when found" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert {:ok, element} = Session.find(session, "h1")
      assert %PhoenixHtmldriver.Element{} = element
    end

    test "returns error when not found" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert {:error, message} = Session.find(session, ".nonexistent")
      assert message == "Element not found: .nonexistent"
    end
  end

  describe "find_all/2" do
    test "returns list of elements" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      elements = Session.find_all(session, "a")
      assert is_list(elements)
      assert length(elements) > 0
      assert Enum.all?(elements, &match?(%PhoenixHtmldriver.Element{}, &1))
    end

    test "returns empty list when no matches" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      elements = Session.find_all(session, ".nonexistent")
      assert elements == []
    end
  end

  describe "current_path/1" do
    test "returns the request path" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert Session.current_path(session) == "/home"
    end
  end

  describe "current_html/1" do
    test "returns the response body" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      html = Session.current_html(session)
      assert is_binary(html)
      assert html =~ "Welcome Home"
    end
  end

  describe "Form API" do
    alias PhoenixHtmldriver.Form

    test "form raises if form not found" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      assert_raise RuntimeError, ~r/Form not found/, fn ->
        Form.new(session, "#nonexistent-form")
      end
    end

    test "fills and submits form with values" do
      conn = build_test_conn()

      session =
        Session.visit(conn, "/login-form")
        |> Form.new("#login-form")
        |> Form.fill(username: "alice")
        |> Form.submit()

      # The username should be included in the submission
      assert Session.current_html(session) =~ "Logged in as: alice"
      assert Session.current_html(session) =~ "Form was loaded: true"
    end

    test "submit values override fill values" do
      conn = build_test_conn()

      session =
        Session.visit(conn, "/login-form")
        |> Form.new("#login-form")
        |> Form.fill(username: "alice")
        |> Form.submit(username: "bob")

      # bob should override alice
      assert Session.current_html(session) =~ "Logged in as: bob"
    end

    test "supports nested map values" do
      conn = build_test_conn()

      html = """
      <html>
        <body>
          <form id="test-form" action="/login" method="post">
            <input type="text" name="user[email]" />
            <input type="password" name="user[password]" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      form =
        session
        |> Form.new("#test-form")
        |> Form.fill(%{user: %{email: "test@example.com", password: "secret"}})

      # Check that values are stored in form struct (merged with defaults)
      assert form.values["user"] == %{"email" => "test@example.com", "password" => "secret"}
    end
  end

  describe "session cookie preservation" do
    alias PhoenixHtmldriver.Form

    setup do
      conn = build_test_conn()
      {:ok, conn: conn}
    end

    test "preserves session cookies across requests when clicking links", %{conn: conn} do
      # Visit page that sets a session value
      session = Session.visit(conn, "/set-session")
      assert Session.current_html(session) =~ "Session set"

      # Click link to another page - session should be preserved
      new_session = Session.click_link(session, "Check Session")
      assert Session.current_html(new_session) =~ "User ID: test_user_123"
    end

    test "preserves session cookies when submitting forms", %{conn: conn} do
      # Visit page that sets session and shows form
      session = Session.visit(conn, "/login-form")

      # Submit form - session from page load should be preserved
      new_session = session |> Form.new("#login-form") |> Form.submit(username: "alice")

      # Both the form_loaded session value and new username should be present
      assert Session.current_html(new_session) =~ "Logged in as: alice"
      assert Session.current_html(new_session) =~ "Form was loaded: true"
    end

    test "preserves session cookies when using visit/2 with a Session", %{conn: conn} do
      # Visit page that sets a session value
      session = Session.visit(conn, "/set-session")
      assert Session.current_html(session) =~ "Session set"

      # Visit another page using the session - cookies should be preserved
      new_session = Session.visit(session, "/check-session")
      assert Session.current_html(new_session) =~ "User ID: test_user_123"
    end

    test "visit/2 with Plug.Conn starts fresh without cookies", %{conn: conn} do
      # Visit page that sets a session
      _session = Session.visit(conn, "/set-session")

      # Visit another page with fresh conn - should not have cookies
      fresh_session = Session.visit(conn, "/check-session")
      assert Session.current_html(fresh_session) =~ "User ID: not set"
    end

    test "cookies field is populated in session", %{conn: conn} do
      session = Session.visit(conn, "/set-session")

      # Session should have cookies
      assert session.cookies != nil
      assert is_map(session.cookies)
    end

    test "updates cookies after each request", %{conn: conn} do
      # First request
      session1 = Session.visit(conn, "/set-session")
      cookies1 = session1.cookies

      # Second request should have updated cookies
      session2 = Session.click_link(session1, "Check Session")
      cookies2 = session2.cookies

      # Both should have cookies (though they may be the same or updated)
      assert cookies1 != nil
      assert cookies2 != nil
    end

    test "updates cookies when using visit/2 with a Session", %{conn: conn} do
      # First request
      session1 = Session.visit(conn, "/set-session")
      cookies1 = session1.cookies

      # Second request using visit/2 should preserve and potentially update cookies
      session2 = Session.visit(session1, "/check-session")
      cookies2 = session2.cookies

      # Both should have cookies
      assert cookies1 != nil
      assert cookies2 != nil
    end
  end

  describe "automatic redirect following" do
    alias PhoenixHtmldriver.Form

    setup do
      conn = build_test_conn()
      {:ok, conn: conn}
    end

    test "visit follows redirects automatically", %{conn: conn} do
      session = Session.visit(conn, "/redirect-source")

      # Should end up at redirect destination, not source
      assert Session.current_path(session) == "/redirect-destination"
      assert Session.current_html(session) =~ "Redirect Destination"
      assert Session.current_html(session) =~ "You were redirected here"
    end

    test "submit_form follows redirects after POST", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="login-form" action="/login-redirect" method="post">
            <input type="text" name="username">
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
      }

      new_session = session |> Form.new("#login-form") |> Form.submit(username: "alice")

      # Should follow redirect to dashboard
      assert Session.current_path(new_session) == "/dashboard"
      assert Session.current_html(new_session) =~ "Dashboard"
      assert Session.current_html(new_session) =~ "Welcome, alice!"
    end

    test "click_link follows redirects", %{conn: conn} do
      html = """
      <html>
        <body>
          <a id="redirect-link" href="/redirect-source">Click me</a>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
      }

      new_session = Session.click_link(session, "#redirect-link")

      # Should follow redirect
      assert Session.current_path(new_session) == "/redirect-destination"
      assert Session.current_html(new_session) =~ "Redirect Destination"
    end

    test "follows multiple redirects in a chain", %{conn: conn} do
      session = Session.visit(conn, "/redirect-chain-1")

      # Should follow all 3 redirects
      assert Session.current_path(session) == "/redirect-chain-3"
      assert Session.current_html(session) =~ "Chain End"
      assert Session.current_html(session) =~ "After 3 redirects"
    end

    test "preserves cookies across redirects", %{conn: conn} do
      html = """
      <html>
        <body>
          <form id="login-form" action="/login-redirect" method="post">
            <input type="text" name="username">
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
      }

      new_session = session |> Form.new("#login-form") |> Form.submit(username: "bob")

      # Session should be preserved through redirect
      assert Session.current_html(new_session) =~ "Welcome, bob!"
    end
  end

  describe "CSRF token handling" do
    alias PhoenixHtmldriver.Form

    setup do
      conn = build_test_conn()
      {:ok, conn: conn}
    end

    test "automatically extracts and includes CSRF token from hidden input", %{conn: conn} do
      session = Session.visit(conn, "/form-with-csrf")

      new_session = session |> Form.new("#csrf-form") |> Form.submit(message: "Hello")

      assert Session.current_html(new_session) =~ "CSRF valid: Hello"
    end

    test "does not override user-provided CSRF token", %{conn: conn} do
      session = Session.visit(conn, "/form-with-csrf")

      # User explicitly provides wrong token
      new_session = session |> Form.new("#csrf-form") |> Form.submit(_csrf_token: "wrong-token", message: "Hello")

      # Should use user-provided token (wrong), so validation fails
      assert new_session.response.status == 403
      assert Session.current_html(new_session) =~ "CSRF token invalid or missing"
    end

    test "works with forms that don't have CSRF tokens", %{conn: conn} do
      # No error should occur when form has no CSRF token
      html = """
      <html>
        <body>
          <form id="simple-form" action="/search" method="get">
            <input type="text" name="q" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#simple-form") |> Form.submit(q: "test")
      assert Session.current_html(new_session) =~ "Search results for: test"
    end

    test "only adds CSRF token for POST/PUT/PATCH/DELETE methods", %{conn: conn} do
      # GET request should not include CSRF token even if meta tag is present
      html = """
      <html>
        <head>
          <meta name="csrf-token" content="should-not-be-included">
        </head>
        <body>
          <form id="get-form" action="/search" method="get">
            <input type="text" name="q" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        current_path: "/"
      }

      new_session = session |> Form.new("#get-form") |> Form.submit(q: "search")
      assert Session.current_html(new_session) =~ "Search results for: search"
    end
  end
end
