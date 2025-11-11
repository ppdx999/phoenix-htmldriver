# PhoenixHtmldriver

A lightweight Phoenix library for testing pure HTML interactions without the overhead of a headless browser. PhoenixHtmldriver provides a human-like API for testing Phoenix applications' HTML output, inspired by Capybara and Wallaby but optimized for pure HTML testing.

## Features

- **Session-based API**: Chain interactions naturally with a session object
- **Lightweight**: No headless browser overhead - pure HTML parsing with Floki
- **Phoenix Integration**: Seamlessly works with Phoenix.ConnTest
- **Human-readable**: Intuitive API that mirrors user interactions
- **Fast**: Significantly faster than browser-based testing

## Installation

Add `phoenix_htmldriver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_htmldriver, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Example

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  import PhoenixHtmldriver

  test "login flow", %{conn: conn} do
    # Visit a page
    session = visit(conn, "/login")

    # Fill and submit a form
    session
    |> fill_form("#login-form", username: "alice", password: "secret")
    |> submit_form("#login-form")
    |> assert_text("Welcome, alice")
    |> assert_selector(".alert-success")
  end
end
```

### Navigation

```elixir
# Visit a page
session = visit(conn, "/home")

# Click a link by selector
session = click_link(session, "#about-link")

# Click a link by text
session = click_link(session, "About Us")

# Get current path
path = current_path(session)
```

### Forms

```elixir
# Fill in a form (prepares values)
session = fill_form(session, "#contact-form",
  name: "Alice",
  email: "alice@example.com",
  message: "Hello!"
)

# Submit a form
session = submit_form(session, "#contact-form")

# Or submit with values directly
session = submit_form(session, "#contact-form",
  name: "Alice",
  email: "alice@example.com"
)
```

### Assertions

```elixir
# Assert text is present
session = assert_text(session, "Welcome back")

# Assert element exists
session = assert_selector(session, ".alert-success")
session = assert_selector(session, "#user-profile")

# Assert element does not exist
session = refute_selector(session, ".alert-danger")
```

### Finding Elements

```elixir
# Find a single element
{:ok, element} = find(session, ".user-name")
text = PhoenixHtmldriver.Element.text(element)

# Find all matching elements
elements = find_all(session, ".list-item")
length(elements) # => 5

# Get element attributes
{:ok, element} = find(session, "#profile-link")
href = PhoenixHtmldriver.Element.attr(element, "href")
has_id = PhoenixHtmldriver.Element.has_attr?(element, "id")
```

### Inspecting Responses

```elixir
# Get current HTML
html = current_html(session)

# Get current path
path = current_path(session)
```

## API Reference

### Session Functions

- `visit(conn, path)` - Navigate to a path and create a new session
- `click_link(session, selector_or_text)` - Click a link by selector or text
- `fill_form(session, selector, values)` - Fill in form fields
- `submit_form(session, selector, values \\ [])` - Submit a form
- `assert_text(session, text)` - Assert text is present
- `assert_selector(session, selector)` - Assert element exists
- `refute_selector(session, selector)` - Assert element doesn't exist
- `find(session, selector)` - Find a single element
- `find_all(session, selector)` - Find all matching elements
- `current_path(session)` - Get current request path
- `current_html(session)` - Get current response HTML

### Element Functions

- `PhoenixHtmldriver.Element.text(element)` - Get element text content
- `PhoenixHtmldriver.Element.attr(element, name)` - Get attribute value
- `PhoenixHtmldriver.Element.has_attr?(element, name)` - Check if attribute exists

## How It Works

PhoenixHtmldriver uses Floki to parse HTML and Plug.Test to simulate HTTP requests. Unlike browser-based testing tools, it works directly with your Phoenix application's conn struct, making tests fast and reliable.

The library maintains a Session struct that tracks:
- The current conn
- The parsed HTML document
- The latest response
- The endpoint being tested

This allows for natural chaining of interactions while maintaining the state of the "browsing session".

## Comparison with Other Tools

### vs. Wallaby/Hound (Browser-based)
- **Faster**: No browser startup overhead
- **Simpler**: No JavaScript support, pure HTML only
- **More Reliable**: No flaky browser interactions
- **Limited**: Cannot test JavaScript behavior

### vs. Phoenix.ConnTest (Direct)
- **More Natural**: Human-like API vs. low-level HTTP
- **Chainable**: Session-based interactions
- **HTML-aware**: Built-in selectors and assertions
- **Simpler Forms**: Easy form filling and submission

## When to Use

PhoenixHtmldriver is perfect for:
- Testing server-rendered HTML applications
- Controller and view testing
- Form submission flows
- Multi-step interactions
- Fast integration tests

It's not suitable for:
- Testing JavaScript-heavy applications
- Testing client-side interactions
- Testing WebSocket behavior

## Examples

### Testing a Multi-Step Flow

```elixir
test "user registration and profile update", %{conn: conn} do
  # Register a new user
  session =
    visit(conn, "/register")
    |> fill_form("#registration-form",
      username: "alice",
      email: "alice@example.com",
      password: "secret123"
    )
    |> submit_form("#registration-form")

  # Verify registration success
  session = assert_text(session, "Welcome, alice!")

  # Navigate to profile
  session = click_link(session, "Edit Profile")

  # Update profile
  session
    |> fill_form("#profile-form", bio: "Hello, I'm Alice")
    |> submit_form("#profile-form")
    |> assert_text("Profile updated successfully")
end
```

### Testing with Assertions

```elixir
test "validates form submission", %{conn: conn} do
  visit(conn, "/contact")
  |> submit_form("#contact-form", name: "")  # Submit empty form
  |> assert_text("Name is required")
  |> assert_selector(".error-message")
  |> refute_selector(".success-message")
end
```

## Setting Up in Your Tests

To use PhoenixHtmldriver in your test cases, you need to ensure your conn has the endpoint set:

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  import PhoenixHtmldriver

  setup %{conn: conn} do
    conn = put_private(conn, :phoenix_endpoint, MyAppWeb.Endpoint)
    {:ok, conn: conn}
  end

  test "home page", %{conn: conn} do
    session = visit(conn, "/")
    assert_text(session, "Welcome")
  end
end
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
