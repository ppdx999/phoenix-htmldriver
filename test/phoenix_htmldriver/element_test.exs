defmodule PhoenixHtmldriver.ElementTest do
  use ExUnit.Case

  alias PhoenixHtmldriver.Element

  describe "text/1" do
    test "extracts text content from element" do
      {:ok, [node]} = Floki.parse_fragment("<p>Hello World</p>")
      element = %Element{node: node}

      assert Element.text(element) == "Hello World"
    end

    test "extracts text with nested elements" do
      {:ok, [node]} = Floki.parse_fragment("<div><p>Hello</p><p>World</p></div>")
      element = %Element{node: node}

      # Floki concatenates text without newlines
      assert Element.text(element) == "HelloWorld"
    end

    test "trims whitespace" do
      {:ok, [node]} = Floki.parse_fragment("<p>  Hello World  </p>")
      element = %Element{node: node}

      assert Element.text(element) == "Hello World"
    end

    test "returns empty string for empty element" do
      {:ok, [node]} = Floki.parse_fragment("<div></div>")
      element = %Element{node: node}

      assert Element.text(element) == ""
    end
  end

  describe "attr/2" do
    test "gets attribute value" do
      {:ok, [node]} = Floki.parse_fragment("<a href='/about' id='link'>Link</a>")
      element = %Element{node: node}

      assert Element.attr(element, "href") == "/about"
      assert Element.attr(element, "id") == "link"
    end

    test "returns nil for missing attribute" do
      {:ok, [node]} = Floki.parse_fragment("<a href='/about'>Link</a>")
      element = %Element{node: node}

      assert Element.attr(element, "class") == nil
    end

    test "gets data attributes" do
      {:ok, [node]} = Floki.parse_fragment("<div data-id='123' data-name='test'>Content</div>")
      element = %Element{node: node}

      assert Element.attr(element, "data-id") == "123"
      assert Element.attr(element, "data-name") == "test"
    end

    test "returns empty string for empty attribute" do
      {:ok, [node]} = Floki.parse_fragment("<input disabled='' />")
      element = %Element{node: node}

      assert Element.attr(element, "disabled") == ""
    end
  end

  describe "has_attr?/2" do
    test "returns true when attribute exists" do
      {:ok, [node]} = Floki.parse_fragment("<a href='/about' id='link'>Link</a>")
      element = %Element{node: node}

      assert Element.has_attr?(element, "href")
      assert Element.has_attr?(element, "id")
    end

    test "returns false when attribute does not exist" do
      {:ok, [node]} = Floki.parse_fragment("<a href='/about'>Link</a>")
      element = %Element{node: node}

      refute Element.has_attr?(element, "class")
      refute Element.has_attr?(element, "data-id")
    end

    test "returns true for empty attributes" do
      {:ok, [node]} = Floki.parse_fragment("<input disabled='' />")
      element = %Element{node: node}

      assert Element.has_attr?(element, "disabled")
    end
  end
end
