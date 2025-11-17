defmodule PhoenixHtmldriverTest do
  use ExUnit.Case

  import PhoenixHtmldriver

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
    test "visits a page and returns a session" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert %PhoenixHtmldriver.Session{} = session
      assert session.endpoint == @endpoint
      assert session.response.status == 200
    end

    test "visits a page with text content" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_text(session, "Welcome Home")
    end

    test "visits a page with HTML elements" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_selector(session, "h1")
      assert_selector(session, "a")
    end
  end

  describe "click_link/2" do
    test "clicks a link by CSS selector" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      session = click_link(session, "#about-link")
      assert_text(session, "About Page")
      assert current_path(session) == "/about"
    end

    test "clicks a link by text content" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      session = click_link(session, "About")
      assert_text(session, "About Page")
    end

    test "raises when link not found by selector" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_raise RuntimeError, ~r/Link not found/, fn ->
        click_link(session, "#nonexistent-link")
      end
    end

    test "raises when link not found by text" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_raise RuntimeError, ~r/Link not found/, fn ->
        click_link(session, "Nonexistent Link Text")
      end
    end
  end

  describe "Form API" do
    alias PhoenixHtmldriver.Form

    setup do
      conn = build_test_conn()

      html = """
      <html>
        <body>
          <form id="login-form" action="/login" method="post">
            <input type="text" name="username" />
            <input type="submit" value="Login" />
          </form>
        </body>
      </html>
      """

      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}

      session = %PhoenixHtmldriver.Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint,
        cookies: %{},
        path: "/"
      }

      {:ok, session: session}
    end

    test "submits a form with values", %{session: session} do
      session =
        session
        |> form("#login-form")
        |> Form.fill(username: "alice") |> Form.submit()

      assert_text(session, "Welcome, alice!")
    end

    test "submits a form without explicit values", %{session: session} do
      # Form has <input name="username" /> with no value attribute
      # FormParser extracts this as username: ""
      # When submitted, it sends username="" (empty string)
      # Server uses: username = params["username"] || "guest"
      # Since "" is truthy in Elixir, it uses "" not "guest"
      session =
        session
        |> form("#login-form")
        |> Form.submit()

      assert_text(session, "Welcome, !")
    end

    test "raises when form not found", %{session: session} do
      assert_raise RuntimeError, ~r/Form not found/, fn ->
        form(session, "#nonexistent-form")
      end
    end
  end

  describe "assert_text/2" do
    test "passes when text is present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_text(session, "Welcome Home")
    end

    test "fails when text is not present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_raise ExUnit.AssertionError, fn ->
        assert_text(session, "Nonexistent Text")
      end
    end

    test "returns session for chaining" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      result = assert_text(session, "Welcome Home")
      assert result == session
    end
  end

  describe "assert_selector/2" do
    test "passes when element is present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_selector(session, "h1")
    end

    test "passes when element with id is present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_selector(session, "#about-link")
    end

    test "fails when element is not present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_raise ExUnit.AssertionError, fn ->
        assert_selector(session, ".nonexistent-class")
      end
    end

    test "returns session for chaining" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      result = assert_selector(session, "h1")
      assert result == session
    end
  end

  describe "refute_selector/2" do
    test "passes when element is not present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      refute_selector(session, ".nonexistent-class")
    end

    test "fails when element is present" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_raise ExUnit.AssertionError, fn ->
        refute_selector(session, "h1")
      end
    end

    test "returns session for chaining" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      result = refute_selector(session, ".nonexistent")
      assert result == session
    end
  end

  describe "find/2" do
    test "finds an element by selector" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert {:ok, element} = find(session, "h1")
      assert %PhoenixHtmldriver.Element{} = element
    end

    test "returns error when element not found" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert {:error, message} = find(session, ".nonexistent")
      assert message =~ "Element not found"
    end
  end

  describe "find_all/2" do
    test "finds all matching elements" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      elements = find_all(session, "a")
      assert length(elements) == 1
      assert Enum.all?(elements, &match?(%PhoenixHtmldriver.Element{}, &1))
    end

    test "returns empty list when no elements found" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      elements = find_all(session, ".nonexistent")
      assert elements == []
    end
  end

  describe "current_path/1" do
    test "returns the current request path" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert current_path(session) == "/home"
    end

    test "returns updated path after navigation" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      session = click_link(session, "#about-link")
      assert current_path(session) == "/about"
    end
  end

  describe "current_html/1" do
    test "returns the current response HTML" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      html = current_html(session)
      assert html =~ "Welcome Home"
      assert html =~ "<h1>"
    end
  end

  describe "chaining operations" do
    test "chains multiple operations together" do
      conn = build_test_conn()

      visit(conn, "/home")
      |> assert_text("Welcome Home")
      |> assert_selector("h1")
      |> click_link("#about-link")
      |> assert_text("About Page")
      |> refute_selector("#about-link")
    end
  end
end
