defmodule PhoenixHtmldriver.Session do
  @moduledoc """
  Represents a browser session for testing Phoenix applications.
  """

  import ExUnit.Assertions

  defstruct [:conn, :document, :response, :endpoint]

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          document: Floki.html_tree(),
          response: Plug.Conn.t(),
          endpoint: module()
        }

  @doc """
  Visits a path and returns a new session.
  The conn should be created with Phoenix.ConnTest.build_conn/0 and have an endpoint set.
  """
  @spec visit(Plug.Conn.t(), String.t()) :: t()
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

    # Use Plug.Test functions directly instead of Phoenix.ConnTest dispatch
    response =
      Plug.Test.conn(:get, path)
      |> endpoint.call([])

    {:ok, document} = Floki.parse_document(response.resp_body)

    %__MODULE__{
      conn: conn,
      document: document,
      response: response,
      endpoint: endpoint
    }
  end

  @doc """
  Fills in a form with the given values.
  """
  @spec fill_form(t(), String.t(), keyword()) :: t()
  def fill_form(%__MODULE__{} = session, _selector, _values) do
    # For now, just store the values in session for submit_form to use
    # This is a simplified implementation
    session
  end

  @doc """
  Submits a form.
  """
  @spec submit_form(t(), String.t(), keyword()) :: t()
  def submit_form(%__MODULE__{conn: conn, document: document, endpoint: endpoint} = _session, selector, values \\ []) do
    # Find the form
    form = Floki.find(document, selector)

    if Enum.empty?(form) do
      raise "Form not found: #{selector}"
    end

    [form_node | _] = form

    # Get form action and method
    action = get_attribute(form_node, "action") || "/"
    method = get_attribute(form_node, "method") || "get"
    method_atom = String.downcase(method) |> String.to_atom()

    # Submit the form using Plug.Test directly
    response =
      case method_atom do
        :post ->
          Plug.Test.conn(:post, action, values)
          |> endpoint.call([])

        :get ->
          Plug.Test.conn(:get, action <> "?" <> URI.encode_query(values))
          |> endpoint.call([])

        :put ->
          Plug.Test.conn(:put, action, values)
          |> endpoint.call([])

        :patch ->
          Plug.Test.conn(:patch, action, values)
          |> endpoint.call([])

        :delete ->
          Plug.Test.conn(:delete, action)
          |> endpoint.call([])
      end

    {:ok, new_document} = Floki.parse_document(response.resp_body)

    %__MODULE__{
      conn: conn,
      document: new_document,
      response: response,
      endpoint: endpoint
    }
  end

  @doc """
  Clicks a link.
  """
  @spec click_link(t(), String.t()) :: t()
  def click_link(%__MODULE__{conn: conn, document: document, endpoint: endpoint} = _session, selector_or_text) do
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

    response =
      Plug.Test.conn(:get, href)
      |> endpoint.call([])

    {:ok, new_document} = Floki.parse_document(response.resp_body)

    %__MODULE__{
      conn: conn,
      document: new_document,
      response: response,
      endpoint: endpoint
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
