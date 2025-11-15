defmodule PhoenixHtmldriver.FormParser do
  @moduledoc """
  Parses HTML forms and extracts default values from input fields.

  Mimics browser behavior by:
  - Extracting hidden input values
  - Extracting default values from text/email/password/etc inputs
  - Handling checkboxes (checked = "on", unchecked = not included)
  - Handling radio buttons (checked one gets its value)
  - Handling textareas
  - Handling select elements (selected option's value)

  This ensures that forms submitted without explicit values still
  include all default values, just like a real browser.
  """

  @doc """
  Parses all forms in a document and extracts their default values.

  Returns a map where keys are form selectors (or generated IDs) and
  values are maps of field names to default values.

  ## Examples

      iex> parse_forms(document)
      %{
        "#login-form" => %{"_csrf_token" => "abc", "remember" => "on"},
        "#search" => %{"q" => "", "filter" => "all"}
      }

  """
  @spec parse_forms(Floki.html_tree()) :: %{String.t() => map()}
  def parse_forms(document) do
    document
    |> Floki.find("form")
    |> Enum.reduce(%{}, fn form, acc ->
      selector = form_selector(form)
      values = extract_form_values(form)
      Map.put(acc, selector, values)
    end)
  end

  @doc """
  Extracts default values from a specific form element.

  ## Examples

      iex> extract_form_values(form_node)
      %{"_csrf_token" => "abc123", "name" => "Alice", "active" => "on"}

  """
  @spec extract_form_values(Floki.html_node()) :: map()
  def extract_form_values(form) do
    form
    |> Floki.find("input, textarea, select")
    |> Enum.reduce(%{}, fn element, acc ->
      case extract_field_value(element) do
        {name, value} when is_binary(name) -> Map.put(acc, name, value)
        nil -> acc
      end
    end)
  end

  # Private functions

  # Generate a selector for a form (ID, name, or position-based)
  defp form_selector(form) do
    cond do
      id = get_attribute(form, "id") ->
        "##{id}"

      name = get_attribute(form, "name") ->
        "form[name='#{name}']"

      true ->
        # Generate a unique selector based on action or position
        action = get_attribute(form, "action") || "unknown"
        "form[action='#{action}']"
    end
  end

  # Extract value from a single form field
  defp extract_field_value(element) do
    name = get_attribute(element, "name")

    # Skip fields without names
    if !name || name == "" do
      nil
    else
      value = extract_value_by_type(element)
      {name, value}
    end
  end

  # Extract value based on element type
  defp extract_value_by_type(element) do
    case element do
      {"input", _attrs, _children} ->
        extract_input_value(element)

      {"textarea", _attrs, children} ->
        # Textarea value is in text content
        Floki.text(children) |> String.trim()

      {"select", _attrs, _children} ->
        extract_select_value(element)

      _ ->
        nil
    end
  end

  # Extract value from input element
  defp extract_input_value(input) do
    input_type = get_attribute(input, "type") || "text"

    case String.downcase(input_type) do
      "checkbox" ->
        # Checkbox: only include if checked
        if get_attribute(input, "checked") do
          get_attribute(input, "value") || "on"
        else
          nil
        end

      "radio" ->
        # Radio: only include if checked
        if get_attribute(input, "checked") do
          get_attribute(input, "value")
        else
          nil
        end

      "file" ->
        # File inputs don't have default values
        nil

      "submit" ->
        # Submit buttons are not included in default values
        nil

      "button" ->
        # Buttons are not included in default values
        nil

      "reset" ->
        # Reset buttons are not included
        nil

      "image" ->
        # Image inputs are not included in default values
        nil

      _ ->
        # text, password, email, hidden, number, etc.
        get_attribute(input, "value") || ""
    end
  end

  # Extract value from select element
  defp extract_select_value(select) do
    # Find selected option
    case Floki.find(select, "option[selected]") do
      [option | _] ->
        get_attribute(option, "value") || Floki.text(option)

      [] ->
        # No selected option, use first option's value
        case Floki.find(select, "option") do
          [first_option | _] ->
            get_attribute(first_option, "value") || Floki.text(first_option)

          [] ->
            ""
        end
    end
  end

  # Get attribute value from element
  defp get_attribute(element, name) do
    case Floki.attribute(element, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
