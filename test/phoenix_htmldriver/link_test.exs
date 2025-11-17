defmodule PhoenixHtmldriver.LinkTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.{Link, Session}

  @endpoint PhoenixHtmldriver.TestRouter

  defp build_session_with_links(html) do
    # Create a mock session with the given HTML
    conn = Plug.Test.conn(:get, "/")
    |> put_in([Access.key!(:secret_key_base)], @endpoint.config(:secret_key_base))

    {:ok, document} = Floki.parse_document(html)

    %Session{
      conn: conn,
      document: document,
      response: %Plug.Conn{conn | status: 200, resp_body: html, request_path: "/test"},
      endpoint: @endpoint,
      cookies: %{},
      path: "/test"
    }
  end

  describe "new/2" do
    test "finds link by CSS selector" do
      html = """
      <div>
        <a id="profile-link" href="/profile">Profile</a>
        <a class="nav-link" href="/home">Home</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "#profile-link")

      assert link.endpoint == @endpoint
      assert link.cookies == %{}
      assert link.path == "/test"
    end

    test "finds link by text content" do
      html = """
      <div>
        <a href="/login">Login</a>
        <a href="/signup">Sign Up</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Login")

      assert link.endpoint == @endpoint
    end

    test "prefers CSS selector over text when both match" do
      html = """
      <div>
        <a id="login-link" href="/login">Login</a>
        <a href="/other">Login</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "#login-link")

      # Should find by selector, not by text
      assert link.node == {"a", [{"id", "login-link"}, {"href", "/login"}], ["Login"]}
    end

    test "finds link by class selector" do
      html = """
      <div>
        <a class="nav-link" href="/home">Home</a>
        <a class="nav-link" href="/about">About</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "a.nav-link")

      # Should find first matching element
      assert link.node == {"a", [{"class", "nav-link"}, {"href", "/home"}], ["Home"]}
    end

    test "finds link by text with whitespace" do
      html = """
      <div>
        <a href="/login">
          Login
        </a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Login")

      assert link.endpoint == @endpoint
    end

    test "raises when link not found by selector" do
      html = """
      <div>
        <a href="/home">Home</a>
      </div>
      """

      session = build_session_with_links(html)

      assert_raise RuntimeError, "Link not found: #missing-link", fn ->
        Link.new(session, "#missing-link")
      end
    end

    test "raises when link not found by text" do
      html = """
      <div>
        <a href="/home">Home</a>
      </div>
      """

      session = build_session_with_links(html)

      assert_raise RuntimeError, "Link not found: Nonexistent Link", fn ->
        Link.new(session, "Nonexistent Link")
      end
    end

    test "finds link with multiple attributes" do
      html = """
      <div>
        <a id="profile" class="user-link" href="/users/123" data-id="123">View Profile</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "#profile")

      assert link.endpoint == @endpoint
    end

    test "finds link inside nested elements" do
      html = """
      <nav>
        <ul>
          <li>
            <a href="/dashboard">Dashboard</a>
          </li>
        </ul>
      </nav>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Dashboard")

      assert link.endpoint == @endpoint
    end
  end

  describe "click/1" do
    test "clicks link and returns Session" do
      html = """
      <div>
        <a id="home-link" href="/home">Home</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "#home-link")

      result = Link.click(link)

      assert %Session{} = result
      assert result.endpoint == @endpoint
    end

    test "uses href attribute as path" do
      html = """
      <div>
        <a href="/profile">Profile</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Profile")

      result = Link.click(link)

      assert %Session{} = result
    end

    test "defaults to / when href is missing" do
      html = """
      <div>
        <a id="no-href">Click Me</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "#no-href")

      result = Link.click(link)

      assert %Session{} = result
    end

    test "handles absolute paths" do
      html = """
      <div>
        <a href="/users/123/edit">Edit User</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Edit User")

      result = Link.click(link)

      assert %Session{} = result
    end

    test "handles paths with query strings" do
      html = """
      <div>
        <a href="/search?q=test">Search</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Search")

      result = Link.click(link)

      assert %Session{} = result
    end

    test "handles paths with anchors" do
      html = """
      <div>
        <a href="/page#section">Go to Section</a>
      </div>
      """

      session = build_session_with_links(html)
      link = Link.new(session, "Go to Section")

      result = Link.click(link)

      assert %Session{} = result
    end
  end
end
