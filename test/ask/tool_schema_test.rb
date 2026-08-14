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
    params(type: "object", properties: { cmd: { type: "string" } }, required: ["cmd"], additionalProperties: false)

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
# The real-model bug: a tool whose execute takes kwargs but declares
  # no params was uncallable ("unknown parameters" for every argument).
  # The schema is now inferred from the signature, and validation names
  # what was expected so the model can correct the call.
  class ImplicitTool < Ask::Tool
    description "Implicit params from the execute signature"
    def execute(project_id:, title:, stage: nil)
      "ok"
    end
  end

  def test_parameters_are_inferred_from_the_execute_signature
    schema = ImplicitTool.new.tool_definition[:input_schema]
    assert_equal %w[project_id title], schema[:required],
      "required kwargs become required schema properties"
    assert_equal %w[project_id stage title], schema[:properties].keys.sort,
      "optional kwargs become optional properties"
  end

  def test_validation_names_what_was_expected
    tool = ImplicitTool.new
    message = tool.validate(project_id: "p1", title: "ok", titile: "typo")
    assert_match(/unknown parameters: :titile/, message)
    assert_match(/expected: :project_id, :title, :stage/, message,
      "the error is actionable — the model repairs instead of guessing")
    assert_nil tool.validate(project_id: "p1", title: "ok", stage: "Backlog")
  end

  def test_schema_validation_applies_to_declared_params_blocks
    tool = ToolWithHashSchema.new
    message = tool.validate(cmd: "ls")
    assert_nil message
    message = tool.validate(cmd: "ls", typo: "ls")
    assert_match(%r{unknown parameters: "typo" — expected: "cmd"}, message)
  end
end
