# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2025-01-14

### Added
- Cookie preservation when calling `visit/2` with a Session struct ([#6](https://github.com/ppdx999/phoenix-htmldriver/issues/6))
  - `visit(session, path)` now preserves cookies from previous requests
  - `visit(conn, path)` continues to start fresh without cookies
  - Enables testing of authenticated flows across multiple page visits
  - Brings `visit/2` behavior in line with `click_link/2` and `submit_form/3`
- Added 3 new tests for visit/2 cookie preservation (total: 87 tests)

### Changed
- `visit/2` now has two function clauses for different input types
- Updated `@spec` for `visit/2` to accept both `t()` and `Plug.Conn.t()`
- Enhanced documentation with examples showing both usage modes

### Fixed
- Fixed issue where `visit/2` did not preserve session cookies, breaking authentication flows ([#6](https://github.com/ppdx999/phoenix-htmldriver/issues/6))
- Session cookies are now consistently preserved across all navigation functions

## [0.6.0] - 2025-01-11

### Added
- Automatic redirect following for all navigation actions ([#5](https://github.com/ppdx999/phoenix-htmldriver/issues/5))
  - `visit/2`, `click_link/2`, and `submit_form/3` now automatically follow redirects
  - Supports all redirect status codes (301, 302, 303, 307, 308)
  - Follows redirect chains up to 5 redirects deep
  - Preserves cookies across redirects
  - Matches real browser behavior
- Added 5 new tests for redirect following (total: 84 tests)
- Added comprehensive documentation about redirect following in README

### Changed
- All navigation functions now automatically follow HTTP redirects
- `current_path/1` returns the final destination path after redirects

### Fixed
- Fixed issue where redirected responses showed original request path instead of final destination ([#5](https://github.com/ppdx999/phoenix-htmldriver/issues/5))
- Enabled testing of login flows and other redirect-based actions

## [0.5.0] - 2025-01-11

### Added
- Proper `fill_form/3` implementation that stores values ([#4](https://github.com/ppdx999/phoenix-htmldriver/issues/4))
  - `fill_form/3` now stores form values in the session
  - Values are automatically included when `submit_form/3` is called
  - Supports both keyword lists and nested maps
  - Values provided directly to `submit_form/3` override `fill_form/3` values
- Added 4 new tests for fill_form/submit_form integration (total: 79 tests)
- Enhanced documentation for `fill_form/3` with examples and multiple usage patterns

### Changed
- Added `:form_values` field to Session struct to store form data
- `fill_form/3` now validates that the form exists and raises if not found
- Updated README with comprehensive form filling examples

### Fixed
- Fixed critical bug where `fill_form/3` values were not included in form submission ([#4](https://github.com/ppdx999/phoenix-htmldriver/issues/4))
- Library is now usable for its primary purpose of form testing

## [0.4.0] - 2025-01-11

### Added
- Session cookie preservation across requests ([#3](https://github.com/ppdx999/phoenix-htmldriver/issues/3))
  - Session cookies are now automatically preserved across `visit`, `click_link`, and `submit_form` calls
  - Added `:cookies` field to Session struct to store cookies
  - Automatically extracts cookies from responses and includes them in subsequent requests
  - Properly handles `secret_key_base` for session cookie encryption
- Added 4 new tests for session cookie preservation (total: 76 tests)
- Added comprehensive documentation about session and cookie handling in README

### Changed
- Updated Session struct to include `:cookies` field
- Modified all request functions to preserve and restore cookies
- Enhanced Session module documentation

### Fixed
- Fixed session cookie loss between requests that prevented CSRF validation ([#3](https://github.com/ppdx999/phoenix-htmldriver/issues/3))
- Enabled testing of real Phoenix applications with session-based CSRF protection

## [0.3.0] - 2025-01-11

### Added
- Automatic CSRF token extraction and submission ([#2](https://github.com/ppdx999/phoenix-htmldriver/issues/2))
  - `submit_form/3` now automatically extracts CSRF tokens from forms
  - Looks for `_csrf_token` hidden input field first
  - Falls back to `<meta name="csrf-token">` tag if not found in form
  - Automatically includes token for POST, PUT, PATCH, and DELETE requests
  - User-provided tokens are never overridden
- Added 5 new tests for CSRF token handling (total: 72 tests)
- Added comprehensive documentation about CSRF protection in README

### Changed
- Enhanced `submit_form/3` function in `Session` module with CSRF token extraction
- Updated README with CSRF protection section and examples

### Fixed
- Fixed CSRF protection errors when submitting forms ([#2](https://github.com/ppdx999/phoenix-htmldriver/issues/2))

## [0.2.0] - 2025-01-11

### Added
- `use PhoenixHtmldriver` macro for automatic endpoint configuration ([#1](https://github.com/ppdx999/phoenix-htmldriver/issues/1))
  - Automatically captures `@endpoint` module attribute at compile time
  - Provides `conn` with endpoint configured in setup block
  - Eliminates need for manual endpoint setup in most cases
  - Three usage modes: create conn, add endpoint to existing conn, or use existing conn as-is
- Comprehensive test suite with 67 tests and 95.77% code coverage
  - Added `test/phoenix_htmldriver/use_macro_test.exs` for macro testing
  - Added `test/phoenix_htmldriver/element_test.exs` for Element module
  - Added `test/phoenix_htmldriver/session_test.exs` for Session module

### Changed
- Updated README with recommended usage pattern using `use PhoenixHtmldriver`
- Improved documentation with examples for both automatic and manual configuration
- Added important note about `@endpoint` ordering requirement

### Fixed
- Fixed endpoint configuration issue when using `Phoenix.ConnTest.build_conn/0` ([#1](https://github.com/ppdx999/phoenix-htmldriver/issues/1))

## [0.1.0] - 2025-01-11

### Added
- Initial release of PhoenixHtmldriver
- Core session-based API for testing Phoenix HTML
- `visit/2` - Navigate to a path and create a session
- `click_link/2` - Click links by selector or text
- `fill_form/3` and `submit_form/3` - Form interaction
- `assert_text/2`, `assert_selector/2`, `refute_selector/2` - Assertions
- `find/2` and `find_all/2` - Element finding
- `current_path/1` and `current_html/1` - Session inspection
- Element module with `text/1`, `attr/2`, and `has_attr?/2`
- Integration with Phoenix.ConnTest and Plug.Test
- Floki-based HTML parsing
- Support for all HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Comprehensive documentation and README

[0.7.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ppdx999/phoenix-htmldriver/releases/tag/v0.1.0
