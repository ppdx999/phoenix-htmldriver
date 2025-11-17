defmodule PhoenixHtmldriver.Form do
  @moduledoc """
  Represents a form within a browser session.

  A Form encapsulates form-specific state and operations while inheriting
  the session context (endpoint, cookies, etc.) from the parent Session.

  ## Usage

      session
      |> Session.form("#login-form")
      |> Form.fill(%{username: "alice", password: "secret"})
      |> Form.submit()
  """

  alias PhoenixHtmldriver.HTTP

  defstruct [:node, :values, :endpoint, :cookies, :path]

  @type t :: %__MODULE__{
          node: Floki.html_node(),
          values: map(),
          endpoint: module(),
          cookies: map(),
          path: String.t()
        }

  @doc """
  Creates a new Form from a Session.

  Finds the form by selector, parses its default values, and returns
  a Form struct ready for filling and submitting.

  ## Examples

      alias PhoenixHtmldriver.Form

      session
      |> Form.new("#login-form")
      |> Form.fill(username: "alice")
      |> Form.submit()
  """
  @spec new(PhoenixHtmldriver.Session.t(), String.t()) :: t()
  def new(%PhoenixHtmldriver.Session{document: document, endpoint: endpoint, cookies: cookies, path: path}, selector) do
    # Find the form
    form_node = Floki.find(document, selector)

    if Enum.empty?(form_node) do
      raise "Form not found: #{selector}"
    end

    [node | _] = form_node

    # Parse form to get current DOM state (initial values)
    values = parse_form_values(node)

    %__MODULE__{
      node: node,
      values: values,
      endpoint: endpoint,
      cookies: cookies,
      path: path
    }
  end

  @doc """
  Fills form fields with the given values.

  Merges the provided field values with the form's current values.
  Accepts both maps and keyword lists. Field names can be atoms or strings.

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

  - Text inputs: any string value
  - Select: option value as string
  - Radio: option value as string
  - Checkbox (checked): "on" or the input's value attribute
  - Checkbox (unchecked): use `uncheck/2` to remove the field
  """
  @spec fill(t(), map() | keyword()) :: t()
  def fill(%__MODULE__{values: current_values} = form, fields) do
    # Convert to map and normalize all keys to strings
    normalized_fields =
      fields
      |> Enum.into(%{})
      |> Map.new(fn {key, value} -> {normalize_field_name(key), value} end)

    # Simple merge - new values override current values
    updated_values = Map.merge(current_values, normalized_fields)

    %{form | values: updated_values}
  end

  @doc """
  Unchecks a checkbox by removing its field from the form.

  ## Examples

      form
      |> fill(terms: "on")
      |> uncheck("terms")
      |> submit()
  """
  @spec uncheck(t(), String.t() | atom()) :: t()
  def uncheck(%__MODULE__{values: current_values} = form, field_name) do
    updated_values = Map.delete(current_values, normalize_field_name(field_name))
    %{form | values: updated_values}
  end

  @doc """
  Submits the form and returns a new Session.

  Submits the form with its current values. Use `fill/2` to set values before submitting.

  All form fields (including hidden inputs like CSRF tokens) are automatically
  included from the form's current values.

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
  """
  @spec submit(t()) :: PhoenixHtmldriver.Session.t()
  def submit(%__MODULE__{node: node, values: current_values, endpoint: endpoint, cookies: cookies, path: path} = _form) do
    # Get form action and method
    # Per HTML spec, if action is not specified, form submits to current URL
    action = get_attribute(node, "action") || path
    method = (get_attribute(node, "method") || "get") |> String.downcase() |> String.to_atom()

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

    # Use current form values (already includes all fields including CSRF tokens)
    form_values = current_values

    # Submit the form - handle GET specially (query params in URL)
    {final_response, final_cookies, new_document} =
      case method do
        :get ->
          # GET forms encode params in query string
          path_with_query = action <> "?" <> URI.encode_query(form_values)
          HTTP.perform_request(:get, path_with_query, endpoint, cookies)

        :post ->
          # POST forms send params in body
          HTTP.perform_request(:post, action, endpoint, cookies, form_values)
      end

    # Return a new Session struct
    # Note: We need to get the original conn from somewhere
    # This is a design decision - for now we'll create a minimal session
    %PhoenixHtmldriver.Session{
      conn: nil,  # Will be set by Session module
      document: new_document,
      response: final_response,
      endpoint: endpoint,
      cookies: final_cookies,
      path: final_response.request_path
    }
  end

  # Helper to get attribute value
  defp get_attribute(node, name) do
    case Floki.attribute(node, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  # Normalize field name to string (atom -> string)
  defp normalize_field_name(field_name) when is_atom(field_name), do: Atom.to_string(field_name)
  defp normalize_field_name(field_name) when is_binary(field_name), do: field_name

  # Parse form and extract default values from all fields
  defp parse_form_values(form) do
    form
    |> Floki.find("input, textarea, select")
    |> Enum.reduce(%{}, fn element, acc ->
      case extract_field_value(element) do
        {name, value} when is_binary(name) -> Map.put(acc, name, value)
        nil -> acc
      end
    end)
  end

  # Extract name and value from a single form field
  defp extract_field_value(element) do
    case get_attribute(element, "name") do
      nil -> nil
      "" -> nil
      name -> {name, extract_value(element)}
    end
  end

  # Extract value based on element type
  defp extract_value({"input", _attrs, _children} = input) do
    input_type = get_attribute(input, "type") || "text"

    case String.downcase(input_type) do
      "checkbox" ->
        if get_attribute(input, "checked") do
          get_attribute(input, "value") || "on"
        else
          nil
        end

      "radio" ->
        if get_attribute(input, "checked") do
          get_attribute(input, "value")
        else
          nil
        end

      type when type in ["file", "submit", "button", "reset", "image"] ->
        nil

      _ ->
        # text, password, email, hidden, number, etc.
        get_attribute(input, "value") || ""
    end
  end

  defp extract_value({"textarea", _attrs, children}) do
    Floki.text(children) |> String.trim()
  end

  defp extract_value({"select", _attrs, _children} = select) do
    case Floki.find(select, "option[selected]") do
      [option | _] ->
        get_attribute(option, "value") || Floki.text(option)

      [] ->
        case Floki.find(select, "option") do
          [first_option | _] ->
            get_attribute(first_option, "value") || Floki.text(first_option)

          [] ->
            ""
        end
    end
  end

  defp extract_value(_), do: nil
end
