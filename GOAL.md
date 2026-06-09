# ask-tools — Tool Framework

## Purpose

The foundational gem for the ask-rb ecosystem. Defines `Ask::Tool` — the base class every tool inherits from — along with `Ask::Result` (standardized return value), tool discovery/registration, and a scaffold generator. Zero external dependencies.

This gem does NOT ship any executable tools. It only provides the contract that tool gems (`ask-tools-shell`, future custom tools) implement.

## Dependencies

- **Runtime:** none (stdlib only)
- **Build/test:** minitest, mocha, rake
- **No other ask-rb gems required.** This is the root of the dependency tree.

## Implementation Steps

### 1. Define the gem scaffold
- Create `lib/ask-tools.rb` — the entry point
- Create `lib/ask/tools.rb` — module with `register`, `all`, `discover`
- Create `lib/ask/version.rb`
- Write `ask-tools.gemspec` with zero runtime dependencies

### 2. Build `Ask::Tool` base class (`lib/ask/tools/tool.rb`)
- Class-level DSL: `description(text)`, `param(name, type:, desc:, required:)`
- `name` instance method — auto-derived from class name (snake_case, strip `_tool` suffix)
- `call(args)` — normalize args to symbols, validate required params, call `execute`
- `execute(**args)` — abstract method, subclasses implement
- Schema generation from declared params (produce JSON Schema hash for LLM function calling)
- Error handling: `Ask::Tool::Halt` for stopping conversation, meaningful error messages

### 3. Build `Ask::Result` (`lib/ask/tools/result.rb`)
- Value object with `ok?`, `output`, `error`, `metadata` attributes
- Factory methods: `Ask::Result.ok(data:)`, `Ask::Result.error(message:)`
- Implements `to_s` for display, `to_h` for serialization

### 4. Build tool discovery (`lib/ask/tools.rb`)
- `Ask::Tools.register(tool_class)` — manually register a tool class
- `Ask::Tools.all` — return list of all registered tool instances
- `Ask::Tools.discover` — auto-discover subclasses of `Ask::Tool` via `ObjectSpace` or descendants tracker
- `Ask::Tools.[](name)` — find a tool by name

### 5. Test coverage
- Test `description` and `param` DSL methods
- Test `name` auto-derivation for various class naming conventions
- Test `call` with valid args, missing required args, extra args
- Test `execute` abstract method raises `NotImplementedError`
- Test `Ask::Result` construction, `ok?`, `error`, `to_h`
- Test tool discovery registration lifecycle
- Test schema generation from params produces valid JSON Schema

### 6. README
- Installation instructions
- Quick usage example showing a custom tool definition
- How to define tools, use `Ask::Result`, register custom tools
- Link to contributed tool gems
- Development workflow

### 7. Production hardening
- Thread safety: tool registry should be safe under concurrent access
- Frozen string literals everywhere
- Validate that param types are valid JSON Schema types
- Sensible error messages for common mistakes

## What "Done" Means

- All tests pass with >90% coverage
- A dummy tool can be defined, instantiated, called, and return `Ask::Result`
- Schema generation produces tool definitions that OpenAI/Anthropic accept
- `Ask::Tools.all` returns registered tools
- No runtime dependencies beyond Ruby stdlib
- README documents the full API
