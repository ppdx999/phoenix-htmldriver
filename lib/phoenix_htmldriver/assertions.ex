defmodule PhoenixHtmldriver.Assertions do
  @moduledoc """
  Provides assertion helpers for testing with PhoenixHtmldriver.

  This module contains ExUnit assertions for verifying the state of a Session.
  Import this module in your tests to use these assertions in a pipeline style.

  ## Usage

      import PhoenixHtmldriver.Assertions

      session
      |> visit("/login")
      |> assert_text("Login")
      |> assert_selector("#login-form")
      |> refute_selector(".error")

  All assertion functions return the session, enabling method chaining.
  """

  import ExUnit.Assertions
  alias PhoenixHtmldriver.Session

  @doc """
  Asserts that text is present in the response.

  ## Examples

      session
      |> assert_text("Welcome")
      |> assert_text("Logged in successfully")

  Returns the session to enable chaining.
  """
  @spec assert_text(Session.t(), String.t()) :: Session.t()
  def assert_text(%Session{response: response} = session, text) do
    assert response.resp_body =~ text, "Expected to find text: #{text}"
    session
  end

  @doc """
  Asserts that an element matching the selector is present.

  ## Examples

      session
      |> assert_selector("#login-form")
      |> assert_selector(".alert-success")

  Returns the session to enable chaining.
  """
  @spec assert_selector(Session.t(), String.t()) :: Session.t()
  def assert_selector(%Session{document: document} = session, selector) do
    elements = Floki.find(document, selector)
    assert length(elements) > 0, "Expected to find element: #{selector}"
    session
  end

  @doc """
  Asserts that an element matching the selector is not present.

  ## Examples

      session
      |> refute_selector(".error")
      |> refute_selector("#admin-panel")

  Returns the session to enable chaining.
  """
  @spec refute_selector(Session.t(), String.t()) :: Session.t()
  def refute_selector(%Session{document: document} = session, selector) do
    elements = Floki.find(document, selector)
    assert length(elements) == 0, "Expected not to find element: #{selector}"
    session
  end
end
