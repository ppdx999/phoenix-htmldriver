defmodule PhoenixHtmldriver.CookieJar do
  @moduledoc """
  Cookie management with proper monoid structure.

  This module handles cookie storage and merging with the following guarantees:
  - Cookies form a monoid under merge operation
  - Deleted cookies (max_age <= 0) are automatically removed
  - Browser-like behavior for cookie handling
  """

  @type cookie :: %{
          value: String.t(),
          max_age: integer() | nil,
          path: String.t() | nil,
          domain: String.t() | nil,
          secure: boolean() | nil,
          http_only: boolean() | nil,
          same_site: atom() | nil
        }

  @type t :: %{optional(String.t()) => cookie()}

  @doc """
  Extracts cookies from a Plug.Conn response.

  Returns a map of cookie name to cookie struct.
  """
  @spec extract(Plug.Conn.t()) :: t()
  def extract(response) do
    response.resp_cookies
  end

  @doc """
  Merges cookies using monoid structure with cookie deletion support.

  ## Monoid Properties

  - **Identity**: `merge(%{}, a) = merge(a, %{}) = a`
  - **Associativity**: `merge(merge(a, b), c) = merge(a, merge(b, c))`
  - **Right-biased**: `merge(%{k: v1}, %{k: v2}) = %{k: v2}`
  - **Deletion**: Cookies with `max_age <= 0` are removed

  ## Examples

      iex> merge(%{"session" => %{value: "old"}}, %{"session" => %{value: "new"}})
      %{"session" => %{value: "new"}}

      iex> merge(%{"session" => %{value: "keep"}}, %{})
      %{"session" => %{value: "keep"}}

      iex> merge(%{"session" => %{value: "old"}}, %{"session" => %{value: "", max_age: 0}})
      %{}

  """
  @spec merge(t() | nil, t() | nil) :: t()
  def merge(existing, new) when is_map(existing) and is_map(new) do
    existing
    |> Map.merge(new)
    |> filter_deleted()
  end

  def merge(nil, new) when is_map(new) do
    filter_deleted(new)
  end

  def merge(existing, nil) when is_map(existing) do
    existing
  end

  def merge(nil, nil), do: %{}

  @doc """
  Puts cookies into a request conn by setting the Cookie header.

  Returns the conn with Cookie header set, or unchanged conn if no cookies.
  """
  @spec put_into_request(Plug.Conn.t(), t() | nil) :: Plug.Conn.t()
  def put_into_request(conn, nil), do: conn
  def put_into_request(conn, cookies) when map_size(cookies) == 0, do: conn

  def put_into_request(conn, cookies) do
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
  def empty, do: %{}

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
