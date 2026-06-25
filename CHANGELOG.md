## [0.2.4] - 2026-06-25

### Changed
- Testing infrastructure: rubocop, overcommit, bin/setup, gemspec validation, SimpleCov, CI matrix, .minitest config
## [0.2.3] - 2026-06-24

### Added

- `Ask::Result#error?` predicate — symmetrical counterpart to `ok?`
- `Ask::Result#error_message` alias for `error`

### Tests

- Added 5 tests for `error?` and `error_message` on `Ask::Result`

## [0.2.2] - 2026-06-23

### Fixed

- Added `ask-schema` as a runtime dependency in gemspec. The `tool.rb` already
  required `ask-schema` but it wasn't declared, causing `LoadError` for consumers
  installing from Rubygems without local path resolution.

## [0.2.0] - 2026-06-21

### Added

- Gemspec metadata for Rubygems discovery
- CHANGELOG.md included in gem files list

# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-09

### Added

- `Ask::Tool` base class with DSL for declaring `description` and `param`
- Auto-derived tool names from class names (CamelCase → snake_case, strips `_tool`)
- `Ask::Result` value object with `ok?`, `output`, `error`, `metadata` and factory methods `ok(data:)`, `error(message:)`
- JSON Schema generation via `params_schema` and `tool_definition` for LLM function-calling APIs
- `Ask::Tools` module for tool registration, auto-discovery via `ObjectSpace`, and name-based lookup
- `Ask::Tool::Halt` for stopping conversation loops
- `Ask::Tool::Parameter` value object for parameter metadata
- Comprehensive test suite with 54+ tests using Minitest and Mocha

## [0.1.3] - 2026-06-18

### Added

- Class-level `params_schema` method mirroring the instance method. `ToolDef.from_tool`
  calls `tool.params_schema` on the object it receives, which may be a Class (not an
  instance). The instance method existed but there was no class-level equivalent,
  causing `NoMethodError: undefined method 'params_schema' for class` when dynamic
  tool classes were passed directly to `ToolDef.from_tool`.

### Tests

- Added `tool_schema_test.rb` (8 tests, 27 assertions) covering class-level
  `params_schema` for the params DSL, hash schema, empty schema, instance/class
  equivalence, dynamic tool classes, and parameter metadata.
