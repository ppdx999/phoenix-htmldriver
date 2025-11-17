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

  alias PhoenixHtmldriver.Session

  defstruct [:session, :node]

  @type t :: %__MODULE__{
          session: Session.t(),
          node: Floki.html_node()
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
  @spec new(Session.t(), String.t()) :: t()
  def new(%Session{document: document} = session, selector_or_text) do
    case link(document, selector_or_text) do
      nil -> raise "Link not found: #{selector_or_text}"
      found_link ->
        %__MODULE__{
          session: session,
          node: found_link
        }
    end
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

      # Click by class
      session
      |> Link.new("a.nav-link")
      |> Link.click()

  ## Returns

  A new `PhoenixHtmldriver.Session.t()` struct representing the response after
  clicking the link, including any redirects that were followed.
  """
  @spec click(t()) :: Session.t()
  def click(%__MODULE__{session: %Session{conn: conn, endpoint: endpoint, cookies: cookies}, node: node} = _link) do
    case attr(node, "href") do
      nil -> raise "Link has no href attribute"
      href -> Session.request(:get, href, conn, endpoint, cookies)
    end
  end

  # Helper to get attribute value
  defp attr(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp find(node, selector) do
    case Floki.find(node, selector) do
      [] -> nil
      [found | _] -> found
    end
  end

  defp link(node, selector_or_text) do
    link_by_selector(node, selector_or_text) ||
      link_by_text(node, selector_or_text)
  end

  defp link_by_selector(node, selector) do
    find(node, selector)
  end

  defp link_by_text(node, text) do
    Floki.find(node, "a") |> Enum.find(&match(&1, text))
  end

  defp match(node, text) do
    Floki.text(node) |> String.trim() == text
  end
end
