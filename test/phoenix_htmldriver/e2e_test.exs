defmodule PhoenixHtmldriver.E2ETest do
  use ExUnit.Case, async: true

  # This test demonstrates how users would actually use PhoenixHtmldriver
  # Each test represents a real-world scenario and serves as documentation

  # Set endpoint first, then use the macro
  @endpoint PhoenixHtmldriver.TestRouter

  use PhoenixHtmldriver
  alias PhoenixHtmldriver.{Assertions, Element, Form, Link, Session}

  describe "Login flow" do
    test "user can log in with form submission", %{conn: conn} do
      # Start by visiting the login form page
      session = visit(conn, "/login-form")

      # Verify we're on the login page
      session
      |> Assertions.assert_text("Login")
      |> Assertions.assert_selector("#login-form")

      # Fill and submit the login form
      session =
        session
        |> Form.new("#login-form")
        |> Form.fill(username: "alice")
        |> Form.submit()

      # Verify successful login
      session
      |> Assertions.assert_text("Logged in as: alice")
      |> Assertions.assert_text("Form was loaded: true")
    end

    test "login with redirect flow", %{conn: conn} do
      # Visit a page with a login form
      session = visit(conn, "/login-form")

      # Submit form that redirects to dashboard
      session =
        session
        |> Form.new("#login-form")
        |> Form.fill(username: "bob")
        |> Form.submit()

      # Note: This uses /do-login which doesn't redirect in our test router
      # But demonstrates the pattern for redirecting login flows
      Assertions.assert_text(session, "Logged in as: bob")
    end
  end

  describe "Navigation flows" do
    test "user can navigate using links", %{conn: conn} do
      # Start at home page
      session = visit(conn, "/home")

      session
      |> Assertions.assert_text("Welcome Home")
      |> Assertions.assert_selector("#about-link")

      # Click the about link
      session =
        session
        |> Link.new("#about-link")
        |> Link.click()

      # Verify navigation to about page
      session
      |> Assertions.assert_text("About Page")
      |> Assertions.refute_selector("#about-link")
    end

    test "user can navigate by link text", %{conn: conn} do
      session = visit(conn, "/home")

      # Click link by its text content
      session =
        session
        |> Link.new("About")
        |> Link.click()

      Assertions.assert_text(session, "About Page")
    end

    test "user can use Session.get for direct navigation", %{conn: conn} do
      session = visit(conn, "/home")

      # Direct navigation using Session.get
      session
      |> Session.get("/about")
      |> Assertions.assert_text("About Page")
    end
  end

  describe "Form handling" do
    test "user can search with GET form", %{conn: conn} do
      # In a real app, there would be a search form
      # Here we demonstrate the pattern
      session = visit(conn, "/")

      # Simulate a search by navigating with params
      session =
        Session.request(session, :get, "/search", %{q: "phoenix"})

      Assertions.assert_text(session, "Search results for: phoenix")
    end

    test "user can submit POST form with data", %{conn: conn} do
      session = visit(conn, "/")

      # Submit a POST request
      session =
        Session.request(session, :post, "/login", %{username: "charlie"})

      Assertions.assert_text(session, "Welcome, charlie!")
    end
  end

  describe "CSRF token handling" do
    test "form automatically includes CSRF token from form field", %{conn: conn} do
      session = visit(conn, "/form-with-csrf")

      # CSRF token should be automatically included
      session =
        session
        |> Form.new("#csrf-form")
        |> Form.fill(message: "Hello")
        |> Form.submit()

      Assertions.assert_text(session, "CSRF valid: Hello")
    end

    @tag :skip
    test "form can extract CSRF from meta tag", %{conn: conn} do
      # Note: This feature is not yet implemented
      # Form module currently only extracts CSRF from hidden form fields
      session = visit(conn, "/form-with-meta-csrf")

      # CSRF should be extracted from meta tag
      session =
        session
        |> Form.new("#meta-csrf-form")
        |> Form.fill(data: "Test data")
        |> Form.submit()

      Assertions.assert_text(session, "Meta CSRF valid: Test data")
    end
  end

  describe "Session and cookie management" do
    test "session cookies are preserved across requests", %{conn: conn} do
      # Visit page that sets session
      session = visit(conn, "/set-session")

      session
      |> Assertions.assert_text("Session set")
      |> Assertions.assert_selector("a[href='/check-session']")

      # Click link to check session
      session =
        session
        |> Link.new("Check Session")
        |> Link.click()

      # Session should be preserved
      Assertions.assert_text(session, "User ID: test_user_123")
    end

    test "cookies are preserved through form submissions", %{conn: conn} do
      # Login sets a session cookie
      session = visit(conn, "/login-form")

      session =
        session
        |> Form.new("#login-form")
        |> Form.fill(username: "dave")
        |> Form.submit()

      # Session should indicate form was loaded (cookie preserved)
      Assertions.assert_text(session, "Form was loaded: true")
    end
  end

  describe "Redirect handling" do
    test "automatically follows redirects", %{conn: conn} do
      # Visit a URL that redirects
      session = visit(conn, "/redirect-source")

      # Should automatically follow redirect
      session
      |> Assertions.assert_text("Redirect Destination")
      |> Assertions.assert_text("You were redirected here")

      # Verify final path
      assert Session.path(session) == "/redirect-destination"
    end

    test "follows redirect chains", %{conn: conn} do
      session = visit(conn, "/redirect-chain-1")

      # Should follow all redirects in chain
      session
      |> Assertions.assert_text("Chain End")
      |> Assertions.assert_text("After 3 redirects")

      assert Session.path(session) == "/redirect-chain-3"
    end

    test "preserves cookies through redirects", %{conn: conn} do
      session = visit(conn, "/redirect-with-cookie")

      # Should preserve cookies set during redirect
      assert session.cookies.cookies != %{}
      assert Session.path(session) == "/home"
    end
  end

  describe "Element inspection" do
    test "user can inspect element attributes", %{conn: conn} do
      session = visit(conn, "/home")

      # Get element and inspect its attributes
      link_element = Element.new(session, "#about-link")

      assert Element.text(link_element) == "About"
      assert Element.attr(link_element, "href") == "/about"
      assert Element.has_attr?(link_element, "href")
      refute Element.has_attr?(link_element, "disabled")
    end

    test "user can extract text from elements", %{conn: conn} do
      session = visit(conn, "/home")

      heading = Element.new(session, "h1")
      assert Element.text(heading) == "Welcome Home"
    end
  end

  describe "Complex workflows" do
    test "complete user journey: browse → search → view results", %{conn: conn} do
      # Start at home
      session =
        conn
        |> visit("/home")
        |> Assertions.assert_text("Welcome Home")

      # Navigate to search
      session =
        session
        |> Session.get("/search")
        |> Assertions.assert_selector("body")

      # Perform search
      session =
        Session.request(session, :get, "/search", %{q: "elixir"})

      # Verify results
      session
      |> Assertions.assert_text("Search results for: elixir")
      |> Assertions.refute_selector(".error")
    end

    test "form submission with validation and assertions", %{conn: conn} do
      session = visit(conn, "/form-with-csrf")

      # Verify form is present
      Assertions.assert_selector(session, "#csrf-form")
      Assertions.assert_selector(session, "input[name='message']")

      # Fill and submit form
      session =
        session
        |> Form.new("#csrf-form")
        |> Form.fill(message: "Integration test")
        |> Form.submit()

      # Verify success
      session
      |> Assertions.assert_text("CSRF valid")
      |> Assertions.assert_text("Integration test")
    end
  end

  describe "Module composition patterns" do
    test "mixing Session, Form, Link, Element, and Assertions", %{conn: conn} do
      # Demonstrates how all modules work together
      session =
        conn
        |> visit("/home")
        |> Assertions.assert_text("Welcome")

      # Extract heading text using Element
      heading = Element.new(session, "h1")
      assert Element.text(heading) == "Welcome Home"

      # Click link using Link
      session =
        session
        |> Link.new("#about-link")
        |> Link.click()

      # Navigate using Session
      session = Session.get(session, "/home")

      # Make assertions using Assertions
      session
      |> Assertions.assert_selector("a")
      |> Assertions.refute_selector(".error")

      # Check current path
      assert Session.path(session) == "/home"
    end

    test "pipeline-style testing", %{conn: conn} do
      # Shows elegant pipeline testing pattern
      conn
      |> visit("/login-form")
      |> Assertions.assert_selector("#login-form")
      |> Form.new("#login-form")
      |> Form.fill(username: "pipeline_user")
      |> Form.submit()
      |> Assertions.assert_text("Logged in as: pipeline_user")
      |> Session.get("/home")
      |> Assertions.assert_text("Welcome Home")
    end
  end

  describe "Documentation examples" do
    test "example from README: login flow", %{conn: conn} do
      # This matches the example from the main documentation
      session = visit(conn, "/login-form")

      session
      |> Form.new("#login-form")
      |> Form.fill(username: "alice")
      |> Form.submit()
      |> Assertions.assert_text("Logged in as: alice")
    end

    test "example: navigation and assertions", %{conn: conn} do
      session =
        conn
        |> visit("/home")
        |> Assertions.assert_text("Welcome Home")
        |> Assertions.assert_selector("#about-link")

      session
      |> Link.new("#about-link")
      |> Link.click()
      |> Assertions.assert_text("About Page")
    end
  end

  describe "Error cases" do
    test "helpful error when form not found", %{conn: conn} do
      session = visit(conn, "/home")

      assert_raise RuntimeError, ~r/Form not found/, fn ->
        Form.new(session, "#non-existent-form")
      end
    end

    test "helpful error when link not found", %{conn: conn} do
      session = visit(conn, "/home")

      assert_raise RuntimeError, ~r/Link not found/, fn ->
        Link.new(session, "#non-existent-link")
      end
    end

    test "helpful error when element not found", %{conn: conn} do
      session = visit(conn, "/home")

      assert_raise RuntimeError, ~r/Element not found/, fn ->
        Element.new(session, "#non-existent-element")
      end
    end
  end
end
