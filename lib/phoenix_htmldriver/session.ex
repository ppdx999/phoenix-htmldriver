defmodule PhoenixHtmldriver.Session do
  @moduledoc """
  Represents a browser session for testing Phoenix applications.

  Session automatically preserves cookies across requests, enabling proper
  session handling and CSRF token validation. Each request (`visit`, `click_link`,
  `submit_form`) carries forward cookies from the previous response.
  """

  import ExUnit.Assertions

  defstruct [:conn, :document, :response, :endpoint, :cookies, :form_values]

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          document: Floki.html_tree(),
          response: Plug.Conn.t(),
          endpoint: module(),
          cookies: map(),
          form_values: map()
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
      build_test_conn(:get, path, endpoint)
      |> endpoint.call([])

    {:ok, document} = Floki.parse_document(response.resp_body)

    # Extract cookies from response to preserve session
    cookies = extract_cookies(response)

    %__MODULE__{
      conn: conn,
      document: document,
      response: response,
      endpoint: endpoint,
      cookies: cookies,
      form_values: %{}
    }
  end

  @doc """
  Fills in a form with the given values.

  Stores the values in the session so they can be submitted later with `submit_form/3`.
  The values are associated with the form selector.

  ## Examples

      session
      |> fill_form("#login-form", email: "user@example.com", password: "secret")
      |> submit_form("#login-form")  # Values are automatically included

      # Can also use nested maps
      session
      |> fill_form("form", %{user: %{email: "test@example.com"}})
      |> submit_form("form")
  """
  @spec fill_form(t(), String.t(), keyword() | map()) :: t()
  def fill_form(%__MODULE__{document: document, form_values: form_values} = session, selector, values) do
    # Validate that the form exists
    form = Floki.find(document, selector)

    if Enum.empty?(form) do
      raise "Form not found: #{selector}"
    end

    # Convert keyword list to map for consistent handling
    values_map = Enum.into(values, %{})

    # Store the values associated with this form selector
    new_form_values = Map.put(form_values || %{}, selector, values_map)

    %{session | form_values: new_form_values}
  end

  @doc """
  Submits a form.

  Automatically extracts and includes CSRF token from the form if present.
  This helps prevent `Plug.CSRFProtection.InvalidCSRFTokenError` when testing
  forms with CSRF protection.

  ## CSRF Token Extraction

  The CSRF token is looked up in the following order:
  1. Hidden input field with name="_csrf_token" within the form
  2. Meta tag with name="csrf-token" in the document head

  The token is automatically added to form values for POST, PUT, PATCH, and DELETE
  requests. GET requests do not include CSRF tokens.

  If you provide your own `_csrf_token` value, it will not be overridden.

  ## Examples

      # CSRF token is automatically extracted and included
      session
      |> visit(conn, "/login")
      |> submit_form("#login-form", email: "test@example.com", password: "secret")

      # Override CSRF token if needed
      session
      |> submit_form("form", _csrf_token: "custom-token", email: "test@example.com")

      # Forms without CSRF tokens work normally
      session
      |> submit_form("#search-form", q: "elixir")
  """
  @spec submit_form(t(), String.t(), keyword() | map()) :: t()
  def submit_form(%__MODULE__{conn: conn, document: document, endpoint: endpoint, cookies: cookies, form_values: stored_form_values} = _session, selector, values \\ []) do
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

    # Get stored values from fill_form for this selector
    stored_values = Map.get(stored_form_values || %{}, selector, %{})

    # Convert values parameter to map
    submit_values = Enum.into(values, %{})

    # Merge stored values with submit values (submit values take precedence)
    merged_values = Map.merge(stored_values, submit_values)

    # Extract CSRF token from form or document
    csrf_token = extract_csrf_token(form_node, document)

    # Merge CSRF token into values if present and method requires it
    form_values =
      if csrf_token && method_atom in [:post, :put, :patch, :delete] do
        # Only add CSRF token if not already present
        if Map.has_key?(merged_values, "_csrf_token") || Map.has_key?(merged_values, :_csrf_token) do
          merged_values
        else
          Map.put(merged_values, "_csrf_token", csrf_token)
        end
      else
        merged_values
      end

    # Submit the form using Plug.Test directly
    response =
      case method_atom do
        :post ->
          build_test_conn(:post, action, endpoint, form_values)
          |> put_cookies(cookies)
          |> endpoint.call([])

        :get ->
          build_test_conn(:get, action <> "?" <> URI.encode_query(form_values), endpoint)
          |> put_cookies(cookies)
          |> endpoint.call([])

        :put ->
          build_test_conn(:put, action, endpoint, form_values)
          |> put_cookies(cookies)
          |> endpoint.call([])

        :patch ->
          build_test_conn(:patch, action, endpoint, form_values)
          |> put_cookies(cookies)
          |> endpoint.call([])

        :delete ->
          build_test_conn(:delete, action, endpoint)
          |> put_cookies(cookies)
          |> endpoint.call([])
      end

    {:ok, new_document} = Floki.parse_document(response.resp_body)

    # Extract new cookies from response
    new_cookies = extract_cookies(response)

    %__MODULE__{
      conn: conn,
      document: new_document,
      response: response,
      endpoint: endpoint,
      cookies: new_cookies,
      form_values: %{}  # Reset form values after submission
    }
  end

  # Extract CSRF token from form or document
  defp extract_csrf_token(form_node, document) do
    # Try to find CSRF token in form's hidden input
    case Floki.find(form_node, "input[name='_csrf_token']") do
      [input | _] ->
        case get_attribute(input, "value") do
          nil -> extract_csrf_from_meta(document)
          token -> token
        end

      [] ->
        extract_csrf_from_meta(document)
    end
  end

  # Extract CSRF token from meta tag
  defp extract_csrf_from_meta(document) do
    case Floki.find(document, "meta[name='csrf-token']") do
      [meta | _] ->
        get_attribute(meta, "content")

      [] ->
        nil
    end
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

    response =
      build_test_conn(:get, href, endpoint)
      |> put_cookies(cookies)
      |> endpoint.call([])

    {:ok, new_document} = Floki.parse_document(response.resp_body)

    # Extract new cookies from response
    new_cookies = extract_cookies(response)

    %__MODULE__{
      conn: conn,
      document: new_document,
      response: response,
      endpoint: endpoint,
      cookies: new_cookies,
      form_values: %{}  # Reset form values after navigation
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

  # Extract cookies from response
  defp extract_cookies(response) do
    response.resp_cookies
  end

  # Put cookies into request
  defp put_cookies(conn, nil), do: conn
  defp put_cookies(conn, cookies) when map_size(cookies) == 0, do: conn

  defp put_cookies(conn, cookies) do
    Enum.reduce(cookies, conn, fn {name, cookie}, conn ->
      Plug.Test.put_req_cookie(conn, to_string(name), cookie.value)
    end)
  end

  # Create a test conn with secret_key_base if needed
  defp build_test_conn(method, path, endpoint, body_or_params \\ nil) do
    conn =
      case body_or_params do
        nil -> Plug.Test.conn(method, path)
        params -> Plug.Test.conn(method, path, params)
      end

    # Set secret_key_base if the endpoint has one (needed for session cookies)
    if endpoint_secret = endpoint.config(:secret_key_base) do
      put_in(conn.secret_key_base, endpoint_secret)
    else
      conn
    end
  end
end
