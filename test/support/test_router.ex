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

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
