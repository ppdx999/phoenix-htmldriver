defmodule PhoenixHtmldriver.Session do
  @moduledoc """
  Represents a browser session for testing Phoenix applications.

  Session automatically preserves cookies across requests, enabling proper
  session handling and CSRF token validation. Each request (`visit`, `click_link`,
  `submit_form`) carries forward cookies from the previous response.
  """

  import ExUnit.Assertions
  alias PhoenixHtmldriver.{CookieJar, HTTP}

  defstruct [:conn, :document, :response, :endpoint, :cookies]

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          document: Floki.html_tree(),
          response: Plug.Conn.t(),
          endpoint: module(),
          cookies: map()
        }

  @doc """
  Visits a path and returns a new session.

  When called with a Session struct, preserves cookies from the previous request.
  When called with a Plug.Conn, starts a fresh session without cookies.

  The conn should be created with Phoenix.ConnTest.build_conn/0 and have an endpoint set.

  ## Examples

      # Fresh session (no cookies)
      session = visit(conn, "/login")

      # Preserves cookies from previous request
      session = visit(session, "/dashboard")
  """
  @spec visit(t() | Plug.Conn.t(), String.t()) :: t()
  def visit(%__MODULE__{conn: conn, endpoint: endpoint, cookies: cookies}, path) do
    {final_response, final_cookies, document} =
      HTTP.perform_request(:get, path, endpoint, cookies)

    %__MODULE__{
      conn: conn,
      document: document,
      response: final_response,
      endpoint: endpoint,
      cookies: final_cookies
    }
  end

  def visit(conn, path) do
    # Get the endpoint from conn's private data (set by Phoenix.ConnTest.build_conn)
    endpoint = conn.private[:phoenix_endpoint]

    if !endpoint do
      raise """
      No endpoint found in conn. Make sure you:
      1. Set @endpoint in your test module
      2. Use Phoenix.ConnTest.build_conn/0 to create the conn
      """
    end

    # Start with empty cookies (monoid identity)
    {final_response, final_cookies, document} =
      HTTP.perform_request(:get, path, endpoint, CookieJar.empty())

    %__MODULE__{
      conn: conn,
      document: document,
      response: final_response,
      endpoint: endpoint,
      cookies: final_cookies
    }
  end

  @doc """
  Clicks a link.
  """
  @spec click_link(t(), String.t()) :: t()
  def click_link(%__MODULE__{conn: conn, document: document, endpoint: endpoint, cookies: cookies} = _session, selector_or_text) do
    # Try to find link by selector first
    link =
      case Floki.find(document, selector_or_text) do
        [] ->
          # If not found, try to find by text
          Floki.find(document, "a")
          |> Enum.find(fn node ->
            Floki.text(node) |> String.trim() == selector_or_text
          end)

        [node | _] ->
          node

        _ ->
          nil
      end

    if !link do
      raise "Link not found: #{selector_or_text}"
    end

    href = get_attribute(link, "href") || "/"

    {final_response, final_cookies, new_document} =
      HTTP.perform_request(:get, href, endpoint, cookies)

    %__MODULE__{
      conn: conn,
      document: new_document,
      response: final_response,
      endpoint: endpoint,
      cookies: final_cookies
    }
  end

  @doc """
  Asserts that text is present in the response.
  """
  @spec assert_text(t(), String.t()) :: t()
  def assert_text(%__MODULE__{response: response} = session, text) do
    assert response.resp_body =~ text, "Expected to find text: #{text}"
    session
  end

  @doc """
  Asserts that an element matching the selector is present.
  """
  @spec assert_selector(t(), String.t()) :: t()
  def assert_selector(%__MODULE__{document: document} = session, selector) do
    elements = Floki.find(document, selector)
    assert length(elements) > 0, "Expected to find element: #{selector}"
    session
  end

  @doc """
  Asserts that an element matching the selector is not present.
  """
  @spec refute_selector(t(), String.t()) :: t()
  def refute_selector(%__MODULE__{document: document} = session, selector) do
    elements = Floki.find(document, selector)
    assert length(elements) == 0, "Expected not to find element: #{selector}"
    session
  end

  @doc """
  Gets the current path.
  """
  @spec current_path(t()) :: String.t()
  def current_path(%__MODULE__{response: response}) do
    response.request_path
  end

  @doc """
  Gets the current HTML.
  """
  @spec current_html(t()) :: String.t()
  def current_html(%__MODULE__{response: response}) do
    response.resp_body
  end

  @doc """
  Finds an element by selector.
  """
  @spec find(t(), String.t()) :: {:ok, PhoenixHtmldriver.Element.t()} | {:error, String.t()}
  def find(%__MODULE__{document: document}, selector) do
    case Floki.find(document, selector) do
      [] ->
        {:error, "Element not found: #{selector}"}

      [node | _] ->
        {:ok, %PhoenixHtmldriver.Element{node: node}}

      _ ->
        {:error, "Invalid element"}
    end
  end

  @doc """
  Finds all elements matching the selector.
  """
  @spec find_all(t(), String.t()) :: [PhoenixHtmldriver.Element.t()]
  def find_all(%__MODULE__{document: document}, selector) do
    Floki.find(document, selector)
    |> Enum.map(fn node -> %PhoenixHtmldriver.Element{node: node} end)
  end

  # Helper to get attribute value
  defp get_attribute(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
