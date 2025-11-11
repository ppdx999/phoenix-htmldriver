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

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
