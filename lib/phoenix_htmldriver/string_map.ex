defmodule PhoenixHtmldriver.StringMap do
  @moduledoc """
  A map that normalizes atom and string keys to strings.

  This module provides convenience functions for working with maps that accept
  both atom and string keys but internally store everything as strings. This is
  useful for APIs that want to provide flexible input while maintaining internal
  consistency.

  ## Examples

      iex> StringMap.new(username: "alice", password: "secret")
      %{"username" => "alice", "password" => "secret"}

      iex> StringMap.new(%{"email" => "test@example.com", password: "secret"})
      %{"email" => "test@example.com", "password" => "secret"}

      iex> map = StringMap.new(%{"name" => "Alice"})
      iex> StringMap.put(map, :age, 25)
      %{"name" => "Alice", "age" => 25}

      iex> map = StringMap.new(%{"username" => "alice"})
      iex> StringMap.get(map, :username)
      "alice"
  """

  @type t :: %{String.t() => any()}

  @doc """
  Creates a new string-keyed map from the given data.

  Accepts a map or keyword list with atom or string keys, and returns
  a map with all keys normalized to strings.

  ## Examples

      iex> StringMap.new(username: "alice")
      %{"username" => "alice"}

      iex> StringMap.new(%{"email" => "test@example.com", password: "secret"})
      %{"email" => "test@example.com", "password" => "secret"}

      iex> StringMap.new([])
      %{}
  """
  @spec new(map() | keyword()) :: t()
  def new(data) do
    data
    |> Enum.into(%{})
    |> Map.new(fn {key, value} -> {normalize_key(key), value} end)
  end

  @doc """
  Puts a value into the map with the given key.

  The key can be an atom or string and will be normalized to a string.

  ## Examples

      iex> map = %{"name" => "Alice"}
      iex> StringMap.put(map, :age, 25)
      %{"name" => "Alice", "age" => 25}

      iex> map = %{}
      iex> StringMap.put(map, "email", "test@example.com")
      %{"email" => "test@example.com"}
  """
  @spec put(t(), atom() | String.t(), any()) :: t()
  def put(map, key, value) do
    Map.put(map, normalize_key(key), value)
  end

  @doc """
  Gets a value from the map by key.

  The key can be an atom or string and will be normalized to a string.
  Returns the default value if the key is not found.

  ## Examples

      iex> map = %{"username" => "alice"}
      iex> StringMap.get(map, :username)
      "alice"

      iex> map = %{"username" => "alice"}
      iex> StringMap.get(map, "username")
      "alice"

      iex> map = %{"username" => "alice"}
      iex> StringMap.get(map, :missing, "default")
      "default"
  """
  @spec get(t(), atom() | String.t(), any()) :: any()
  def get(map, key, default \\ nil) do
    Map.get(map, normalize_key(key), default)
  end

  @doc """
  Deletes a key from the map.

  The key can be an atom or string and will be normalized to a string.

  ## Examples

      iex> map = %{"username" => "alice", "password" => "secret"}
      iex> StringMap.delete(map, :password)
      %{"username" => "alice"}

      iex> map = %{"username" => "alice"}
      iex> StringMap.delete(map, "missing")
      %{"username" => "alice"}
  """
  @spec delete(t(), atom() | String.t()) :: t()
  def delete(map, key) do
    Map.delete(map, normalize_key(key))
  end

  @doc """
  Merges two maps, with values from the second map taking precedence.

  The second argument can be a map or keyword list with atom or string keys.
  All keys are normalized to strings.

  ## Examples

      iex> map = %{"username" => "alice"}
      iex> StringMap.merge(map, password: "secret")
      %{"username" => "alice", "password" => "secret"}

      iex> map = %{"username" => "alice", "email" => "old@example.com"}
      iex> StringMap.merge(map, %{"email" => "new@example.com", "password" => "secret"})
      %{"username" => "alice", "email" => "new@example.com", "password" => "secret"}
  """
  @spec merge(t(), map() | keyword()) :: t()
  def merge(map, data) do
    Map.merge(map, new(data))
  end

  # Normalizes a key to a string
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
end
