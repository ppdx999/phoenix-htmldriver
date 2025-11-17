defmodule PhoenixHtmldriver.FormTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.{Form, Session}

  @endpoint PhoenixHtmldriver.TestRouter

  defp build_session_with_form(html) do
    # Create a mock session with the given HTML
    conn = Plug.Test.conn(:get, "/")
    |> put_in([Access.key!(:secret_key_base)], @endpoint.config(:secret_key_base))

    {:ok, document} = Floki.parse_document(html)

    %Session{
      conn: conn,
      document: document,
      response: %Plug.Conn{conn | status: 200, resp_body: html, request_path: "/test"},
      endpoint: @endpoint,
      cookies: %{},
      path: "/test"
    }
  end

  describe "new/2" do
    test "finds form by selector and parses values" do
      html = """
      <form id="login-form" action="/login" method="post">
        <input type="text" name="username" value="alice" />
        <input type="password" name="password" value="" />
        <input type="hidden" name="_csrf_token" value="secret123" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#login-form")

      assert form.values == %{
        "username" => "alice",
        "password" => "",
        "_csrf_token" => "secret123"
      }
      assert form.endpoint == @endpoint
      assert form.cookies == %{}
      assert form.path == "/test"
    end

    test "raises when form not found" do
      html = "<div>No form here</div>"
      session = build_session_with_form(html)

      assert_raise RuntimeError, "Form not found: #missing-form", fn ->
        Form.new(session, "#missing-form")
      end
    end

    test "parses checkbox values - checked" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="terms" value="accepted" checked />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"terms" => "accepted"}
    end

    test "parses checkbox values - unchecked" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="terms" value="accepted" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{}
    end

    test "parses checkbox with default 'on' value when checked" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="agree" checked />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"agree" => "on"}
    end

    test "parses radio buttons - selected" do
      html = """
      <form id="test-form">
        <input type="radio" name="color" value="red" />
        <input type="radio" name="color" value="blue" checked />
        <input type="radio" name="color" value="green" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"color" => "blue"}
    end

    test "parses radio buttons - none selected" do
      html = """
      <form id="test-form">
        <input type="radio" name="color" value="red" />
        <input type="radio" name="color" value="blue" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{}
    end

    test "parses select with selected option" do
      html = """
      <form id="test-form">
        <select name="country">
          <option value="us">United States</option>
          <option value="jp" selected>Japan</option>
          <option value="uk">United Kingdom</option>
        </select>
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"country" => "jp"}
    end

    test "parses select with first option as default" do
      html = """
      <form id="test-form">
        <select name="country">
          <option value="us">United States</option>
          <option value="jp">Japan</option>
        </select>
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"country" => "us"}
    end

    test "parses select with option text as value when no value attribute" do
      html = """
      <form id="test-form">
        <select name="language">
          <option selected>English</option>
          <option>Japanese</option>
        </select>
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"language" => "English"}
    end

    test "parses textarea" do
      html = """
      <form id="test-form">
        <textarea name="bio">Hello world</textarea>
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"bio" => "Hello world"}
    end

    test "ignores inputs without name attribute" do
      html = """
      <form id="test-form">
        <input type="text" value="no name" />
        <input type="text" name="with_name" value="has name" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"with_name" => "has name"}
    end

    test "ignores submit, button, file, reset, image inputs" do
      html = """
      <form id="test-form">
        <input type="submit" name="submit" value="Submit" />
        <input type="button" name="button" value="Click" />
        <input type="file" name="upload" />
        <input type="reset" name="reset" value="Reset" />
        <input type="image" name="image" src="button.png" />
        <input type="text" name="name" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"name" => "alice"}
    end

    test "supports HTML5 input types - text-based inputs" do
      html = """
      <form id="test-form">
        <input type="text" name="text" value="text value" />
        <input type="email" name="email" value="test@example.com" />
        <input type="password" name="password" value="secret" />
        <input type="search" name="search" value="search query" />
        <input type="tel" name="phone" value="123-456-7890" />
        <input type="url" name="website" value="https://example.com" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{
        "text" => "text value",
        "email" => "test@example.com",
        "password" => "secret",
        "search" => "search query",
        "phone" => "123-456-7890",
        "website" => "https://example.com"
      }
    end

    test "supports HTML5 input types - number inputs" do
      html = """
      <form id="test-form">
        <input type="number" name="age" value="25" />
        <input type="range" name="volume" value="50" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{
        "age" => "25",
        "volume" => "50"
      }
    end

    test "supports HTML5 input types - date and time inputs" do
      html = """
      <form id="test-form">
        <input type="date" name="birthday" value="2000-01-01" />
        <input type="time" name="alarm" value="09:00" />
        <input type="datetime-local" name="appointment" value="2024-01-01T09:00" />
        <input type="month" name="month" value="2024-01" />
        <input type="week" name="week" value="2024-W01" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{
        "birthday" => "2000-01-01",
        "alarm" => "09:00",
        "appointment" => "2024-01-01T09:00",
        "month" => "2024-01",
        "week" => "2024-W01"
      }
    end

    test "supports HTML5 input types - color input" do
      html = """
      <form id="test-form">
        <input type="color" name="favorite_color" value="#ff0000" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{"favorite_color" => "#ff0000"}
    end

    test "supports HTML5 input types - hidden input" do
      html = """
      <form id="test-form">
        <input type="hidden" name="_csrf_token" value="secret123" />
        <input type="text" name="username" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert form.values == %{
        "_csrf_token" => "secret123",
        "username" => "alice"
      }
    end
  end

  describe "fill/2" do
    test "fills form fields with map" do
      html = """
      <form id="test-form">
        <input type="text" name="username" value="" />
        <input type="password" name="password" value="" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(%{"username" => "alice", "password" => "secret"})

      assert form.values == %{
        "username" => "alice",
        "password" => "secret"
      }
    end

    test "fills form fields with keyword list" do
      html = """
      <form id="test-form">
        <input type="text" name="username" value="" />
        <input type="password" name="password" value="" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(username: "alice", password: "secret")

      assert form.values == %{
        "username" => "alice",
        "password" => "secret"
      }
    end

    test "normalizes atom keys to strings" do
      html = """
      <form id="test-form">
        <input type="text" name="email" value="" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(email: "test@example.com")

      assert form.values == %{"email" => "test@example.com"}
    end

    test "merges new values with existing values" do
      html = """
      <form id="test-form">
        <input type="text" name="username" value="alice" />
        <input type="password" name="password" value="" />
        <input type="hidden" name="_csrf_token" value="token123" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(%{"password" => "secret"})

      assert form.values == %{
        "username" => "alice",
        "password" => "secret",
        "_csrf_token" => "token123"
      }
    end

    test "multiple fills accumulate values" do
      html = """
      <form id="test-form">
        <input type="text" name="first_name" value="" />
        <input type="text" name="last_name" value="" />
        <input type="email" name="email" value="" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(first_name: "Alice")
      |> Form.fill(last_name: "Smith")
      |> Form.fill(email: "alice@example.com")

      assert form.values == %{
        "first_name" => "Alice",
        "last_name" => "Smith",
        "email" => "alice@example.com"
      }
    end

    test "overwrites previous values" do
      html = """
      <form id="test-form">
        <input type="text" name="username" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(username: "bob")
      |> Form.fill(username: "charlie")

      assert form.values == %{"username" => "charlie"}
    end
  end

  describe "uncheck/2" do
    test "removes field from values with string key" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="terms" value="accepted" checked />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.uncheck("terms")

      assert form.values == %{}
    end

    test "removes field from values with atom key" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="newsletter" value="yes" checked />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.uncheck(:newsletter)

      assert form.values == %{}
    end

    test "works with filled checkboxes" do
      html = """
      <form id="test-form">
        <input type="checkbox" name="agree" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.fill(agree: "on")
      |> Form.uncheck(:agree)

      assert form.values == %{}
    end

    test "does nothing if field doesn't exist" do
      html = """
      <form id="test-form">
        <input type="text" name="username" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")
      |> Form.uncheck("nonexistent")

      assert form.values == %{"username" => "alice"}
    end
  end

  describe "submit/1" do
    test "validates form method - only GET and POST allowed" do
      html = """
      <form id="test-form" action="/users" method="put">
        <input type="text" name="name" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert_raise ArgumentError, ~r/Invalid form method: 'put'/, fn ->
        Form.submit(form)
      end
    end

    test "error message explains method override pattern" do
      html = """
      <form id="test-form" action="/users" method="delete">
        <input type="text" name="name" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      assert_raise ArgumentError, ~r/use method override/, fn ->
        Form.submit(form)
      end
    end

    test "accepts GET method (case insensitive)" do
      html = """
      <form id="test-form" action="/search" method="GET">
        <input type="text" name="q" value="test" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      # Should not raise
      result = Form.submit(form)
      assert %Session{} = result
    end

    test "accepts POST method (case insensitive)" do
      html = """
      <form id="test-form" action="/login" method="POST">
        <input type="text" name="username" value="alice" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      # Should not raise
      result = Form.submit(form)
      assert %Session{} = result
    end

    test "defaults to GET when method not specified" do
      html = """
      <form id="test-form" action="/search">
        <input type="text" name="q" value="test" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      # Should not raise (defaults to GET)
      result = Form.submit(form)
      assert %Session{} = result
    end

    test "uses current path when action not specified" do
      html = """
      <form id="test-form" method="post">
        <input type="text" name="data" value="test" />
      </form>
      """

      session = build_session_with_form(html)
      form = Form.new(session, "#test-form")

      result = Form.submit(form)
      assert %Session{} = result
    end
  end
end
