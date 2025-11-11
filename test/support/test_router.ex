defmodule PhoenixHtmldriver.TestRouter do
  use Plug.Router

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(:match)
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

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
