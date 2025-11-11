# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.2.0]: https://github.com/ppdx999/phoenix-htmldriver/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ppdx999/phoenix-htmldriver/releases/tag/v0.1.0
