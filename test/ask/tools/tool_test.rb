# frozen_string_literal: true

require_relative "../../test_helper"

module Ask
  class ToolTest < Minitest::Test
    class SimpleGreeter < Ask::Tool
      description "Greets someone"
      param :name, type: :string, desc: "The name", required: true

      def execute(name:)
        Ask::Result.ok(data: "Hello, #{name}!")
      end
    end

    class OptionalGreeter < Ask::Tool
      description "Greets with optional title"
      param :name, type: :string, desc: "The name", required: true
      param :title, type: :string, desc: "Optional title", required: false

      def execute(name:, title: nil)
        greeting = title ? "Hello, #{title} #{name}!" : "Hello, #{name}!"
        Ask::Result.ok(data: greeting)
      end
    end

    class NumberCruncher < Ask::Tool
      description "Processes numbers"
      param :value, type: :integer, desc: "An integer", required: true
      param :factor, type: :number, desc: "A float factor", required: false

      def execute(value:, factor: 1.0)
        Ask::Result.ok(data: value * factor)
      end
    end

    class ArrayProcessor < Ask::Tool
      description "Processes arrays"
      param :items, type: :array, desc: "List of items", required: true

      def execute(items:)
        Ask::Result.ok(data: items.join(","))
      end
    end

    class FlagToggler < Ask::Tool
      description "Toggles a flag"
      param :enabled, type: :boolean, desc: "Enable?", required: true

      def execute(enabled:)
        Ask::Result.ok(data: enabled.to_s)
      end
    end

    class InlineTool < Ask::Tool
      description "Inline description"
      param :input, type: :string, desc: "Input", required: true

      def execute(input:)
        Ask::Result.ok(data: "processed: #{input}")
      end
    end

    class HaltTool < Ask::Tool
      description "Halts the conversation"
      param :msg, type: :string, desc: "Message", required: true

      def execute(msg:)
        raise Ask::Tool::Halt, msg
      end
    end

    class CrashingTool < Ask::Tool
      description "Crashes on purpose"

      def execute
        raise RuntimeError, "boom"
      end
    end

    class EmptyTool < Ask::Tool
      description "No parameters"

      def execute
        Ask::Result.ok(data: "done")
      end
    end

    # --- Name derivation tests ---

    def test_name_derived_from_class
      assert_equal "simple_greeter", SimpleGreeter.new.name
    end

    def test_name_strips_tool_suffix
      assert_equal "inline", InlineTool.new.name
    end

    def test_name_for_empty_tool
      assert_equal "empty", EmptyTool.new.name
    end

    # --- DSL tests ---

    def test_description
      assert_equal "Greets someone", SimpleGreeter.description
    end

    def test_description_alias_desc
      assert_equal "Greets someone", SimpleGreeter.desc
    end

    def test_parameters_declared
      params = SimpleGreeter.parameters
      assert_equal 1, params.size
      assert params.key?(:name)
    end

    def test_parameter_attributes
      param = SimpleGreeter.parameters[:name]
      assert_equal :name, param.name
      assert_equal "string", param.type
      assert_equal "The name", param.description
      assert_predicate param, :required?
    end

    def test_optional_parameter_not_required
      param = OptionalGreeter.parameters[:title]
      refute_predicate param, :required?
    end

    # --- Call tests ---

    def test_successful_call
      result = SimpleGreeter.new.call(name: "World")
      assert_predicate result, :ok?
      assert_equal "Hello, World!", result.output
    end

    def test_call_with_string_keys
      result = SimpleGreeter.new.call("name" => "World")
      assert_predicate result, :ok?
      assert_equal "Hello, World!", result.output
    end

    def test_missing_required_param
      result = SimpleGreeter.new.call({})
      refute_predicate result, :ok?
      assert_match(/missing required parameter/, result.error)
    end

    def test_nil_args
      result = SimpleGreeter.new.call(nil)
      refute_predicate result, :ok?
      assert_match(/missing required parameter/, result.error)
    end

    def test_unknown_param
      result = SimpleGreeter.new.call(name: "World", extra: "bad")
      refute_predicate result, :ok?
      assert_match(/unknown parameter/, result.error)
    end

    def test_optional_param_not_provided
      result = OptionalGreeter.new.call(name: "Alice")
      assert_predicate result, :ok?
      assert_equal "Hello, Alice!", result.output
    end

    def test_optional_param_provided
      result = OptionalGreeter.new.call(name: "Alice", title: "Dr.")
      assert_predicate result, :ok?
      assert_equal "Hello, Dr. Alice!", result.output
    end

    # --- Parameter type tests ---

    def test_integer_param
      result = NumberCruncher.new.call(value: 5)
      assert_predicate result, :ok?
      assert_equal 5, result.output
    end

    def test_number_param
      result = NumberCruncher.new.call(value: 10, factor: 2.5)
      assert_predicate result, :ok?
      assert_equal 25.0, result.output
    end

    def test_array_param
      result = ArrayProcessor.new.call(items: %w[a b c])
      assert_predicate result, :ok?
      assert_equal "a,b,c", result.output
    end

    def test_boolean_param
      result = FlagToggler.new.call(enabled: true)
      assert_predicate result, :ok?
      assert_equal "true", result.output
    end

    # --- Halt handling ---

    def test_halt_returns_ok_with_halted_metadata
      result = HaltTool.new.call(msg: "Stopping now")
      assert_predicate result, :ok?
      assert_equal "Stopping now", result.output
      assert_equal true, result.metadata[:halted]
    end

    # --- Crash handling ---

    def test_execute_error_returns_error_result
      result = CrashingTool.new.call
      refute_predicate result, :ok?
      assert_match(/CrashingTool raised RuntimeError: boom/, result.error)
    end

    # --- Schema generation ---

    def test_params_schema_generated
      schema = SimpleGreeter.new.params_schema
      refute_nil schema
      assert_equal "object", schema[:type]
      assert schema[:properties].key?("name")
      assert_includes schema[:required], "name"
    end

    def test_params_schema_property_details
      schema = SimpleGreeter.new.params_schema
      prop = schema[:properties]["name"]
      assert_equal "string", prop[:type]
      assert_equal "The name", prop[:description]
    end

    def test_params_schema_for_empty_tool
      assert_nil EmptyTool.new.params_schema
    end

    def test_params_schema_with_optional
      schema = OptionalGreeter.new.params_schema
      assert schema[:properties].key?("title")
      refute_includes schema[:required], "title"
    end

    def test_params_schema_array_has_items
      schema = ArrayProcessor.new.params_schema
      assert_equal "object", schema[:type]
      assert_equal "array", schema[:properties]["items"][:type]
      assert_equal "string", schema[:properties]["items"][:items][:type]
    end

    # --- Tool definition ---

    def test_tool_definition
      defn = SimpleGreeter.new.tool_definition
      assert_equal "simple_greeter", defn[:name]
      assert_equal "Greets someone", defn[:description]
      assert defn[:input_schema]
      assert_equal "object", defn[:input_schema][:type]
    end

    def test_tool_definition_no_schema_when_no_params
      defn = EmptyTool.new.tool_definition
      assert_equal "empty", defn[:name]
      assert_nil defn[:input_schema]
    end

    # --- Execute abstract ---

    def test_execute_raises_not_implemented
      tool = Ask::Tool.new
      assert_raises(NotImplementedError) { tool.execute }
    end

    # --- Invalid param type ---

    def test_invalid_param_type_raises
      error = assert_raises(ArgumentError) do
        Class.new(Ask::Tool) do
          param :bad, type: :binary, desc: "bad"
        end
      end
      assert_match(/invalid type.*:binary/, error.message.downcase)
    end

    # --- Parameter object ---

    def test_parameter_to_h
      param = Ask::Tool::Parameter.new(name: :x, type: "string", description: "desc", required: true)
      hash = param.to_h
      assert_equal :x, hash[:name]
      assert_equal "string", hash[:type]
      assert_equal "desc", hash[:description]
      assert_equal true, hash[:required]
    end

    def test_parameter_default_required
      param = Ask::Tool::Parameter.new(name: :x, type: "string")
      assert_predicate param, :required?
    end

    # --- Halt class ---

    def test_halt_is_standard_error
      halt = Ask::Tool::Halt.new("stop")
      assert_kind_of StandardError, halt
      assert_equal "stop", halt.content
      assert_equal "stop", halt.to_s
    end

    # --- Inspect ---

    def test_tool_inspect
      tool = SimpleGreeter.new
      assert_match(/#<Ask::ToolTest::SimpleGreeter name="simple_greeter">/, tool.inspect)
    end
  end
end
