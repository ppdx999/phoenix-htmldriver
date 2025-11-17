defmodule PhoenixHtmldriver.Form do
  @moduledoc """
  Represents a form within a browser session.

  A Form encapsulates form-specific state and operations while inheriting
  the session context (conn, endpoint, cookies, path) from the parent Session.

  Forms automatically parse all field values from the DOM, including hidden inputs
  like CSRF tokens. You can modify field values with `fill/2` and submit the form
  with `submit/1`.

  ## Usage

      session
      |> Form.new("#login-form")
      |> Form.fill(%{username: "alice", password: "secret"})
      |> Form.submit()

  ## Supported Field Types

  - Text inputs (text, email, password, search, tel, url, etc.)
  - Number inputs (number, range)
  - Date/time inputs (date, time, datetime-local, month, week)
  - Color picker (color)
  - Hidden inputs (hidden)
  - Checkboxes (checkbox) - use `fill/2` to check, `uncheck/2` to uncheck
  - Radio buttons (radio)
  - Select dropdowns (select)
  - Text areas (textarea)

  Submit, button, file, reset, and image inputs are ignored during parsing.
  """

  alias PhoenixHtmldriver.{HTTP, StringMap, Session}

  defstruct [:session, :node, :values]

  @type t :: %__MODULE__{
          session: Session.t(),
          node: Floki.html_node(),
          values: map()
        }

  @doc """
  Creates a new Form from a Session.

  Finds the form element in the session's document using the given CSS selector,
  parses all field values from the DOM (including hidden inputs, selected options,
  and checked checkboxes/radios), and returns a Form struct ready for filling and
  submitting.

  ## Field Parsing

  The form automatically parses and includes:
  - Text inputs with their current values
  - Hidden inputs (like CSRF tokens)
  - Selected options from select elements
  - Checked checkboxes and radio buttons
  - Textarea content

  Fields without values (unchecked checkboxes, unselected radios, empty inputs)
  are not included in the initial values map.

  ## Examples

      alias PhoenixHtmldriver.Form

      # Find and parse a form
      session
      |> Form.new("#login-form")
      |> Form.fill(username: "alice")
      |> Form.submit()

      # Form with CSRF token automatically included
      session
      |> Form.new("form[action='/users']")
      |> Form.fill(name: "Alice")
      |> Form.submit()

  ## Errors

  Raises if the form is not found in the document.
  """
  @spec new(Session.t(), String.t()) :: t()
  def new(%Session{document: document} = session, selector) do
    case Floki.find(document, selector) do
      [] ->
        raise "Form not found: #{selector}"

      [node | _] ->
        %__MODULE__{
          session: session,
          node: node,
          values: parse_form_values(node)
        }
    end
  end

  @doc """
  Fills form fields with the given values.

  Merges the provided field values with the form's current values, overriding
  any existing values for the same fields. Accepts both maps and keyword lists.
  Field names can be atoms or strings (they are normalized to strings internally).

  ## Examples

      # Using keyword list
      form
      |> fill(email: "user@example.com", password: "secret")
      |> submit()

      # Using map
      form
      |> fill(%{"country" => "Japan", "terms" => "on"})
      |> submit()

      # Multiple fills (values accumulate)
      form
      |> fill(email: "user@example.com")
      |> fill(password: "secret")
      |> submit()

  ## Field values

  All field values should be strings:

  - Text inputs (text, email, password, etc.): any string value
  - Number inputs (number, range): numeric value as string (e.g., "25", "50")
  - Date/time inputs (date, time, etc.): formatted string (e.g., "2024-01-01", "09:00")
  - Color input: hex color as string (e.g., "#ff0000")
  - Select: option value as string
  - Radio: option value as string
  - Checkbox (checked): "on" or the input's value attribute
  - Checkbox (unchecked): use `uncheck/2` to remove the field
  - Hidden inputs: any string value

  Note: PhoenixHtmldriver does not validate field values. It's your responsibility
  to provide valid values for each field type.
  """
  @spec fill(t(), map() | keyword()) :: t()
  def fill(%__MODULE__{values: current_values} = form, fields) do
    # Simple merge - new values override current values
    updated_values = StringMap.merge(current_values, fields)

    %{form | values: updated_values}
  end

  @doc """
  Unchecks a checkbox by removing its field from the form values.

  When a checkbox is unchecked in HTML forms, its field is not submitted to the server.
  This function mimics that behavior by removing the field from the form's values map.

  Accepts both string and atom field names.

  ## Examples

      # Uncheck a checkbox that was checked by fill/2
      form
      |> fill(terms: "on")
      |> uncheck(:terms)
      |> submit()

      # Uncheck a checkbox that was parsed as checked from the DOM
      form
      |> uncheck("newsletter")
      |> submit()

      # Can be used with any field, not just checkboxes
      form
      |> fill(optional_field: "value")
      |> uncheck(:optional_field)
      |> submit()
  """
  @spec uncheck(t(), String.t() | atom()) :: t()
  def uncheck(%__MODULE__{values: current_values} = form, field_name) do
    updated_values = StringMap.delete(current_values, field_name)
    %{form | values: updated_values}
  end

  @doc """
  Submits the form and returns a new Session.

  Submits the form with its current values. Use `fill/2` to set values before submitting.

  All form fields (including hidden inputs like CSRF tokens) are automatically
  included from the form's current values. The form's action and method attributes
  are used to determine where and how to submit.

  ## Form Method Validation

  Per HTML specification, only GET and POST methods are supported. If the form
  specifies a different method (PUT, PATCH, DELETE), an ArgumentError is raised.

  For PUT/PATCH/DELETE requests in Phoenix, use the method override pattern:

      <form method="post">
        <input type="hidden" name="_method" value="put" />
      </form>

  PhoenixHtmldriver will submit as POST with the `_method` parameter, and
  Phoenix's `Plug.MethodOverride` will handle the conversion.

  ## Form Action

  - If the form has an `action` attribute, it will be used as the submit path
  - If no `action` is specified, the form submits to the current page path
  - Default method is GET if not specified

  ## Examples

      # Submit with filled values (includes CSRF token from hidden input)
      form
      |> fill(%{email: "user@example.com", password: "secret"})
      |> submit()

      # Submit without filling (uses parsed DOM values including hidden fields)
      form
      |> submit()

      # Multiple fills before submit
      form
      |> fill(%{email: "user@example.com"})
      |> fill(%{password: "secret"})
      |> submit()

  ## Returns

  A new `PhoenixHtmldriver.Session.t()` struct representing the response after
  form submission, including any redirects that were followed.
  """
  @spec submit(t()) :: Session.t()
  def submit(%__MODULE__{session: %Session{conn: conn, endpoint: endpoint, cookies: cookies, path: path}, node: node, values: current_values} = _form) do
    # Get form action and method
    # Per HTML spec, if action is not specified, form submits to current URL
    action = attr(node, "action") || path
    method = (attr(node, "method") || "get") |> String.downcase() |> String.to_atom()

    # Validate method - HTML forms only support get and post
    unless method in [:get, :post] do
      raise ArgumentError, """
      Invalid form method: '#{method}'.

      HTML forms only support 'get' or 'post' methods.

      For PUT/PATCH/DELETE requests in Phoenix, use method override:
        <form method="post">
          <input type="hidden" name="_method" value="put" />
        </form>

      Then PhoenixHtmldriver will submit as POST with _method parameter,
      and Phoenix's Plug.MethodOverride will handle the conversion.
      """
    end

    # Submit the form
    # HTTP.perform_request handles method-specific details (query string for GET, body for POST)
    HTTP.perform_request(method, action, conn, endpoint, cookies, current_values)
  end

  # Helper to get attribute value
  defp attr(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  # Extract value from form element based on element type
  defp value({"input", _attrs, _children} = input) do
    input_type = attr(input, "type") || "text"

    case String.downcase(input_type) do
      "checkbox" -> attr(input, "checked") && (attr(input, "value") || "on")
      "radio" -> attr(input, "checked") && attr(input, "value")
      type when type in ["file", "submit", "button", "reset", "image"] -> nil
      _ -> attr(input, "value") || ""
    end
  end

  defp value({"textarea", _attrs, children}) do
    Floki.text(children) |> String.trim()
  end

  defp value({"select", _attrs, _children} = select) do
    case Floki.find(select, "option[selected]") do
      [option | _] ->
        attr(option, "value") || Floki.text(option)

      [] ->
        case Floki.find(select, "option") do
          [first_option | _] ->
            attr(first_option, "value") || Floki.text(first_option)

          [] ->
            ""
        end
    end
  end

  defp value(_), do: nil

  # Parse form and extract default values from all fields
  defp parse_form_values(form) do
    form
    |> Floki.find("input, textarea, select")
    |> Enum.filter(&has_valid_name?/1)
    |> Enum.map(&to_name_value_pair/1)
    |> Enum.reject(fn {_name, val} -> is_nil(val) end)
    |> Enum.into(%{})
  end

  # Checks if element has a valid name attribute
  defp has_valid_name?(element) do
    case attr(element, "name") do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  # Transforms element to {name, value} pair
  defp to_name_value_pair(element) do
    {attr(element, "name"), value(element)}
  end
end
