defmodule PhoenixHtmldriver do
  @moduledoc """
  PhoenixHtmldriver - A lightweight Phoenix library for testing pure HTML.

  PhoenixHtmldriver provides an intuitive API for testing Phoenix applications'
  HTML output without the overhead of a headless browser. It integrates seamlessly
  with Phoenix.ConnTest.

  ## Examples

      use MyAppWeb.ConnTest

      test "login flow", %{conn: conn} do
        # Visit a page
        session = visit(conn, "/login")

        # Fill and submit a form
        session = session
        |> fill_form("#login-form", username: "alice", password: "secret")
        |> submit_form("#login-form")

        # Assert on the response
        assert_text(session, "Welcome, alice")
        assert_selector(session, ".alert-success")
      end
  """

  alias PhoenixHtmldriver.Session

  @doc """
  Visits a path and returns a new session.

  ## Examples

      session = visit(conn, "/home")
  """
  @spec visit(Plug.Conn.t(), String.t()) :: Session.t()
  defdelegate visit(conn, path), to: Session

  @doc """
  Fills in a form with the given values.

  ## Examples

      session = fill_form(session, "#login-form", username: "alice", password: "secret")
  """
  @spec fill_form(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate fill_form(session, selector, values), to: Session

  @doc """
  Submits a form.

  ## Examples

      session = submit_form(session, "#login-form")
      session = submit_form(session, "#login-form", username: "alice")
  """
  @spec submit_form(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate submit_form(session, selector, values \\ []), to: Session

  @doc """
  Clicks a link.

  ## Examples

      session = click_link(session, "#profile-link")
      session = click_link(session, "View Profile")
  """
  @spec click_link(Session.t(), String.t()) :: Session.t()
  defdelegate click_link(session, selector_or_text), to: Session

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
