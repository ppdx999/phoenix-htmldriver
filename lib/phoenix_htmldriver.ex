defmodule PhoenixHtmldriver do
  @moduledoc """
  PhoenixHtmldriver - A lightweight Phoenix library for testing pure HTML.

  PhoenixHtmldriver provides an intuitive API for testing Phoenix applications'
  HTML output without the overhead of a headless browser. It integrates seamlessly
  with Phoenix.ConnTest.

  ## Usage

  Add `use PhoenixHtmldriver` to your test module to automatically configure
  the endpoint:

      defmodule MyAppWeb.PageControllerTest do
        use MyAppWeb.ConnCase
        use PhoenixHtmldriver
        alias PhoenixHtmldriver.{Session, Form, Assertions}

        test "login flow", %{conn: conn} do
          # Visit a page to start a session
          session = visit(conn, "/login")

          # Use Form, Link, Element modules directly
          session
          |> Form.new("#login-form")
          |> Form.fill(username: "alice", password: "secret")
          |> Form.submit()
          |> Assertions.assert_text("Welcome, alice")
          |> Assertions.assert_selector(".alert-success")
        end
      end

  The `use PhoenixHtmldriver` macro will:
  1. Import the visit/2 function for starting sessions
  2. Automatically configure the Phoenix endpoint from `@endpoint` module attribute
  3. Set up the conn with the endpoint in a setup block (if conn is not already provided)

  ## Available Modules

  - `PhoenixHtmldriver.Session` - Session management and navigation
  - `PhoenixHtmldriver.Form` - Form interaction
  - `PhoenixHtmldriver.Link` - Link clicking
  - `PhoenixHtmldriver.Element` - Element inspection
  - `PhoenixHtmldriver.Assertions` - Test assertions
  """

  alias PhoenixHtmldriver.Session

  @doc """
  Sets up PhoenixHtmldriver in your test module.

  Automatically configures the endpoint and imports all functions.
  """
  defmacro __using__(_opts) do
    quote do
      import PhoenixHtmldriver

      # Capture endpoint at compile time
      @phoenix_htmldriver_endpoint Module.get_attribute(__MODULE__, :endpoint)

      setup tags do
        endpoint = @phoenix_htmldriver_endpoint

        cond do
          # If conn is already in tags and has endpoint, use it as-is
          tags[:conn] && tags[:conn].private[:phoenix_endpoint] ->
            :ok

          # If conn is in tags but missing endpoint, add endpoint
          tags[:conn] && endpoint ->
            conn = Plug.Conn.put_private(tags[:conn], :phoenix_endpoint, endpoint)
            %{conn: conn}

          # If no conn in tags but endpoint is set, create conn with endpoint
          endpoint ->
            conn =
              Phoenix.ConnTest.build_conn()
              |> Plug.Conn.put_private(:phoenix_endpoint, endpoint)

            %{conn: conn}

          # No endpoint set, do nothing (will error later with helpful message)
          true ->
            :ok
        end
      end
    end
  end

  @doc """
  Visits a path and returns a session.

  This is the entry point for working with sessions. It automatically dispatches to:
  - `Session.new/2` when given a Plug.Conn (creates a new session)
  - `Session.get/2` when given a Session (navigates within existing session)

  Once you have a session, you can also use Session, Form, Link, Element,
  and Assertions modules directly.

  ## Examples

      # Create a new session
      session = visit(conn, "/home")

      # Navigate within the session
      session = visit(session, "/profile")

      # Or use Session.get/2 directly
      session = Session.get(session, "/about")
  """
  @spec visit(Session.t() | Plug.Conn.t(), String.t()) :: Session.t()
  def visit(%Session{} = session, path), do: Session.get(session, path)
  def visit(conn, path), do: Session.new(conn, path)
end
