defmodule PhoenixHtmldriver.EncryptedSessionRouter do
  @moduledoc """
  Router with encrypted session configuration (like real Phoenix apps with phx.gen.auth)
  """
  use Plug.Router

  def config(:secret_key_base) do
    "test_secret_key_base_that_is_at_least_64_bytes_long_for_security_purposes"
  end

  def config(_key), do: nil

  # Use encrypted session (like Phoenix apps with phx.gen.auth)
  plug(Plug.Session,
    store: :cookie,
    key: "_encrypted_test_session",
    signing_salt: "woep8afH",
    encryption_salt: "qR2vK9xL"
  )

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(:match)
  plug(:fetch_session)

  # Auth plug before dispatch
  plug(:fetch_current_user)

  plug(:dispatch)

  defp fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    assign(conn, :current_user, user_id)
  end

  # Redirect if already logged in
  defp redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> put_resp_header("location", "/")
      |> send_resp(302, "Redirecting to home...")
      |> halt()
    else
      conn
    end
  end

  get "/login" do
    conn = redirect_if_authenticated(conn, [])

    if conn.halted do
      conn
    else
      send_resp(conn, 200, """
      <html>
        <body>
          <h1>Login</h1>
          <form action="/login" method="post">
            <input type="text" name="email" />
            <input type="password" name="password" />
            <button type="submit">Login</button>
          </form>
        </body>
      </html>
      """)
    end
  end

  post "/login" do
    email = conn.body_params["email"]
    password = conn.body_params["password"]

    if email == "test@example.com" && password == "Password123" do
      conn
      |> put_session(:user_id, "user_123")
      |> put_resp_header("location", "/")
      |> send_resp(302, "Redirecting to home...")
    else
      send_resp(conn, 401, "Invalid credentials")
    end
  end

  get "/" do
    user_id = conn.assigns[:current_user]

    send_resp(conn, 200, """
    <html>
      <body>
        <h1>Home</h1>
        <p>User: #{user_id || "not logged in"}</p>
      </body>
    </html>
    """)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
