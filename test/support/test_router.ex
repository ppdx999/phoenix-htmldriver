defmodule PhoenixHtmldriver.TestRouter do
  use Plug.Router

  def config(:secret_key_base) do
    "test_secret_key_base_that_is_at_least_64_bytes_long_for_security_purposes"
  end

  def config(_key), do: nil

  plug(Plug.Session,
    store: :cookie,
    key: "_test_session",
    signing_salt: "test_salt"
  )

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(:match)
  plug(:fetch_session)
  plug(:dispatch)

  get "/home" do
    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Welcome Home</h1>
        <a href="/about" id="about-link">About</a>
      </body>
    </html>
    """)
  end

  get "/about" do
    send_resp(conn, 200, """
    <html>
      <body>
        <h1>About Page</h1>
      </body>
    </html>
    """)
  end

  post "/login" do
    username = conn.body_params["username"] || "guest"

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Welcome, #{username}!</p>
      </body>
    </html>
    """)
  end

  get "/search" do
    query = conn.query_params["q"] || ""

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Search results for: #{query}</p>
      </body>
    </html>
    """)
  end

  put "/update" do
    name = conn.body_params["name"] || "unknown"

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Updated: #{name}</p>
      </body>
    </html>
    """)
  end

  patch "/patch" do
    value = conn.body_params["value"] || "default"

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Patched: #{value}</p>
      </body>
    </html>
    """)
  end

  delete "/delete" do
    send_resp(conn, 200, """
    <html>
      <body>
        <p>Deleted successfully</p>
      </body>
    </html>
    """)
  end

  get "/form-with-csrf" do
    # Return a form with CSRF token
    csrf_token = "test-csrf-token-12345"

    send_resp(conn, 200, """
    <html>
      <head>
        <meta name="csrf-token" content="#{csrf_token}">
      </head>
      <body>
        <form id="csrf-form" action="/submit-csrf" method="post">
          <input type="hidden" name="_csrf_token" value="#{csrf_token}">
          <input type="text" name="message">
          <button type="submit">Submit</button>
        </form>
      </body>
    </html>
    """)
  end

  post "/submit-csrf" do
    csrf_token = conn.body_params["_csrf_token"]
    message = conn.body_params["message"] || "no message"

    if csrf_token == "test-csrf-token-12345" do
      send_resp(conn, 200, """
      <html>
        <body>
          <p>CSRF valid: #{message}</p>
        </body>
      </html>
      """)
    else
      send_resp(conn, 403, """
      <html>
        <body>
          <p>CSRF token invalid or missing</p>
        </body>
      </html>
      """)
    end
  end

  get "/form-with-meta-csrf" do
    # Return a form without embedded CSRF, only in meta tag
    csrf_token = "meta-csrf-token-67890"

    send_resp(conn, 200, """
    <html>
      <head>
        <meta name="csrf-token" content="#{csrf_token}">
      </head>
      <body>
        <form id="meta-csrf-form" action="/submit-meta-csrf" method="post">
          <input type="text" name="data">
          <button type="submit">Submit</button>
        </form>
      </body>
    </html>
    """)
  end

  post "/submit-meta-csrf" do
    csrf_token = conn.body_params["_csrf_token"]
    data = conn.body_params["data"] || "no data"

    if csrf_token == "meta-csrf-token-67890" do
      send_resp(conn, 200, """
      <html>
        <body>
          <p>Meta CSRF valid: #{data}</p>
        </body>
      </html>
      """)
    else
      send_resp(conn, 403, """
      <html>
        <body>
          <p>Meta CSRF token invalid or missing</p>
        </body>
      </html>
      """)
    end
  end

  get "/set-session" do
    # Set a value in the session
    conn = put_session(conn, :user_id, "test_user_123")

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Session set</p>
        <a href="/check-session">Check Session</a>
      </body>
    </html>
    """)
  end

  get "/check-session" do
    # Check if session value is preserved
    user_id = get_session(conn, :user_id)

    send_resp(conn, 200, """
    <html>
      <body>
        <p>User ID: #{user_id || "not set"}</p>
      </body>
    </html>
    """)
  end

  get "/login-form" do
    # Return a login form with session
    conn = put_session(conn, :form_loaded, true)

    send_resp(conn, 200, """
    <html>
      <body>
        <form id="login-form" action="/do-login" method="post">
          <input type="text" name="username">
          <button type="submit">Login</button>
        </form>
      </body>
    </html>
    """)
  end

  post "/do-login" do
    username = conn.body_params["username"] || "guest"
    form_loaded = get_session(conn, :form_loaded)

    conn = put_session(conn, :username, username)

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Logged in as: #{username}</p>
        <p>Form was loaded: #{form_loaded}</p>
      </body>
    </html>
    """)
  end

  get "/redirect-source" do
    conn
    |> put_resp_header("location", "/redirect-destination")
    |> send_resp(302, "Redirecting...")
  end

  get "/redirect-destination" do
    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Redirect Destination</h1>
        <p>You were redirected here</p>
      </body>
    </html>
    """)
  end

  post "/login-redirect" do
    username = conn.body_params["username"] || "guest"

    conn
    |> put_session(:username, username)
    |> put_resp_header("location", "/dashboard")
    |> send_resp(302, "Redirecting to dashboard...")
  end

  get "/dashboard" do
    username = get_session(conn, :username) || "anonymous"

    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Dashboard</h1>
        <p>Welcome, #{username}!</p>
      </body>
    </html>
    """)
  end

  get "/redirect-chain-1" do
    conn
    |> put_resp_header("location", "/redirect-chain-2")
    |> send_resp(302, "Redirecting to chain 2...")
  end

  get "/redirect-chain-2" do
    conn
    |> put_resp_header("location", "/redirect-chain-3")
    |> send_resp(302, "Redirecting to chain 3...")
  end

  get "/redirect-chain-3" do
    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Chain End</h1>
        <p>After 3 redirects</p>
      </body>
    </html>
    """)
  end

  # Monoid test endpoints
  get "/set-cookie" do
    conn
    |> put_resp_cookie("test_cookie", "value", max_age: 3600)
    |> send_resp(200, "<html><body>Cookie set</body></html>")
  end

  get "/set-cookie-first" do
    conn
    |> put_resp_cookie("test_cookie", "first", max_age: 3600)
    |> send_resp(200, "<html><body>Cookie first</body></html>")
  end

  get "/set-cookie-second" do
    conn
    |> put_resp_cookie("test_cookie", "second", max_age: 3600)
    |> send_resp(200, "<html><body>Cookie second</body></html>")
  end

  get "/with-session" do
    conn
    |> put_session(:test_key, "test_value")
    |> send_resp(200, "<html><body>Session set</body></html>")
  end

  get "/no-cookies" do
    send_resp(conn, 200, "<html><body>No cookies</body></html>")
  end

  get "/redirect-chain" do
    conn
    |> put_resp_header("location", "/final")
    |> send_resp(302, "Redirecting...")
  end

  get "/final" do
    send_resp(conn, 200, "<html><body>Final destination</body></html>")
  end

  # Cookie deletion test endpoints
  get "/set-deletable-cookie" do
    conn
    |> put_resp_cookie("deletable_cookie", "value", max_age: 3600)
    |> send_resp(200, "<html><body>Cookie set</body></html>")
  end

  get "/delete-cookie" do
    conn
    |> put_resp_cookie("deletable_cookie", "", max_age: 0)
    |> send_resp(200, "<html><body>Cookie deleted (max_age=0)</body></html>")
  end

  get "/delete-cookie-negative" do
    conn
    |> put_resp_cookie("deletable_cookie", "", max_age: -1)
    |> send_resp(200, "<html><body>Cookie deleted (max_age=-1)</body></html>")
  end

  get "/set-multiple-cookies" do
    conn
    |> put_resp_cookie("cookie1", "value1", max_age: 3600)
    |> put_resp_cookie("cookie2", "value2", max_age: 3600)
    |> send_resp(200, "<html><body>Multiple cookies set</body></html>")
  end

  get "/delete-cookie1" do
    conn
    |> put_resp_cookie("cookie1", "", max_age: 0)
    |> send_resp(200, "<html><body>Cookie1 deleted</body></html>")
  end

  get "/logout" do
    conn
    |> configure_session(drop: true)
    |> put_resp_cookie("_test_session", "", max_age: 0)
    |> send_resp(200, "<html><body>Logged out</body></html>")
  end

  # Session test endpoints
  get "/redirect-to-home" do
    conn
    |> put_resp_header("location", "/home")
    |> send_resp(302, "Redirecting...")
  end

  get "/infinite-redirect" do
    conn
    |> put_resp_header("location", "/infinite-redirect")
    |> send_resp(302, "Redirecting...")
  end

  get "/redirect-with-cookie" do
    conn
    |> put_resp_cookie("redirect_cookie", "value", max_age: 3600)
    |> put_resp_header("location", "/home")
    |> send_resp(302, "Redirecting with cookie...")
  end

  get "/check-cookie" do
    cookie_value = conn.req_cookies["test_cookie"] || "no cookie"

    send_resp(conn, 200, """
    <html>
      <body>
        <p>Cookie value: #{cookie_value}</p>
      </body>
    </html>
    """)
  end

  get "/set-another-cookie" do
    conn
    |> put_resp_cookie("another_cookie", "another_value", max_age: 3600)
    |> send_resp(200, "<html><body>Another cookie set</body></html>")
  end

  get "/" do
    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Welcome</h1>
      </body>
    </html>
    """)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
