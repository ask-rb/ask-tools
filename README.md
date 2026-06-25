# ask-tools

The foundational gem for the ask-rb ecosystem. Defines `Ask::Tool` — the base class every tool inherits from — along with `Ask::Result` (standardized return value), tool discovery/registration, and a scaffold generator.

This gem does **not** ship any executable tools. It only provides the contract that tool gems (e.g., `ask-tools-shell`, `ask-tools-filesystem`) implement.

## Installation

Add this line to your `Gemfile`:

```ruby
gem "ask-tools"
```

Or install it directly:

```bash
gem install ask-tools
```

## Quick Start

```ruby
require "ask-tools"

class Greeter < Ask::Tool
  description "Greets a person by name"
  param :name, type: :string, desc: "The person's name", required: true

  def execute(name:)
    Ask::Result.ok(data: "Hello, #{name}!")
  end
end

# Use it
tool = Greeter.new
tool.name          # => "greeter"
tool.description   # => "Greets a person by name"

result = tool.call(name: "World")
result.ok?         # => true
result.output      # => "Hello, World!"
```

## API Reference

### `Ask::Tool` — Base Class

Subclass `Ask::Tool` to define a tool that an LLM can call.

#### Class DSL

| Method | Description |
|--------|-------------|
| `description(text)` | Sets or retrieves the tool's human-readable description. Alias: `desc` |
| `param(name, type:, desc:, required:)` | Declares a parameter. `type` must be a valid JSON Schema type (`:string`, `:integer`, `:number`, `:boolean`, `:array`, `:object`) |

#### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `name` | `String` | Auto-derived from the class name: CamelCase → snake_case, strips `_tool` suffix |
| `description` | `String?, nil` | The tool's description |
| `parameters` | `Hash{Symbol => Parameter}` | Declared parameter definitions |
| `call(args = {})` | `Ask::Result` | Normalizes args (symbolizes keys), validates required params, delegates to `execute`. Catches `Halt` and `StandardError` |
| `execute(**args)` | `Ask::Result` | **Override this.** Implement the tool's logic. |
| `params_schema` | `Hash?, nil` | JSON Schema hash for LLM function-calling APIs. Returns `nil` when no params declared |
| `tool_definition` | `Hash` | Full tool definition hash with `:name`, `:description`, and `:input_schema` |

#### Error Handling

- **`Ask::Tool::Halt`** — Raise this inside `execute` to signal the conversation loop should stop after this tool's result. `call` returns an `Ask::Result` with `metadata[:halted] = true`.
- **`StandardError`** — Any other exception raised in `execute` is caught by `call` and returned as an error `Ask::Result`.

### `Ask::Result` — Return Value

A value object representing the outcome of a tool execution.

#### Factory Methods

```ruby
# Successful result
Ask::Result.ok(data: "output", metadata: { key: "val" })

# Failed result
Ask::Result.error(message: "Something went wrong", metadata: { code: 500 })
```

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `ok?` / `ok` | `Boolean` | Whether the tool completed successfully |
| `output` | `Object?, nil` | Output data (success) |
| `error` | `String?, nil` | Error message (failure) |
| `metadata` | `Hash` | Arbitrary metadata |

#### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `to_s` | `String` | Returns `output.to_s` for success, `error` for failure |
| `to_h` | `Hash` | Serialized hash with `:ok`, `:output`, `:error`, `:metadata` |
| `inspect` | `String` | Human-readable representation |

### `Ask::Tool::Parameter` — Parameter Definition

Internal value object describing a declared parameter. Accessible via `Tool.parameters[name]`.

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | `Symbol` | Parameter name |
| `type` | `String` | JSON Schema type string |
| `description` | `String?, nil` | Human-readable description |
| `required` / `required?` | `Boolean` | Whether the parameter is mandatory |

### `Ask::Tools` — Registry & Discovery

Central registry for tool classes.

| Method | Returns | Description |
|--------|---------|-------------|
| `.register(tool_class)` | `void` | Manually register a tool class |
| `.all` | `Array<Tool>` | Instantiated list of all registered tools |
| `.discover` | `Array<Class>` | Auto-discover loaded `Ask::Tool` subclasses via `ObjectSpace` |
| `.[](name)` | `Tool?, nil` | Find a registered tool by its derived name |
| `.clear` | `void` | Remove all registered tools |
| `.count` | `Integer` | Number of registered tool classes |

```ruby
# Manual registration
Ask::Tools.register(MyTool)

# Auto-discover all loaded Ask::Tool subclasses
Ask::Tools.discover

# Find by name
tool = Ask::Tools["my_tool"]
tool.call(input: "hello")

# List all
Ask::Tools.all.each { |t| puts t.name }
```

## Defining a Custom Tool

```ruby
class SearchTool < Ask::Tool
  description "Searches a knowledge base"
  param :query, type: :string, desc: "Search query", required: true
  param :limit, type: :integer, desc: "Max results", required: false

  def execute(query:, limit: 10)
    results = perform_search(query, limit)
    Ask::Result.ok(data: results)
  rescue SearchError => e
    Ask::Result.error(message: e.message)
  end

  private

  def perform_search(query, limit)
    # ... implementation
  end
end
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Build the gem
gem build ask-tools.gemspec
```

## Testing

ask-tools uses **Minitest** with **Mocha** for mocking.

```bash
# Run the full test suite
bundle exec rake test
```

## Release Process

1. Update `CHANGELOG.md`
2. Update `lib/ask/version.rb` if needed
3. Build the gem: `gem build ask-tools.gemspec`
4. Push to GitHub Packages: `gem push ask-tools-*.gem`

## License

MIT — see [LICENSE](LICENSE).

## Links

- **Source:** https://github.com/ask-rb/ask-tools
- **Issues:** https://github.com/ask-rb/ask-tools/issues
- **Docs:** https://github.com/ask-rb/ask-docs
