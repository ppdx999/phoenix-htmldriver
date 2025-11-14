defmodule PhoenixHtmldriver.HTTPTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.{HTTP, CookieJar}

  @endpoint PhoenixHtmldriver.TestRouter

  describe "build_conn/4" do
    test "creates GET conn without params" do
      conn = HTTP.build_conn(:get, "/test", @endpoint)

      assert conn.method == "GET"
      assert conn.request_path == "/test"
      assert conn.params == %Plug.Conn.Unfetched{aspect: :params}
    end

    test "creates POST conn with params" do
      conn = HTTP.build_conn(:post, "/test", @endpoint, %{name: "Alice"})

      assert conn.method == "POST"
      assert conn.request_path == "/test"
      assert conn.params == %{"name" => "Alice"}
    end

    test "sets secret_key_base from endpoint" do
      conn = HTTP.build_conn(:get, "/test", @endpoint)

      assert conn.secret_key_base ==
               "test_secret_key_base_that_is_at_least_64_bytes_long_for_security_purposes"
    end

    test "supports different HTTP methods" do
      for method <- [:get, :post, :put, :patch, :delete] do
        conn = HTTP.build_conn(method, "/test", @endpoint)
        assert conn.method == String.upcase(to_string(method))
      end
    end
  end

  describe "perform_request/5" do
    test "performs GET request and returns response, cookies, document" do
      {response, cookies, document} =
        HTTP.perform_request(:get, "/home", @endpoint, CookieJar.empty())

      assert response.status == 200
      assert response.request_path == "/home"
      assert is_map(cookies)
      assert is_list(document)
      assert Floki.text(document) =~ "Welcome Home"
    end

    test "performs POST request with params" do
      {response, cookies, document} =
        HTTP.perform_request(:post, "/login", @endpoint, CookieJar.empty(), %{
          username: "alice"
        })

      assert response.status == 200
      assert is_map(cookies)
      assert Floki.text(document) =~ "Welcome, alice!"
    end

    test "preserves cookies through request" do
      # First request sets a cookie
      {_response, cookies, _document} =
        HTTP.perform_request(:get, "/with-session", @endpoint, CookieJar.empty())

      cookie_count = map_size(cookies)
      assert cookie_count > 0

      # Second request preserves the cookie
      {_response, cookies2, _document} =
        HTTP.perform_request(:get, "/check-session", @endpoint, cookies)

      assert map_size(cookies2) >= cookie_count
    end

    test "follows redirects automatically" do
      {response, _cookies, document} =
        HTTP.perform_request(:get, "/redirect-source", @endpoint, CookieJar.empty())

      # Should have followed redirect to /redirect-destination
      assert response.status == 200
      assert response.request_path == "/redirect-destination"
      assert Floki.text(document) =~ "Redirect Destination"
    end

    test "merges cookies from redirect response" do
      {_response, cookies, _document} =
        HTTP.perform_request(:get, "/redirect-with-cookie", @endpoint, CookieJar.empty())

      # Should have cookies from both redirect and final response
      assert is_map(cookies)
    end
  end

  describe "follow_redirects/4" do
    test "returns non-redirect response as-is" do
      conn = HTTP.build_conn(:get, "/home", @endpoint)
      response = @endpoint.call(conn, [])
      cookies = CookieJar.empty()

      {final_response, final_cookies} = HTTP.follow_redirects(response, cookies, @endpoint)

      assert final_response.status == 200
      assert final_response == response
      assert final_cookies == cookies
    end

    test "follows single redirect" do
      conn = HTTP.build_conn(:get, "/redirect-source", @endpoint)
      response = @endpoint.call(conn, [])
      cookies = CookieJar.empty()

      {final_response, _final_cookies} = HTTP.follow_redirects(response, cookies, @endpoint)

      assert final_response.status == 200
      assert final_response.request_path == "/redirect-destination"
    end

    test "follows redirect chain" do
      conn = HTTP.build_conn(:get, "/redirect-chain-1", @endpoint)
      response = @endpoint.call(conn, [])
      cookies = CookieJar.empty()

      {final_response, _final_cookies} = HTTP.follow_redirects(response, cookies, @endpoint)

      assert final_response.status == 200
      assert final_response.request_path == "/redirect-chain-3"
    end

    test "preserves and merges cookies through redirects" do
      # Start with a cookie
      initial_cookies = %{"test_cookie" => %{value: "initial_value"}}

      conn = HTTP.build_conn(:get, "/redirect-source", @endpoint)
      response = @endpoint.call(conn, [])

      {_final_response, final_cookies} =
        HTTP.follow_redirects(response, initial_cookies, @endpoint)

      # Initial cookie should be preserved
      assert Map.has_key?(final_cookies, "test_cookie")
    end

    test "raises on too many redirects" do
      # Create a mock response that redirects to itself infinitely
      conn =
        HTTP.build_conn(:get, "/redirect-loop", @endpoint)
        |> Plug.Conn.put_resp_header("location", "/redirect-loop")
        |> Plug.Conn.resp(302, "Redirecting...")
        |> Plug.Conn.send_resp()

      cookies = CookieJar.empty()

      assert_raise RuntimeError, "Too many redirects (max 5)", fn ->
        HTTP.follow_redirects(conn, cookies, @endpoint, 1)
      end
    end

    test "raises on redirect without Location header" do
      conn =
        HTTP.build_conn(:get, "/test", @endpoint)
        |> Plug.Conn.resp(302, "Redirecting...")
        |> Plug.Conn.send_resp()

      cookies = CookieJar.empty()

      assert_raise RuntimeError, "Redirect response missing Location header", fn ->
        HTTP.follow_redirects(conn, cookies, @endpoint)
      end
    end

    test "handles all redirect status codes" do
      for status <- [301, 302, 303, 307, 308] do
        conn =
          HTTP.build_conn(:get, "/test", @endpoint)
          |> Plug.Conn.put_resp_header("location", "/home")
          |> Plug.Conn.resp(status, "Redirecting...")
          |> Plug.Conn.send_resp()

        cookies = CookieJar.empty()

        {final_response, _} = HTTP.follow_redirects(conn, cookies, @endpoint)

        assert final_response.status == 200
        assert final_response.request_path == "/home"
      end
    end
  end
end
