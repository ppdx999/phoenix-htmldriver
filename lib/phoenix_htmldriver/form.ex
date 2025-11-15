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

  alias PhoenixHtmldriver.{HTTP, FormParser}

  defstruct [:selector, :node, :default_values, :filled_values, :endpoint, :cookies]

  @type t :: %__MODULE__{
          selector: String.t(),
          node: Floki.html_node(),
          default_values: map(),
          filled_values: map(),
          endpoint: module(),
          cookies: map()
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
  def new(%PhoenixHtmldriver.Session{document: document, endpoint: endpoint, cookies: cookies}, selector) do
    # Find the form
    form_node = Floki.find(document, selector)

    if Enum.empty?(form_node) do
      raise "Form not found: #{selector}"
    end

    [node | _] = form_node

    # Parse form on-demand to extract default values
    default_values = FormParser.extract_form_values(node)

    %__MODULE__{
      selector: selector,
      node: node,
      default_values: default_values,
      filled_values: %{},
      endpoint: endpoint,
      cookies: cookies
    }
  end

  @doc """
  Fills the form with the given values.

  Values are stored and will be merged with default values when the form is submitted.

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
  def fill(%__MODULE__{} = form, values) do
    # Convert keyword list to map for consistent handling
    values_map = Enum.into(values, %{})

    # Merge with existing filled values
    new_filled_values = Map.merge(form.filled_values || %{}, values_map)

    %{form | filled_values: new_filled_values}
  end

  @doc """
  Submits the form and returns a new Session.

  Automatically merges default values, filled values, and any additional values
  provided to submit. Priority order: defaults < filled < submit.

  CSRF tokens are automatically extracted and included for POST/PUT/PATCH/DELETE requests.

  ## Examples

      # Submit with filled values
      form
      |> fill(%{email: "user@example.com"})
      |> submit()

      # Submit with additional values
      form
      |> fill(%{email: "user@example.com"})
      |> submit(%{remember_me: "on"})

      # Submit without filling
      form
      |> submit(%{email: "user@example.com", password: "secret"})
  """
  @spec submit(t(), keyword() | map()) :: PhoenixHtmldriver.Session.t()
  def submit(%__MODULE__{node: node, selector: _selector, default_values: default_values, filled_values: filled_values, endpoint: endpoint, cookies: cookies} = _form, values \\ []) do
    # Get form action and method
    action = get_attribute(node, "action") || "/"
    method = get_attribute(node, "method") || "get"
    method_atom = String.downcase(method) |> String.to_atom()

    # Convert values parameter to map and normalize keys to strings
    submit_values = normalize_keys(Enum.into(values, %{}))

    # Normalize filled_values keys to strings for consistent merging
    normalized_filled = normalize_keys(filled_values || %{})

    # Merge in priority order: defaults < filled < submit
    # All keys are strings at this point for consistent merging
    merged_values =
      (default_values || %{})
      |> Map.merge(normalized_filled)
      |> Map.merge(submit_values)

    # Extract CSRF token from form's hidden input (meta tag not supported)
    csrf_token = extract_csrf_token(node)

    # Merge CSRF token into values if present and method requires it
    form_values =
      if csrf_token && method_atom in [:post, :put, :patch, :delete] do
        # Only add CSRF token if not already present
        if Map.has_key?(merged_values, "_csrf_token") || Map.has_key?(merged_values, :_csrf_token) do
          merged_values
        else
          Map.put(merged_values, "_csrf_token", csrf_token)
        end
      else
        merged_values
      end

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
      cookies: final_cookies
    }
  end

  # Extract CSRF token from form's hidden input only
  # Meta tag CSRF tokens are not supported (use JavaScript-based testing tools for those)
  defp extract_csrf_token(form_node) do
    case Floki.find(form_node, "input[name='_csrf_token']") do
      [input | _] ->
        get_attribute(input, "value")

      [] ->
        nil
    end
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
end
