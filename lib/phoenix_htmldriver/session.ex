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
          cookies: CookieJar.t(),
          path: String.t()
        }
  @type method :: :get | :post | :put | :patch | :delete
  @type endpoint :: module()
  @type params :: map() | keyword() | nil

  @doc """
  Creates a new session from a Plug.Conn and visits a path.

  The conn should be created with Phoenix.ConnTest.build_conn/0 and have an endpoint set.

  ## Examples

      session = Session.new(conn, "/login")
  """
  @dialyzer {:nowarn_function, new: 2}
  @spec new(Plug.Conn.t(), String.t()) :: t()
  def new(conn, path) do
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
    session = %__MODULE__{
      conn: conn,
      endpoint: endpoint,
      cookies: CookieJar.empty(),
      document: nil,
      response: nil,
      path: nil
    }
    request(session, :get, path)
  end

  @doc """
  Visits a path using an existing session.

  Preserves cookies from the previous request.

  ## Examples

      session = Session.get(session, "/dashboard")
  """
  @spec get(t(), String.t()) :: t()
  def get(%__MODULE__{} = session, path) do
    request(session, :get, path)
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

  @dialyzer {:nowarn_function, request: 5}
  @doc false
  # Internal function for making HTTP requests. Used by Form, Link, and Session.
  @spec request(t(), method(), String.t(), params(), non_neg_integer()) :: t()
  def request(session, method, path, params \\ nil, max_redirects \\ 5)

  def request(_session, _method, _path, _params, 0) do
    raise "Too many redirects (max 5)"
  end

  def request(%__MODULE__{conn: conn, endpoint: endpoint, cookies: cookies} = _session, method, path, params, remaining_redirects) do
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
        request(%__MODULE__{
          conn: conn,
          endpoint: endpoint,
          cookies: merged_cookies,
          document: nil,
          response: nil,
          path: nil
        }, :get, location, nil, remaining_redirects - 1)

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
