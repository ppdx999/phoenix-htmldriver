defmodule PhoenixHtmldriver.Link do
  @moduledoc """
  Represents a link within a browser session.

  A Link encapsulates link-specific state and operations while inheriting
  the session context (conn, endpoint, cookies, path) from the parent Session.

  ## Usage

      session
      |> Link.new("#login-link")
      |> Link.click()

      # Or find by text
      session
      |> Link.new("Login")
      |> Link.click()
  """

  alias PhoenixHtmldriver.HTTP

  defstruct [:conn, :node, :endpoint, :cookies, :path]

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          node: Floki.html_node(),
          endpoint: module(),
          cookies: map(),
          path: String.t()
        }

  @doc """
  Creates a new Link from a Session.

  Finds a link element in the session's document using the given CSS selector
  or text content, and returns a Link struct ready for clicking.

  ## Finding Links

  The selector can be:
  - A CSS selector (e.g., "#login-link", "a.nav-link")
  - Link text content (e.g., "Login", "Sign Up")

  If the selector is not found as a CSS selector, the function will search
  for links by their text content.

  ## Examples

      alias PhoenixHtmldriver.Link

      # Find by CSS selector
      session
      |> Link.new("#login-link")
      |> Link.click()

      # Find by text content
      session
      |> Link.new("Login")
      |> Link.click()

      # Find by class
      session
      |> Link.new("a.nav-link")
      |> Link.click()

  ## Errors

  Raises if the link is not found in the document.
  """
  @spec new(PhoenixHtmldriver.Session.t(), String.t()) :: t()
  def new(%PhoenixHtmldriver.Session{conn: conn, document: document, endpoint: endpoint, cookies: cookies, path: path}, selector_or_text) do
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

    %__MODULE__{
      conn: conn,
      node: link,
      endpoint: endpoint,
      cookies: cookies,
      path: path
    }
  end

  @doc """
  Clicks the link and returns a new Session.

  Follows the link's href attribute and performs a GET request to that URL.
  If the link has no href attribute, defaults to "/".

  ## Examples

      # Click a link
      session
      |> Link.new("#login-link")
      |> Link.click()

      # Click by text
      session
      |> Link.new("Login")
      |> Link.click()

  ## Returns

  A new `PhoenixHtmldriver.Session.t()` struct representing the response after
  clicking the link, including any redirects that were followed.
  """
  @spec click(t()) :: PhoenixHtmldriver.Session.t()
  def click(%__MODULE__{conn: conn, node: node, endpoint: endpoint, cookies: cookies} = _link) do
    href = get_attribute(node, "href") || "/"

    HTTP.perform_request(:get, href, conn, endpoint, cookies)
  end

  # Helper to get attribute value
  defp get_attribute(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
