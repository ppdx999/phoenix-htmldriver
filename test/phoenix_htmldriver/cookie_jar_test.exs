defmodule PhoenixHtmldriver.CookieJarTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.CookieJar

  describe "empty/0" do
    test "returns empty map" do
      assert CookieJar.empty() == %{}
    end
  end

  describe "merge/2 - monoid properties" do
    test "identity: merge(empty, a) = a" do
      cookies = %{"session" => %{value: "abc123"}}
      assert CookieJar.merge(CookieJar.empty(), cookies) == cookies
    end

    test "identity: merge(a, empty) = a" do
      cookies = %{"session" => %{value: "abc123"}}
      assert CookieJar.merge(cookies, CookieJar.empty()) == cookies
    end

    test "identity: merge(nil, a) = a" do
      cookies = %{"session" => %{value: "abc123"}}
      assert CookieJar.merge(nil, cookies) == cookies
    end

    test "identity: merge(a, nil) = a" do
      cookies = %{"session" => %{value: "abc123"}}
      assert CookieJar.merge(cookies, nil) == cookies
    end

    test "identity: merge(nil, nil) = empty" do
      assert CookieJar.merge(nil, nil) == %{}
    end

    test "associativity: merge(merge(a, b), c) = merge(a, merge(b, c))" do
      a = %{"cookie1" => %{value: "a"}}
      b = %{"cookie2" => %{value: "b"}}
      c = %{"cookie3" => %{value: "c"}}

      left = CookieJar.merge(CookieJar.merge(a, b), c)
      right = CookieJar.merge(a, CookieJar.merge(b, c))

      assert left == right
    end

    test "right-biased: newer cookie overrides older" do
      old = %{"session" => %{value: "old"}}
      new = %{"session" => %{value: "new"}}

      result = CookieJar.merge(old, new)

      assert result == %{"session" => %{value: "new"}}
    end

    test "multiple cookies are preserved" do
      existing = %{
        "session" => %{value: "session_value"},
        "prefs" => %{value: "dark_mode"}
      }

      new = %{"csrf" => %{value: "token123"}}

      result = CookieJar.merge(existing, new)

      assert map_size(result) == 3
      assert result["session"] == %{value: "session_value"}
      assert result["prefs"] == %{value: "dark_mode"}
      assert result["csrf"] == %{value: "token123"}
    end
  end

  describe "merge/2 - cookie deletion" do
    test "cookies with max_age=0 are deleted" do
      existing = %{"session" => %{value: "abc123"}}
      delete = %{"session" => %{value: "", max_age: 0}}

      result = CookieJar.merge(existing, delete)

      assert result == %{}
    end

    test "cookies with negative max_age are deleted" do
      existing = %{"session" => %{value: "abc123"}}
      delete = %{"session" => %{value: "", max_age: -1}}

      result = CookieJar.merge(existing, delete)

      assert result == %{}
    end

    test "other cookies preserved when one is deleted" do
      existing = %{
        "session" => %{value: "session_value"},
        "prefs" => %{value: "dark_mode"}
      }

      delete = %{"session" => %{value: "", max_age: 0}}

      result = CookieJar.merge(existing, delete)

      assert result == %{"prefs" => %{value: "dark_mode"}}
    end

    test "cookies with max_age > 0 are kept" do
      existing = %{}
      new = %{"session" => %{value: "abc123", max_age: 3600}}

      result = CookieJar.merge(existing, new)

      assert result == %{"session" => %{value: "abc123", max_age: 3600}}
    end

    test "cookies without max_age are kept" do
      existing = %{}
      new = %{"session" => %{value: "abc123"}}

      result = CookieJar.merge(existing, new)

      assert result == %{"session" => %{value: "abc123"}}
    end
  end

  describe "put_into_request/2" do
    test "sets Cookie header with single cookie" do
      conn = Plug.Test.conn(:get, "/")
      cookies = %{"session" => %{value: "abc123"}}

      result = CookieJar.put_into_request(conn, cookies)

      assert Plug.Conn.get_req_header(result, "cookie") == ["session=abc123"]
    end

    test "sets Cookie header with multiple cookies" do
      conn = Plug.Test.conn(:get, "/")

      cookies = %{
        "session" => %{value: "abc123"},
        "prefs" => %{value: "dark"}
      }

      result = CookieJar.put_into_request(conn, cookies)

      [cookie_header] = Plug.Conn.get_req_header(result, "cookie")

      # Cookie order in header doesn't matter, just check both are present
      assert cookie_header =~ "session=abc123"
      assert cookie_header =~ "prefs=dark"
      assert cookie_header =~ "; "
    end

    test "returns unchanged conn for nil cookies" do
      conn = Plug.Test.conn(:get, "/")

      result = CookieJar.put_into_request(conn, nil)

      assert result == conn
      assert Plug.Conn.get_req_header(result, "cookie") == []
    end

    test "returns unchanged conn for empty cookies" do
      conn = Plug.Test.conn(:get, "/")

      result = CookieJar.put_into_request(conn, %{})

      assert result == conn
      assert Plug.Conn.get_req_header(result, "cookie") == []
    end
  end

  describe "extract/1" do
    test "extracts cookies from response" do
      conn = %Plug.Conn{
        resp_cookies: %{
          "session" => %{value: "abc123", max_age: 3600}
        }
      }

      result = CookieJar.extract(conn)

      assert result == %{"session" => %{value: "abc123", max_age: 3600}}
    end

    test "returns empty map when no cookies" do
      conn = %Plug.Conn{resp_cookies: %{}}

      result = CookieJar.extract(conn)

      assert result == %{}
    end
  end
end
