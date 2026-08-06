## [0.6.0] — 2026-08-06

### Added

- **`Ask::Tool.approval_required` — declare that a tool needs human approval.**
  Combined with `Ask::Agent::ApprovalQueue` (ask-agent), calls to the tool are
  queued instead of executed — the agent gets a pending result and continues,
  and the tool only runs after a human approves it. Defaults to false; the
  flag is not inherited by subclasses.

  ```ruby
  class SendEmail < Ask::Tool
    approval_required true
    def execute(to:, body:) ... end
  end
  ```

- **`Ask::Tool.auto_approvable` — declare that a tool may be auto-approved.**
  A per-action verdict only: the session's user-enabled rule is still the
  binding gate (dual signal). A tool that requires approval but is NOT marked
  auto-approvable always queues for human review.

  ```ruby
  class Ping < Ask::Tool
    approval_required true
    auto_approvable true
    def execute ... end
  end
  ```

- Instance predicates `#approval_required?` and `#auto_approvable?`.

## [0.5.0] — 2026-08-03

### Changed

- **`Ask::Result` now comes from ask-core.** The duplicated `Ask::Result`
  definition in this gem is removed; ask-tools depends on ask-core
  (>= 0.9.0), which owns the single result type for the whole ecosystem with
  both the foundational API (`success`/`failure`/`aborted`/`blocked`) and the
  tool API (`ok`/`error`/`output`/`ok?`/`error_message`). Previously the two
  gems' incompatible constructors meant whichever loaded last broke the
  other's factories (`Ask::Result.success` raised `ArgumentError` in any app
  loading both).

  The tool API is unchanged:

  ```ruby
  Ask::Result.ok(data: "hello").output    # => "hello"
  Ask::Result.error(message: "fail").error  # => "fail"
  ```

### Tested

- 71 tests, 159 assertions, 0 failures.

## [0.4.0] — 2026-07-26

### Added

- **`name` class DSL for custom tool names** — tools can now declare a
  custom name with `name "my_tool"` at the class level instead of
  overriding `def name`. The class method safely shadows `Module#name`
  by detecting arguments: `ClassName.name` returns the Ruby class path,
  `name "foo"` sets the tool name. Instance `#name` returns the custom
  name if set, otherwise auto-derives from the class name.

### Removed

- **`Ask::Tools::SubAgent`** — removed in favor of `Ask::Agent::SubAgent`
  in ask-agent v0.18.0. Sub-agent delegation now lives in the agent
  runtime where it can automatically build sessions.

## [0.3.0] — 2026-07-26

### Added

- **`Ask::Tools::SubAgent` — delegate tasks to a specialized sub-agent tool**.
  An `Ask::Tool` subclass that wraps a runner callable. When the LLM calls it,
  the sub-agent runs independently with its own model, tools, and instructions.

  The tool supports per-instance `name:` and `description:` overrides so that
  multiple sub-agents can coexist in the same tool list with distinct identities.

  ```ruby
  search = Ask::Tools::SubAgent.new(
    name: "web_search",
    description: "Search the web for current information",
    runner: ->(task) {
      Ask::Agent::Session.new(model: "gpt-4o-mini", tools: [Search])
        .run(task).to_s
    }
  )
  ```

### Fixed

- **Tool discovery no longer breaks on tools with required constructor args**.
  `Ask::Tools::SubAgent` makes its `runner:` parameter optional so that tool
  discovery (which instantiates via `klass.new`) works without error. An
  unconfigured SubAgent returns a clear error message at call time.

## [0.2.6] — 2026-07-18

### Fixed

- **`Tool#call` filters `_abort_controller` before passing to `execute`** — The internal `_abort_controller` key was being passed as a keyword argument to tool `execute` methods. Tools with explicit keyword arguments (e.g., `def execute(title:, extraction_scope:)`) crashed with `ArgumentError: unknown keyword` because they didn't accept `_abort_controller`. Now filtered before the `execute(**kwargs)` call.

## [0.2.5] — 2026-07-18

### Fixed

- **`Tool#normalize_args` parses JSON string arguments from LLMs** — Tool call arguments arrive as JSON strings from the LLM, but `normalize_args` only handled Hash arguments. JSON strings were silently ignored, returning an empty args hash and causing "missing required parameters" errors. Now parses JSON strings before normalizing keys to symbols.

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
