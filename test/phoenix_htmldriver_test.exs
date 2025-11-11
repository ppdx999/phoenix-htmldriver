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

  describe "basic functionality" do
    test "visits a page" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      assert_text(session, "Welcome Home")
      assert_selector(session, "h1")
    end

    test "clicks a link" do
      conn = build_test_conn()
      session = visit(conn, "/home")

      session = click_link(session, "#about-link")
      assert_text(session, "About Page")
    end

    test "submits a form" do
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

      # Create a mock session with the form
      {:ok, document} = Floki.parse_document(html)
      response = %Plug.Conn{conn | resp_body: html}
      session = %PhoenixHtmldriver.Session{
        conn: conn,
        document: document,
        response: response,
        endpoint: @endpoint
      }

      session = submit_form(session, "#login-form", username: "alice")
      assert_text(session, "Welcome, alice!")
    end
  end
end
