# frozen_string_literal: true

require_relative "../test_helper"

class ToolSchemaTest < Minitest::Test
  class ToolWithParams < Ask::Tool
    description "A test tool"
    param :name, type: :string, desc: "A name"
    param :count, type: :integer, desc: "A count", required: false

    def execute(name:, count: 0)
      "ok"
    end
  end

  class ToolWithHashSchema < Ask::Tool
    description "A tool with hash schema"
    params(type: "object", properties: { cmd: { type: "string" } }, required: ["cmd"])

    def execute(cmd:)
      "ran: #{cmd}"
    end
  end

  class ToolWithoutParams < Ask::Tool
    description "A tool without parameters"

    def execute
      "done"
    end
  end

  def test_class_level_params_schema_with_params_dsl
    schema = ToolWithParams.params_schema
    assert_equal "object", schema[:type]
    assert schema[:properties].key?("name")
    assert schema[:properties].key?("count")
    assert_includes schema[:required], "name"
    refute_includes schema[:required], "count"
  end

  def test_class_level_params_schema_with_hash
    schema = ToolWithHashSchema.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("cmd")
    assert_includes schema["required"], "cmd"
  end

  def test_class_level_params_schema_returns_nil_when_no_params
    assert_nil ToolWithoutParams.params_schema
  end

  def test_class_description
    assert_equal "A test tool", ToolWithParams.description
    assert_equal "A tool without parameters", ToolWithoutParams.description
  end

  def test_instance_params_schema_matches_class
    assert_equal ToolWithParams.params_schema, ToolWithParams.new.params_schema
    assert_equal ToolWithHashSchema.params_schema, ToolWithHashSchema.new.params_schema
    assert_nil ToolWithoutParams.new.params_schema
  end

  def test_parameters
    params = ToolWithParams.parameters
    assert params[:name]
    assert_equal "string", params[:name].type
    assert params[:name].required?
    assert params[:count]
    assert_equal "integer", params[:count].type
    refute params[:count].required?
  end

  def test_dynamic_tool_class_instance_works
    klass = Class.new(Ask::Tool) do
      description("dynamic tool")
      define_method(:execute) { |**| "ok" }
    end
    klass.define_method(:name) { "my_tool" }

    instance = klass.new
    assert_equal "my_tool", instance.name
    assert_equal "dynamic tool", instance.description
    assert_nil instance.params_schema
  end

  def test_name_includes_class_path
    # Nested test classes get compound names; this is expected behavior.
    name = ToolWithParams.new.name
    assert name.include?("tool_with_params"), "expected name to include tool_with_params, got #{name}"
  end
end
