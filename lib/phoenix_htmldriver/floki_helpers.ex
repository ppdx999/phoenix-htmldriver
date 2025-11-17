defmodule PhoenixHtmldriver.FlokiHelpers do
  @moduledoc """
  Helper functions for working with Floki nodes.

  This module provides utility functions that wrap common Floki operations
  with more convenient return values.
  """

  @doc """
  Gets an attribute value from a Floki node.

  Returns the attribute value as a string, or `nil` if the attribute doesn't exist.

  ## Examples

      iex> node = {"a", [{"href", "/home"}, {"class", "link"}], ["Home"]}
      iex> FlokiHelpers.attr(node, "href")
      "/home"

      iex> node = {"div", [], []}
      iex> FlokiHelpers.attr(node, "missing")
      nil
  """
  @spec attr(Floki.html_node(), String.t()) :: String.t() | nil
  def attr(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
