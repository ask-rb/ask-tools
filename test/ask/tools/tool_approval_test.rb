# frozen_string_literal: true

require_relative "../../test_helper"

module Ask
  class ToolApprovalTest < Minitest::Test
    class ApprovalTool < Ask::Tool
      description "Needs approval"
      approval_required true
      def execute
        Ask::Result.ok(data: "ran")
      end
    end

    class AutoApprovableTool < Ask::Tool
      description "Auto approvable"
      approval_required true
      auto_approvable true
      def execute
        Ask::Result.ok(data: "ran")
      end
    end

    class PlainTool < Ask::Tool
      description "No approval"
      def execute
        Ask::Result.ok(data: "ran")
      end
    end

    # --- class-level DSL ---

    def test_approval_required_defaults_to_false
      refute PlainTool.approval_required
    end

    def test_approval_required_settable
      assert ApprovalTool.approval_required
    end

    def test_approval_required_getter_and_setter
      klass = Class.new(Ask::Tool) do
        approval_required true
      end
      assert_equal true, klass.approval_required
      klass.approval_required false
      assert_equal false, klass.approval_required
    end

    def test_auto_approvable_defaults_to_false
      refute ApprovalTool.auto_approvable
    end

    def test_auto_approvable_settable
      assert AutoApprovableTool.auto_approvable
    end

    # --- instance-level accessors ---

    def test_instance_approval_required
      assert ApprovalTool.new.approval_required?
      refute PlainTool.new.approval_required?
    end

    def test_instance_auto_approvable
      assert AutoApprovableTool.new.auto_approvable?
      refute ApprovalTool.new.auto_approvable?
    end

    # --- inheritance isolation ---

    def test_subclass_does_not_inherit_approval_flag
      subclass = Class.new(ApprovalTool)
      refute subclass.approval_required
    end

    def test_subclass_does_not_inherit_auto_approvable_flag
      subclass = Class.new(AutoApprovableTool)
      refute subclass.auto_approvable
    end

    # --- tools still work normally ---

    def test_approval_required_tool_still_executes
      result = ApprovalTool.new.call
      assert_predicate result, :ok?
      assert_equal "ran", result.output
    end

    def test_tool_definition_unchanged
      defn = ApprovalTool.new.tool_definition
      assert_equal "approval", defn[:name]
      assert_equal "Needs approval", defn[:description]
    end
  end
end
