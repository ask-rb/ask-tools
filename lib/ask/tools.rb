# frozen_string_literal: true

require "monitor"
require_relative "tools/tool"

module Ask
  # Tool registry and discovery.
  #
  # Provides a central registry for tool classes and auto-discovery
  # of Ask::Tool subclasses via ObjectSpace. Thread-safe.
  #
  #   Ask::Tools.register(MyTool)
  #   Ask::Tools.all        # => [MyTool.new, ...]
  #   Ask::Tools["my_tool"] # => instance of MyTool
  #   Ask::Tools.discover   # auto-register all loaded Ask::Tool subclasses
  #
  module Tools
    class << self
      # Register a tool class manually.
      #
      # @param tool_class [Class < Ask::Tool]
      # @return [void]
      def register(tool_class)
        monitor.synchronize { registry[tool_class.name] = tool_class }
      end

      # Return an array of instantiated registered tools.
      #
      # @return [Array<Ask::Tool>]
      def all
        monitor.synchronize { registry.values.map(&:new) }
      end

      # Auto-discover loaded +Ask::Tool+ subclasses via +ObjectSpace+
      # and register any that aren't already registered.
      #
      # @return [Array<Class>] the newly discovered classes
      def discover
        monitor.synchronize do
          discovered = ObjectSpace.each_object(Class).select do |klass|
            klass < Ask::Tool && !registry.value?(klass) && klass.name
          end
          discovered.each { |klass| register(klass) }
          discovered
        end
      end

      # Find a registered tool by its derived name.
      #
      # @param name [String, Symbol] the tool name to look up
      # @return [Ask::Tool, nil] an instance of the matching tool, or nil
      def [](name)
        name_str = name.to_s
        monitor.synchronize do
          registry.each_value do |klass|
            instance = klass.new
            return instance if instance.name == name_str
          end
          nil
        end
      end

      # Remove all registered tools.
      #
      # @return [void]
      def clear
        monitor.synchronize { registry.clear }
      end

      # Number of registered tool classes.
      #
      # @return [Integer]
      def count
        monitor.synchronize { registry.size }
      end

      private

      def registry
        @registry ||= {}
      end

      def monitor
        @monitor ||= Monitor.new
      end
    end
  end
end
