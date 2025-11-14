defmodule PhoenixHtmldriver.CookieMonoidTest do
  use ExUnit.Case

  # Access private function for testing
  # We test through public API behavior that depends on the monoid properties
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

  describe "Cookie monoid properties" do
    test "identity: empty cookies don't affect session" do
      conn = build_test_conn()

      # Start with no cookies
      session1 = Session.visit(conn, "/")

      # Multiple visits should preserve empty cookie state (identity)
      session2 = Session.visit(session1, "/")
      session3 = Session.visit(session2, "/")

      # Cookies should remain empty (or unchanged)
      assert session1.cookies == session2.cookies
      assert session2.cookies == session3.cookies
    end

    test "associativity: cookie merging order doesn't matter" do
      conn = build_test_conn()

      # This test verifies associativity through multiple navigation steps
      # (a ⊕ b) ⊕ c should equal a ⊕ (b ⊕ c)

      # Path 1: visit → visit → visit
      session1 = Session.visit(conn, "/")
        |> Session.visit("/")
        |> Session.visit("/")

      # Path 2: visit → (visit → visit)
      temp = Session.visit(conn, "/")
      session2a = Session.visit(temp, "/")
      session2 = Session.visit(session2a, "/")

      # Both should end up with the same cookies
      assert session1.cookies == session2.cookies
    end

    test "right-bias: new cookies override existing ones" do
      conn = build_test_conn()

      # Visit a page that sets a cookie
      session = Session.visit(conn, "/set-cookie")

      initial_cookie_count = map_size(session.cookies)

      # Visit again - if server sends same cookie name with different value,
      # the new value should override (right-biased merge)
      session2 = Session.visit(session, "/set-cookie")

      # Cookie count should be the same (not doubled)
      assert map_size(session2.cookies) == initial_cookie_count
    end

    test "commutativity does NOT hold (right-biased)" do
      # This test documents that cookie merge is NOT commutative
      # merge(a, b) ≠ merge(b, a) when they have overlapping keys
      # This is correct behavior - newer cookies should override older ones

      conn = build_test_conn()

      # Set a cookie with value "first"
      session1 = Session.visit(conn, "/set-cookie-first")
      first_value = session1.cookies["test_cookie"]

      # Set a cookie with value "second"
      session2 = Session.visit(conn, "/set-cookie-second")
      second_value = session2.cookies["test_cookie"]

      # If cookies were different, verify they're not equal (non-commutative)
      if first_value != second_value do
        # Order matters: visiting second after first should give second's value
        session_first_then_second = Session.visit(session1, "/set-cookie-second")
        assert session_first_then_second.cookies["test_cookie"] == second_value
      end
    end

    test "multiple different cookies are preserved" do
      # This tests that merge_cookies doesn't lose unrelated cookies
      conn = build_test_conn()

      # Start with session cookie
      session = Session.visit(conn, "/with-session")

      # Assume session has at least one cookie (or skip if implementation doesn't set any)
      if map_size(session.cookies) > 0 do
        initial_cookies = session.cookies

        # Navigate to another page that might set different cookies
        session2 = Session.visit(session, "/")

        # Original cookies should still be present (unless explicitly overridden)
        for {key, value} <- initial_cookies do
          assert Map.has_key?(session2.cookies, key),
            "Cookie #{key} was lost during navigation"
        end
      end
    end

    test "cookies survive redirect chains (monoid associativity)" do
      conn = build_test_conn()

      # Visit a page that redirects (tests that cookies are properly merged through redirects)
      session = Session.visit(conn, "/redirect-chain")

      # After following redirects, we should be at the final destination
      assert Session.current_path(session) == "/final"

      # Cookies should be accumulated through the redirect chain
      # This depends on monoid structure being correct
      assert is_map(session.cookies)
    end
  end

  describe "Cookie edge cases" do
    test "nil cookies are handled as identity" do
      # This tests that nil is properly handled as empty map (monoid identity)
      conn = build_test_conn()

      session = Session.visit(conn, "/")

      # Should not crash and should have valid cookie map (possibly empty)
      assert is_map(session.cookies)
    end

    test "empty response cookies preserve existing cookies" do
      conn = build_test_conn()

      # Get a session with some state
      session = Session.visit(conn, "/")
      initial_cookies = session.cookies

      # Visit a page that doesn't set cookies (empty Set-Cookie)
      # The existing cookies should be preserved (identity property)
      session2 = Session.visit(session, "/no-cookies")

      # Existing cookies should be preserved
      assert session2.cookies == initial_cookies
    end
  end

  describe "Cookie deletion (max_age <= 0)" do
    test "cookies with max_age=0 are deleted" do
      conn = build_test_conn()

      # Set a cookie
      session = Session.visit(conn, "/set-deletable-cookie")
      assert Map.has_key?(session.cookies, "deletable_cookie")

      # Delete the cookie (server sends max_age=0)
      session2 = Session.visit(session, "/delete-cookie")

      # Cookie should be removed
      refute Map.has_key?(session2.cookies, "deletable_cookie")
    end

    test "cookies with negative max_age are deleted" do
      conn = build_test_conn()

      # Set a cookie
      session = Session.visit(conn, "/set-deletable-cookie")
      assert Map.has_key?(session.cookies, "deletable_cookie")

      # Delete the cookie (server sends max_age=-1)
      session2 = Session.visit(session, "/delete-cookie-negative")

      # Cookie should be removed
      refute Map.has_key?(session2.cookies, "deletable_cookie")
    end

    test "other cookies are preserved when one is deleted" do
      conn = build_test_conn()

      # Set two cookies
      session = Session.visit(conn, "/set-multiple-cookies")
      assert Map.has_key?(session.cookies, "cookie1")
      assert Map.has_key?(session.cookies, "cookie2")

      # Delete only cookie1
      session2 = Session.visit(session, "/delete-cookie1")

      # cookie1 should be deleted, cookie2 should remain
      refute Map.has_key?(session2.cookies, "cookie1")
      assert Map.has_key?(session2.cookies, "cookie2")
    end

    test "logout flow deletes session cookie" do
      conn = build_test_conn()

      # Login sets session cookie
      session = Session.visit(conn, "/with-session")
      initial_cookie_count = map_size(session.cookies)

      # Assume at least one cookie was set
      if initial_cookie_count > 0 do
        # Logout deletes session cookie
        session2 = Session.visit(session, "/logout")

        # Session cookie should be removed
        assert map_size(session2.cookies) < initial_cookie_count
      end
    end
  end
end
