# ask-tools

[![Gem Version](https://badge.fury.io/rb/ask-tools.svg)](https://badge.fury.io/rb/ask-tools)

The tool framework for the ask-rb ecosystem. Defines `Ask::Tool` (the base class every tool inherits from), `Ask::Result` (standardized return value), and the `Ask::Tools` registry. This gem ships no executable tools; tool gems such as ask-tools-shell implement them.

## Installation

```ruby
gem "ask-tools"
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

result = Greeter.new.call(name: "World")
result.ok?      # => true
result.output   # => "Hello, World!"
```

## Essential API

### Ask::Tool

| Method | Purpose |
|---|---|
| `description "..."` (alias `desc`) | Set the tool description |
| `param :name, type: :string, desc: "...", required: true` | Declare a parameter. `type` must be a JSON Schema type (`:string`, `:integer`, `:number`, `:boolean`, `:array`, `:object`) |
| `name "custom_tool"` | Set a custom tool name (default: derived from the class name, CamelCase to snake_case, `_tool` suffix stripped) |
| `params do ... end` | Declare parameters with the ask-schema DSL |

Override `execute(**args)` with the tool logic. `call(args)` normalizes input (JSON strings and hash keys), validates required parameters, and returns an `Ask::Result`. Raising `Ask::Tool::Halt` inside `execute` yields a success result with `metadata[:halted] = true`; any other exception becomes a failure result.

### Ask::Result

```ruby
Ask::Result.ok(data: "output", metadata: { key: "val" })
Ask::Result.error(message: "Something went wrong", metadata: { code: 500 })
Ask::Result.failure("Something went wrong")

result.ok?       # => true
result.output    # => "output"
result.error     # => nil
result.metadata  # => { key: "val" }
result.to_s      # => "output"
result.to_h      # => { ok: true, output: "output", error: nil, metadata: { key: "val" } }
```

### Ask::Tools registry

| Method | Purpose |
|---|---|
| `Ask::Tools.register(ToolClass)` | Register a tool class manually |
| `Ask::Tools.all` | Instances of all registered tools |
| `Ask::Tools.discover` | Auto-register loaded `Ask::Tool` subclasses via ObjectSpace |
| `Ask::Tools["name"]` | Find a tool instance by derived name |
| `Ask::Tools.clear` / `Ask::Tools.count` | Reset and count the registry |

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs. [ask-tools in depth](https://ask-rb.github.io/ask-docs/core/tools) covers the tool contract, parameter schemas, and custom tool examples. API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
