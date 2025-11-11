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
    {:phoenix_htmldriver, "~> 0.6.0"}
  ]
end
```

## Usage

### Basic Example with `use PhoenixHtmldriver` (Recommended)

The easiest way to use PhoenixHtmldriver is with the `use PhoenixHtmldriver` macro, which automatically configures the endpoint:

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  use PhoenixHtmldriver  # Automatically configures endpoint!

  test "login flow", %{conn: conn} do
    # No manual setup needed - conn is automatically configured
    visit(conn, "/login")
    |> fill_form("#login-form", username: "alice", password: "secret")
    |> submit_form("#login-form")
    |> assert_text("Welcome, alice")
    |> assert_selector(".alert-success")
  end
end
```

**Important:** Make sure to set `@endpoint` **before** `use PhoenixHtmldriver`:

```elixir
defmodule MyTest do
  use ExUnit.Case

  @endpoint MyAppWeb.Endpoint  # Must come before use PhoenixHtmldriver
  use PhoenixHtmldriver

  # Tests...
end
```

### Manual Configuration (Advanced)

If you need more control, you can import functions directly:

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  import PhoenixHtmldriver

  setup %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_endpoint, MyAppWeb.Endpoint)
    %{conn: conn}
  end

  test "login flow", %{conn: conn} do
    session = visit(conn, "/login")
    # ...
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
# Fill in a form (stores values for later submission)
session = fill_form(session, "#contact-form",
  name: "Alice",
  email: "alice@example.com",
  message: "Hello!"
)

# Submit the form - values from fill_form are automatically included
session = submit_form(session, "#contact-form")

# Or combine fill_form and submit_form
session =
  fill_form(session, "#login-form", email: "user@example.com", password: "secret")
  |> submit_form("#login-form")

# Can also submit with values directly (without fill_form)
session = submit_form(session, "#search-form", q: "elixir")

# Values in submit_form override values from fill_form
session =
  fill_form(session, "form", username: "alice")
  |> submit_form("form", username: "bob")  # "bob" wins

# Supports nested maps for complex forms
session =
  fill_form(session, "form", %{user: %{email: "test@example.com", password: "secret"}})
  |> submit_form("form")

# CSRF tokens are automatically extracted and included!
# No manual CSRF handling needed for forms with CSRF protection
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

## Session and Cookie Handling

PhoenixHtmldriver automatically preserves session cookies across requests, enabling you to test multi-step flows naturally:

```elixir
test "login flow with session", %{conn: conn} do
  visit(conn, "/login")
  |> submit_form("#login-form", email: "user@example.com", password: "secret")
  |> assert_text("Welcome back!")
  |> click_link("Profile")
  |> assert_text("user@example.com")
  # Session cookies are automatically preserved throughout!
end
```

**How it works:**
- Session cookies from responses are automatically extracted
- Subsequent requests (`visit`, `click_link`, `submit_form`) include these cookies
- This enables proper session-based authentication and CSRF validation

## Automatic Redirect Following

PhoenixHtmldriver automatically follows HTTP redirects, just like a real browser:

```elixir
test "form submission follows redirect", %{conn: conn} do
  session =
    visit(conn, "/login")
    |> submit_form("#login-form", email: "test@example.com", password: "secret")
    # Automatically follows 302 redirect to /dashboard

  assert current_path(session) == "/dashboard"
  assert_text(session, "Welcome back!")
end
```

**Features:**
- Automatically follows 301, 302, 303, 307, and 308 redirects
- Handles redirect chains (up to 5 redirects deep)
- Preserves cookies across redirects
- Works with `visit/2`, `click_link/2`, and `submit_form/3`
- `current_path/1` returns the final destination after all redirects

## CSRF Protection

PhoenixHtmldriver automatically handles CSRF tokens for you! When submitting forms, it:

1. Looks for a hidden `_csrf_token` input field within the form
2. Falls back to a `<meta name="csrf-token">` tag in the document head
3. Automatically includes the token in POST, PUT, PATCH, and DELETE requests
4. Never overrides tokens you explicitly provide
5. **Works seamlessly with session cookies** to ensure tokens validate correctly

This means you can test forms with CSRF protection without any extra setup:

```elixir
test "login with CSRF protection", %{conn: conn} do
  visit(conn, "/login")
  |> submit_form("#login-form", email: "user@example.com", password: "secret")
  |> assert_text("Welcome back!")
  # Both CSRF token AND session cookie were automatically handled!
end
```

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

### Option 1: Using `use PhoenixHtmldriver` (Recommended)

The simplest way - just add `use PhoenixHtmldriver` after setting `@endpoint`:

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase

  @endpoint MyAppWeb.Endpoint  # Must come first!
  use PhoenixHtmldriver

  # No setup needed - conn is automatically configured!

  test "home page", %{conn: conn} do
    visit(conn, "/")
    |> assert_text("Welcome")
  end
end
```

### Option 2: Manual Setup

If you need more control or prefer explicit configuration:

```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  import PhoenixHtmldriver

  setup %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_endpoint, MyAppWeb.Endpoint)
    %{conn: conn}
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
