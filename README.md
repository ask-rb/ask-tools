# ask-tools

The base class every tool in the ask-rb ecosystem inherits from. Zero dependencies.

Provides `Ask::Tool` (base class with `description`, `param`, `name`, `call`, `execute`), `Ask::Result` (standardized return value), and tool discovery/registration.

This gem does NOT ship any executable tools. It only provides the contract.

## Installation

```ruby
gem "ask-tools"
```

## Usage

```ruby
class MyTool < Ask::Tool
  description "Does something useful"
  param :input, type: :string, desc: "The input", required: true

  def execute(input:)
    result = process(input)
    Ask::Result.ok(data: result)
  end
end

MyTool.new.name    # => "my_tool"
MyTool.new.call(input: "hello")
# => #<Ask::Result ok=true output="..." error=nil>
```

## Development

```bash
bin/setup
bundle exec rake test
```

## License

MIT
