# frozen_string_literal: true

require_relative "../test_helper"

module Ask
  class ToolsTest < Minitest::Test
    class DiscoveredTool < Ask::Tool
      description "Auto-discovered"
      param :x, type: :string, desc: "Input", required: true

      def execute(x:)
        Ask::Result.ok(data: "discovered: #{x}")
      end
    end

    def setup
      Ask::Tools.clear
    end

    def test_register_and_all
      Ask::Tools.register(ToolTest::SimpleGreeter)
      instances = Ask::Tools.all

      assert_equal 1, instances.size
      assert_kind_of Ask::Tool, instances.first
    end

    def test_all_returns_instances
      Ask::Tools.register(ToolTest::SimpleGreeter)
      Ask::Tools.all.each do |instance|
        assert_kind_of Ask::Tool, instance
      end
    end

    def test_find_by_name
      Ask::Tools.register(ToolTest::SimpleGreeter)
      tool = Ask::Tools["simple_greeter"]

      refute_nil tool
      assert_kind_of ToolTest::SimpleGreeter, tool
    end

    def test_find_by_symbol
      Ask::Tools.register(ToolTest::SimpleGreeter)
      assert Ask::Tools[:simple_greeter]
    end

    def test_find_missing_returns_nil
      assert_nil Ask::Tools["nonexistent"]
    end

    def test_discover_adds_new_classes
      _ = DiscoveredTool

      initial_count = Ask::Tools.count
      Ask::Tools.discover
      assert_operator Ask::Tools.count, :>, initial_count
    end

    def test_discover_registers_specific_class
      _ = DiscoveredTool
      Ask::Tools.discover

      # Name is "discovered" because DiscoveredTool strips "_tool" suffix
      tool = Ask::Tools["discovered"]
      refute_nil tool
      assert_kind_of DiscoveredTool, tool
    end

    def test_clear_removes_all
      Ask::Tools.register(ToolTest::SimpleGreeter)
      assert_equal 1, Ask::Tools.count

      Ask::Tools.clear
      assert_equal 0, Ask::Tools.count
    end

    def test_count
      assert_equal 0, Ask::Tools.count
      Ask::Tools.register(ToolTest::SimpleGreeter)
      assert_equal 1, Ask::Tools.count
      Ask::Tools.register(ToolTest::OptionalGreeter)
      assert_equal 2, Ask::Tools.count
    end
  end
end
