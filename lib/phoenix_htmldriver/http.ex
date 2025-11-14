defmodule PhoenixHtmldriver.HTTP do
  @moduledoc """
  HTTP request handling with automatic redirect following and cookie management.

  This module handles the low-level HTTP communication layer:
  - Building requests with proper configuration
  - Executing requests through Phoenix endpoints
  - Following redirects automatically (up to 5 levels)
  - Parsing HTML responses

  Cookie management is handled by `CookieJar` module.
  """

  alias PhoenixHtmldriver.CookieJar

  @type method :: :get | :post | :put | :patch | :delete
  @type endpoint :: module()
  @type cookies :: CookieJar.t()
  @type params :: map() | keyword() | nil

  @doc """
  Performs an HTTP request with cookie handling and redirect following.

  This is the main entry point for making HTTP requests in PhoenixHtmldriver.

  ## Process

  1. Builds a test connection with the given method, path, and parameters
  2. Adds cookies to the request via Cookie header
  3. Executes the request through the Phoenix endpoint
  4. Merges response cookies with existing cookies (monoid operation)
  5. Follows redirects automatically (up to 5 levels)
  6. Parses the final HTML response into a Floki document

  ## Returns

  A tuple of `{response, cookies, document}` where:
  - `response` is the final `Plug.Conn` after all redirects
  - `cookies` is the merged cookie jar
  - `document` is the parsed Floki HTML tree

  ## Examples

      iex> perform_request(:get, "/", MyApp.Endpoint, %{})
      {%Plug.Conn{status: 200, ...}, %{"session" => %{...}}, [{...}]}

      iex> perform_request(:post, "/login", MyApp.Endpoint, cookies, %{username: "alice"})
      {%Plug.Conn{status: 302, ...}, %{"session" => %{...}}, [...]}

  """
  @spec perform_request(method(), String.t(), endpoint(), cookies(), params()) ::
          {Plug.Conn.t(), cookies(), Floki.html_tree()}
  def perform_request(method, path, endpoint, cookies, params \\ nil) do
    # Build and execute request
    response =
      build_conn(method, path, endpoint, params)
      |> CookieJar.put_into_request(cookies)
      |> endpoint.call([])

    # Merge cookies: new cookies from response override existing ones
    merged_cookies = CookieJar.merge(cookies, CookieJar.extract(response))

    # Follow redirects automatically
    {final_response, final_cookies} = follow_redirects(response, merged_cookies, endpoint)

    # Parse HTML document
    {:ok, document} = Floki.parse_document(final_response.resp_body)

    {final_response, final_cookies, document}
  end

  @doc """
  Builds a test connection with proper configuration.

  Sets up:
  - HTTP method and path
  - Request body/params (for POST/PUT/PATCH)
  - Secret key base from endpoint (for encrypted session cookies)

  ## Examples

      iex> build_conn(:get, "/users", MyApp.Endpoint)
      %Plug.Conn{method: "GET", request_path: "/users", ...}

      iex> build_conn(:post, "/users", MyApp.Endpoint, %{name: "Alice"})
      %Plug.Conn{method: "POST", body_params: %{name: "Alice"}, ...}

  """
  @spec build_conn(method(), String.t(), endpoint(), params()) :: Plug.Conn.t()
  def build_conn(method, path, endpoint, body_or_params \\ nil) do
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

  @doc """
  Follows HTTP redirects automatically.

  Mimics browser behavior by:
  - Following redirect status codes (301, 302, 303, 307, 308)
  - Using GET for redirect requests
  - Carrying cookies through redirect chain
  - Merging cookies at each step (new cookies override old ones)
  - Limiting to maximum 5 redirects (prevents infinite loops)

  ## Returns

  A tuple of `{final_response, final_cookies}` where:
  - `final_response` is the non-redirect response
  - `final_cookies` is the accumulated cookie jar through all redirects

  ## Examples

      iex> follow_redirects(redirect_response, cookies, MyApp.Endpoint)
      {%Plug.Conn{status: 200, ...}, %{"session" => %{...}}}

      iex> follow_redirects(ok_response, cookies, MyApp.Endpoint)
      {%Plug.Conn{status: 200, ...}, %{"session" => %{...}}}

  """
  @spec follow_redirects(Plug.Conn.t(), cookies(), endpoint(), non_neg_integer()) ::
          {Plug.Conn.t(), cookies()}
  def follow_redirects(response, cookies, endpoint, max_redirects \\ 5)

  def follow_redirects(_response, _cookies, _endpoint, 0) do
    raise "Too many redirects (max 5)"
  end

  def follow_redirects(response, cookies, endpoint, remaining) do
    case response.status do
      status when status in [301, 302, 303, 307, 308] ->
        # Get redirect location
        location =
          case Plug.Conn.get_resp_header(response, "location") do
            [loc | _] -> loc
            [] -> raise "Redirect response missing Location header"
          end

        # Follow redirect with GET request
        new_response =
          build_conn(:get, location, endpoint)
          |> CookieJar.put_into_request(cookies)
          |> endpoint.call([])

        # Merge cookies using monoid structure: new cookies override existing ones
        merged_cookies = CookieJar.merge(cookies, CookieJar.extract(new_response))

        follow_redirects(new_response, merged_cookies, endpoint, remaining - 1)

      _ ->
        # Not a redirect, return final response with current cookies
        {response, cookies}
    end
  end
end
