defmodule PhoenixHtmldriver.Element do
  @moduledoc """
  Represents an HTML element.
  """

  alias PhoenixHtmldriver.FlokiHelpers

  defstruct [:node]

  @type t :: %__MODULE__{
          node: Floki.html_tree()
        }

  @doc """
  Gets the text content of the element.
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{node: node}) do
    node
    |> Floki.text()
    |> String.trim()
  end

  @doc """
  Gets an attribute value from the element.
  """
  @spec attr(t(), String.t()) :: String.t() | nil
  def attr(%__MODULE__{node: node}, name) do
    FlokiHelpers.attr(node, name)
  end

  @doc """
  Checks if the element has an attribute.
  """
  @spec has_attr?(t(), String.t()) :: boolean()
  def has_attr?(%__MODULE__{} = element, name) do
    attr(element, name) != nil
  end
end
