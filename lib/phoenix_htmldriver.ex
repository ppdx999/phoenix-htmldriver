defmodule PhoenixHtmldriver do
  @moduledoc """
  PhoenixHtmldriver - A lightweight Phoenix library for testing pure HTML.

  PhoenixHtmldriver provides an intuitive API for testing Phoenix applications'
  HTML output without the overhead of a headless browser. It integrates seamlessly
  with Phoenix.ConnTest.

  ## Usage

  Add `use PhoenixHtmldriver` to your test module to automatically configure
  the endpoint and import all functions:

      defmodule MyAppWeb.PageControllerTest do
        use MyAppWeb.ConnCase
        use PhoenixHtmldriver
        alias PhoenixHtmldriver.Form

        test "login flow", %{conn: conn} do
          # Visit a page
          session = visit(conn, "/login")

          # Fill and submit a form using Form API
          session
          |> form("#login-form")
          |> Form.fill(username: "alice", password: "secret")
          |> Form.submit()
          |> assert_text("Welcome, alice")
          |> assert_selector(".alert-success")
        end
      end

  The `use PhoenixHtmldriver` macro will:
  1. Import all PhoenixHtmldriver functions
  2. Automatically configure the Phoenix endpoint from `@endpoint` module attribute
  3. Set up the conn with the endpoint in a setup block (if conn is not already provided)

  ## Manual Configuration

  If you need manual control, you can import functions directly:

      defmodule MyAppWeb.PageControllerTest do
        use MyAppWeb.ConnCase
        import PhoenixHtmldriver

        setup %{conn: conn} do
          conn = Plug.Conn.put_private(conn, :phoenix_endpoint, MyAppWeb.Endpoint)
          %{conn: conn}
        end

        test "login flow", %{conn: conn} do
          session = visit(conn, "/login")
          # ...
        end
      end
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
  Visits a path and returns a new session.

  ## Examples

      session = visit(conn, "/home")
  """
  @spec visit(Plug.Conn.t(), String.t()) :: Session.t()
  defdelegate visit(conn, path), to: Session

  @doc """
  Gets a form from the current session.

  Returns a Form struct that can be filled and submitted using the Form module.

  ## Examples

      alias PhoenixHtmldriver.Form

      session
      |> form("#login-form")
      |> Form.fill(username: "alice", password: "secret")
      |> Form.submit()
  """
  @spec form(Session.t(), String.t()) :: PhoenixHtmldriver.Form.t()
  defdelegate form(session, selector), to: PhoenixHtmldriver.Form, as: :new

  @doc """
  Gets a link from the current session.

  Returns a Link struct that can be clicked using the Link module.

  ## Examples

      alias PhoenixHtmldriver.Link

      # Find by selector
      session
      |> link("#profile-link")
      |> Link.click()

      # Find by text
      session
      |> link("View Profile")
      |> Link.click()
  """
  @spec link(Session.t(), String.t()) :: PhoenixHtmldriver.Link.t()
  defdelegate link(session, selector_or_text), to: PhoenixHtmldriver.Link, as: :new

  @doc """
  Asserts that text is present in the response.

  ## Examples

      assert_text(session, "Welcome back")
  """
  @spec assert_text(Session.t(), String.t()) :: Session.t()
  defdelegate assert_text(session, text), to: Session

  @doc """
  Asserts that an element matching the selector is present.

  ## Examples

      assert_selector(session, ".alert-success")
      assert_selector(session, "#user-profile")
  """
  @spec assert_selector(Session.t(), String.t()) :: Session.t()
  defdelegate assert_selector(session, selector), to: Session

  @doc """
  Asserts that an element matching the selector is not present.

  ## Examples

      refute_selector(session, ".alert-danger")
  """
  @spec refute_selector(Session.t(), String.t()) :: Session.t()
  defdelegate refute_selector(session, selector), to: Session

  @doc """
  Gets the current path of the session.

  ## Examples

      path = current_path(session)
      assert path == "/profile"
  """
  @spec current_path(Session.t()) :: String.t()
  defdelegate current_path(session), to: Session

  @doc """
  Gets the current response body.

  ## Examples

      html = current_html(session)
  """
  @spec current_html(Session.t()) :: String.t()
  defdelegate current_html(session), to: Session

  @doc """
  Finds an element by selector.

  ## Examples

      element = find(session, ".user-name")
      text = PhoenixHtmldriver.Element.text(element)
  """
  @spec find(Session.t(), String.t()) :: {:ok, PhoenixHtmldriver.Element.t()} | {:error, String.t()}
  defdelegate find(session, selector), to: Session

  @doc """
  Finds all elements matching the selector.

  ## Examples

      elements = find_all(session, ".list-item")
      assert length(elements) == 5
  """
  @spec find_all(Session.t(), String.t()) :: [PhoenixHtmldriver.Element.t()]
  defdelegate find_all(session, selector), to: Session
end
