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
- Zero runtime dependencies — stdlib only
