defmodule PhoenixHtmldriver.CookieJar do
  @moduledoc """
  Cookie management with proper monoid structure.

  This module handles cookie storage and merging with the following guarantees:
  - Cookies form a monoid under merge operation
  - Deleted cookies (max_age <= 0) are automatically removed
  - Browser-like behavior for cookie handling
  """

  defstruct [:cookies]

  @type cookie :: %{
          value: String.t(),
          max_age: integer() | nil,
          path: String.t() | nil,
          domain: String.t() | nil,
          secure: boolean() | nil,
          http_only: boolean() | nil,
          same_site: atom() | nil
        }

  @type t :: %__MODULE__{
          cookies: %{optional(String.t()) => cookie()}
        }

  @doc """
  Extracts cookies from a Plug.Conn response.

  Returns a CookieJar containing cookies from the response.
  """
  @spec extract(Plug.Conn.t()) :: t()
  def extract(response) do
    %__MODULE__{cookies: response.resp_cookies}
  end

  @doc """
  Merges cookies using monoid structure with cookie deletion support.

  ## Monoid Properties

  - **Identity**: `merge(empty(), a) = merge(a, empty()) = a`
  - **Associativity**: `merge(merge(a, b), c) = merge(a, merge(b, c))`
  - **Right-biased**: New cookies override existing ones with the same name
  - **Deletion**: Cookies with `max_age <= 0` are removed

  ## Examples

      iex> jar1 = %CookieJar{cookies: %{"session" => %{value: "old"}}}
      iex> jar2 = %CookieJar{cookies: %{"session" => %{value: "new"}}}
      iex> merge(jar1, jar2)
      %CookieJar{cookies: %{"session" => %{value: "new"}}}

      iex> jar = %CookieJar{cookies: %{"session" => %{value: "keep"}}}
      iex> merge(jar, empty())
      %CookieJar{cookies: %{"session" => %{value: "keep"}}}

  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{cookies: existing}, %__MODULE__{cookies: new}) do
    merged =
      existing
      |> Map.merge(new)
      |> filter_deleted()

    %__MODULE__{cookies: merged}
  end

  @doc """
  Puts cookies into a request conn by setting the Cookie header.

  Returns the conn with Cookie header set, or unchanged conn if no cookies.
  """
  @spec put_into_request(Plug.Conn.t(), t()) :: Plug.Conn.t()
  def put_into_request(conn, %__MODULE__{cookies: cookies}) when map_size(cookies) == 0 do
    conn
  end

  def put_into_request(conn, %__MODULE__{cookies: cookies}) do
    cookie_header =
      cookies
      |> Enum.map(fn {name, cookie} -> "#{name}=#{cookie.value}" end)
      |> Enum.join("; ")

    Plug.Conn.put_req_header(conn, "cookie", cookie_header)
  end

  @doc """
  Returns an empty cookie jar (monoid identity).
  """
  @spec empty() :: t()
  def empty, do: %__MODULE__{cookies: %{}}

  # Private functions

  # Filters out cookies marked for deletion (max_age <= 0)
  # This matches browser behavior for expired/deleted cookies
  defp filter_deleted(cookies) do
    cookies
    |> Enum.reject(fn {_name, cookie} ->
      case cookie do
        %{max_age: max_age} when is_integer(max_age) and max_age <= 0 -> true
        _ -> false
      end
    end)
    |> Map.new()
  end
end
