defmodule PhoenixHtmldriver.Element do
  @moduledoc """
  Represents an HTML element within a browser session.

  An Element encapsulates element-specific operations while being found
  from a parent Session.

  ## Usage

      session
      |> Element.new("#profile")
      |> Element.text()

      session
      |> Element.new(".alert")
      |> Element.attr("class")
  """

  alias PhoenixHtmldriver.Session

  defstruct [:node]

  @type t :: %__MODULE__{
          node: Floki.html_tree()
        }

  @doc """
  Creates a new Element from a Session.

  Finds an element in the session's document using the given CSS selector,
  and returns an Element struct.

  ## Examples

      alias PhoenixHtmldriver.Element

      # Find by CSS selector
      session
      |> Element.new("#profile")
      |> Element.text()

      # Find by class
      session
      |> Element.new(".alert-success")
      |> Element.attr("class")

  ## Errors

  Raises if the element is not found in the document.
  """
  @spec new(Session.t(), String.t()) :: t()
  def new(%Session{document: document}, selector) do
    case Floki.find(document, selector) do
      [] ->
        raise "Element not found: #{selector}"

      [node | _] ->
        %__MODULE__{node: node}
    end
  end

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
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  @doc """
  Checks if the element has an attribute.
  """
  @spec has_attr?(t(), String.t()) :: boolean()
  def has_attr?(%__MODULE__{} = element, name) do
    attr(element, name) != nil
  end
end
