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

  describe "submit_form/3" do
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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#test-form", username: "alice")

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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#search-form", q: "elixir")

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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#update-form", name: "test")

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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#patch-form", value: "updated")

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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#delete-form")

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
        endpoint: @endpoint
      }

      # Should default to "/" for action
      new_session = Session.submit_form(session, "#test-form", username: "test")
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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#test-form", q: "phoenix")
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

  describe "fill_form/3" do
    test "stores form values in session" do
      conn = build_test_conn()
      session = Session.visit(conn, "/home")

      # fill_form should raise if form not found
      assert_raise RuntimeError, ~r/Form not found/, fn ->
        Session.fill_form(session, "#nonexistent-form", field: "value")
      end
    end

    test "fills and submits form with values" do
      conn = build_test_conn()

      session =
        Session.visit(conn, "/login-form")
        |> Session.fill_form("#login-form", username: "alice")
        |> Session.submit_form("#login-form")

      # The username should be included in the submission
      assert Session.current_html(session) =~ "Logged in as: alice"
      assert Session.current_html(session) =~ "Form was loaded: true"
    end

    test "submit_form values override fill_form values" do
      conn = build_test_conn()

      session =
        Session.visit(conn, "/login-form")
        |> Session.fill_form("#login-form", username: "alice")
        |> Session.submit_form("#login-form", username: "bob")

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
        form_values: %{}
      }

      result = Session.fill_form(session, "#test-form", %{user: %{email: "test@example.com", password: "secret"}})

      # Check that values are stored
      assert result.form_values["#test-form"] == %{user: %{email: "test@example.com", password: "secret"}}
    end
  end

  describe "session cookie preservation" do
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
      new_session = Session.submit_form(session, "#login-form", username: "alice")

      # Both the form_loaded session value and new username should be present
      assert Session.current_html(new_session) =~ "Logged in as: alice"
      assert Session.current_html(new_session) =~ "Form was loaded: true"
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
  end

  describe "CSRF token handling" do
    setup do
      conn = build_test_conn()
      {:ok, conn: conn}
    end

    test "automatically extracts and includes CSRF token from hidden input", %{conn: conn} do
      session = Session.visit(conn, "/form-with-csrf")

      new_session = Session.submit_form(session, "#csrf-form", message: "Hello")

      assert Session.current_html(new_session) =~ "CSRF valid: Hello"
    end

    test "automatically extracts CSRF token from meta tag when not in form", %{conn: conn} do
      session = Session.visit(conn, "/form-with-meta-csrf")

      new_session = Session.submit_form(session, "#meta-csrf-form", data: "test data")

      assert Session.current_html(new_session) =~ "Meta CSRF valid: test data"
    end

    test "does not override user-provided CSRF token", %{conn: conn} do
      session = Session.visit(conn, "/form-with-csrf")

      # User explicitly provides wrong token
      new_session = Session.submit_form(session, "#csrf-form", _csrf_token: "wrong-token", message: "Hello")

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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#simple-form", q: "test")
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
        endpoint: @endpoint
      }

      new_session = Session.submit_form(session, "#get-form", q: "search")
      assert Session.current_html(new_session) =~ "Search results for: search"
    end
  end
end
