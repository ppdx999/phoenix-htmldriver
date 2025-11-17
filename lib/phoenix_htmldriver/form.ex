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

  defstruct [:selector, :node, :values, :endpoint, :cookies, :path]

  @type t :: %__MODULE__{
          selector: String.t(),
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
      selector: selector,
      node: node,
      values: values,
      endpoint: endpoint,
      cookies: cookies,
      path: path
    }
  end

  @doc """
  Fills the form with the given values.

  Updates the form's current values, mimicking how a browser updates the DOM
  when a user fills in form fields.

  ## Examples

      form
      |> fill(%{email: "user@example.com", password: "secret"})
      |> submit()

      # Can also use keyword lists
      form
      |> fill(email: "test@example.com", password: "secret")
      |> submit()
  """
  @spec fill(t(), keyword() | map()) :: t()
  def fill(%__MODULE__{values: current_values} = form, new_values) do
    # Convert keyword list to map and normalize keys
    normalized_new_values = new_values |> Enum.into(%{}) |> normalize_keys()

    # Merge with current values (mimicking DOM state update)
    updated_values = Map.merge(current_values, normalized_new_values)

    %{form | values: updated_values}
  end

  @doc """
  Submits the form and returns a new Session.

  Optionally accepts additional values to merge with the form's current values
  before submission. Additional values take priority over current values.

  All form fields (including hidden inputs like CSRF tokens) are automatically
  included from the form's current values.

  ## Examples

      # Submit with current values (includes CSRF token from hidden input)
      form
      |> fill(%{email: "user@example.com"})
      |> submit()

      # Submit with additional values (override current values)
      form
      |> fill(%{email: "user@example.com"})
      |> submit(%{remember_me: "on"})

      # Submit without filling (uses parsed DOM values including hidden fields)
      form
      |> submit(%{email: "user@example.com", password: "secret"})
  """
  @spec submit(t(), keyword() | map()) :: PhoenixHtmldriver.Session.t()
  def submit(%__MODULE__{node: node, selector: _selector, values: current_values, endpoint: endpoint, cookies: cookies, path: path} = _form, additional_values \\ []) do
    # Get form action and method
    # Per HTML spec, if action is not specified, form submits to current URL
    action = get_attribute(node, "action") || path
    method = get_attribute(node, "method") || "get"
    method_atom = String.downcase(method) |> String.to_atom()

    # Normalize additional values
    normalized_additional = additional_values |> Enum.into(%{}) |> normalize_keys()

    # Merge current values with additional values (additional takes priority)
    # CSRF tokens from hidden inputs are already in current_values
    form_values = Map.merge(current_values, normalized_additional)

    # Submit the form - handle GET specially (query params in URL)
    {final_response, final_cookies, new_document} =
      case method_atom do
        :get ->
          # GET forms encode params in query string
          path_with_query = action <> "?" <> URI.encode_query(form_values)
          HTTP.perform_request(:get, path_with_query, endpoint, cookies)

        method when method in [:post, :put, :patch] ->
          # POST/PUT/PATCH forms send params in body
          HTTP.perform_request(method, action, endpoint, cookies, form_values)

        :delete ->
          # DELETE typically doesn't have a body
          HTTP.perform_request(:delete, action, endpoint, cookies)
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

  # Normalize map keys to strings, recursively handling nested maps
  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      normalized_key = if is_atom(key), do: Atom.to_string(key), else: key
      normalized_value = if is_map(value), do: normalize_keys(value), else: value
      {normalized_key, normalized_value}
    end)
  end

  defp normalize_keys(value), do: value

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
    name = get_attribute(element, "name")

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
        Floki.text(children) |> String.trim()

      {"select", _attrs, _children} ->
        extract_select_value(element)

      _ ->
        nil
    end
  end

  # Extract value from input element based on type
  defp extract_input_value(input) do
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

  # Extract value from select element
  defp extract_select_value(select) do
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
end
