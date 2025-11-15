defmodule PhoenixHtmldriver.EncryptedSessionReproductionTest do
  use ExUnit.Case
  alias PhoenixHtmldriver.Session

  @endpoint PhoenixHtmldriver.EncryptedSessionRouter

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

  describe "Encrypted session - reproducing issue #7" do
    alias PhoenixHtmldriver.Form

    test "Form.submit works, and subsequent visit preserves session" do
      conn = build_test_conn()

      # Step 1: Login successfully (this works)
      session =
        Session.visit(conn, "/login")
        |> Form.new("form")
        |> Form.fill(%{
          email: "test@example.com",
          password: "Password123"
        })
        |> Form.submit()

      # Should be redirected to home and authenticated
      assert Session.current_path(session) == "/"
      assert Session.current_html(session) =~ "User: user_123"

      # Step 2: Visit /login again (should redirect to / because already logged in)
      # This is the failing case reported in issue #7
      session2 = Session.visit(session, "/login")

      # Expected: Should redirect to "/" because user is already logged in
      # Actual (reported bug): Stays at "/login" with new session cookie
      assert Session.current_path(session2) == "/",
             "Expected to be redirected to / but got #{Session.current_path(session2)}"

      # Verify session was preserved (cookie value should be same or at least user still logged in)
      assert Session.current_html(session2) =~ "User: user_123",
             "Expected to still be logged in"
    end
  end
end
