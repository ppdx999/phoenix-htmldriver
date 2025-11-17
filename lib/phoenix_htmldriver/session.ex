defmodule PhoenixHtmldriver.Session do
  @moduledoc """
  Represents a browser session for testing Phoenix applications.

  Session automatically preserves cookies across requests, enabling proper
  session handling and CSRF token validation. Each request (`visit`, `click_link`,
  `submit_form`) carries forward cookies from the previous response.
  """

  alias PhoenixHtmldriver.CookieJar

  defstruct [:conn, :document, :response, :endpoint, :cookies, :path]

  @type t :: %__MODULE__{
          conn: Plug.Conn.t(),
          document: Floki.html_tree(),
          response: Plug.Conn.t(),
          endpoint: module(),
          cookies: map(),
          path: String.t()
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
    request(:get, path, conn, endpoint, cookies)
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
    request(:get, path, conn, endpoint, CookieJar.empty())
  end

  @doc """
  Gets the current path.
  """
  @spec path(t()) :: String.t()
  def path(%__MODULE__{response: response}) do
    response.request_path
  end

  @doc """
  Gets the current HTML.
  """
  @spec html(t()) :: String.t()
  def html(%__MODULE__{response: response}) do
    response.resp_body
  end

  # Private functions for HTTP request handling

  @type method :: :get | :post | :put | :patch | :delete
  @type endpoint :: module()
  @type cookies :: CookieJar.t()
  @type params :: map() | keyword() | nil

  @doc false
  # Internal function for making HTTP requests. Used by Form, Link, and Session.
  @spec request(method(), String.t(), Plug.Conn.t(), endpoint(), cookies(), params(), non_neg_integer()) :: t()
  def request(method, path, conn, endpoint, cookies, params \\ nil, max_redirects \\ 5)

  def request(_method, _path, _conn, _endpoint, _cookies, _params, 0) do
    raise "Too many redirects (max 5)"
  end

  def request(method, path, conn, endpoint, cookies, params, remaining_redirects) do
    # For GET requests, encode params in query string
    {final_path, body_params} =
      if method == :get && params && params != %{} do
        query_string = URI.encode_query(params)
        final_path = if String.contains?(path, "?") do
          path <> "&" <> query_string
        else
          path <> "?" <> query_string
        end
        {final_path, nil}
      else
        {path, params}
      end

    # Build and execute request
    response =
      build_conn(method, final_path, endpoint, body_params)
      |> CookieJar.put_into_request(cookies)
      |> endpoint.call([])

    # Merge cookies: new cookies from response override existing ones
    merged_cookies = CookieJar.merge(cookies, CookieJar.extract(response))

    # Check if response is a redirect
    case response.status do
      status when status in [301, 302, 303, 307, 308] ->
        # Extract redirect location
        location =
          case Plug.Conn.get_resp_header(response, "location") do
            [loc | _] -> loc
            [] -> raise "Redirect response missing Location header"
          end

        # Recursively follow redirect with GET request
        request(:get, location, conn, endpoint, merged_cookies, nil, remaining_redirects - 1)

      _ ->
        # Not a redirect, parse and return
        {:ok, document} = Floki.parse_document(response.resp_body)

        %__MODULE__{
          conn: conn,
          document: document,
          response: response,
          endpoint: endpoint,
          cookies: merged_cookies,
          path: response.request_path
        }
    end
  end

  # Builds a test connection with proper configuration
  @spec build_conn(method(), String.t(), endpoint(), params()) :: Plug.Conn.t()
  defp build_conn(method, path, endpoint, body_or_params) do
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
