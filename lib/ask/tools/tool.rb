# frozen_string_literal: true

require "json"
require "ask-schema"

module Ask
  class Tool
    class Halt < StandardError
      attr_reader :content
      def initialize(content)
        @content = content
        super(content.to_s)
      end
    end

    class << self
      def inherited(subclass)
        super
        @parameters = {} if @parameters.nil?
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@parameters, {})
        subclass.instance_variable_set(:@params_schema_definition, nil)
        subclass.instance_variable_set(:@tool_name, nil)
        subclass.instance_variable_set(:@approval_required, nil)
        subclass.instance_variable_set(:@auto_approvable, nil)
      end

      def description(text = nil)
        return @description unless text
        @description = text
      end
      alias desc description

      # Declare a custom tool name.
      # Called with no argument returns the class name (via Module#name).
      # Called with a string stores a custom name for the instance.
      # Example: name "my_custom_tool"
      def name(custom = :_no_arg_given)
        if custom == :_no_arg_given
          super()  # Module#name, returns the Ruby class path
        else
          @tool_name = custom
        end
      end

      # Declare that calling this tool requires human approval.
      #
      # The tool is still registered and described to the LLM normally, but
      # when an agent session runs with an approval queue enabled, calls to
      # it are queued instead of executed — the agent gets a pending result,
      # and the tool only runs after a human approves it.
      #
      # Called with no argument returns the current value (default false).
      #
      # @example
      #   class SendEmail < Ask::Tool
      #     approval_required true
      #     def execute(to:, body:) ... end
      #   end
      #
      # @param value [Boolean, nil]
      # @return [Boolean]
      def approval_required(value = :_no_arg_given)
        if value == :_no_arg_given
          @approval_required == true
        else
          @approval_required = !!value
        end
      end

      # Declare that this tool may be auto-approved when the session's
      # approval policy has auto-approval enabled for it. This is a
      # per-action verdict only — the session-level user rule is still the
      # binding gate. A tool that requires approval but is NOT marked
      # auto-approvable always queues for human review.
      #
      # Called with no argument returns the current value (default false).
      #
      # @param value [Boolean, nil]
      # @return [Boolean]
      def auto_approvable(value = :_no_arg_given)
        if value == :_no_arg_given
          @auto_approvable == true
        else
          @auto_approvable = !!value
        end
      end

      def param(name, type:, desc: nil, description: nil, required: true)
        type = type.to_s.downcase.to_sym
        validate_param_type!(type, name)
        parameters[name] = Parameter.new(
          name: name, type: map_type(type),
          description: desc || description, required: required
        )
      end

      def params(schema = nil, &block)
        @params_schema_definition = schema || block
      end

      # The tool's declared parameters — or, when none are declared,
      # inferred from the execute signature so a tool is never silently
      # uncallable: a tool whose execute takes keyword arguments but
      # declares no params would otherwise reject every call ("unknown
      # parameters"). Inference is a fallback, never an override: an
      # explicit `params`/`param` declaration wins.
      def parameters
        @parameters ||= {}
        if @parameters.empty? && @params_schema_definition.nil? && !@parameters_inferred
          infer_parameters_from_execute
        end
        @parameters
      end

      # Derive parameters from `def execute(project_id:, title:, ...)`:
      # required keywords become required string parameters. Ruby types
      # aren't introspectable, so everything infers as string (JSON
      # numbers coerce); tools that need real types declare `params`.
      def infer_parameters_from_execute
        @parameters_inferred = true
        instance_method(:execute).parameters.each do |kind, name|
          next unless %i[keyreq key opt].include?(kind)
          next if name.nil? || name == :_abort_controller

          @parameters[name] = Parameter.new(name: name, type: "string", required: kind == :keyreq)
        end
      end

      def provider_params
        @provider_params ||= {}
      end

      def params_schema
        @params_schema ||= begin
          if @params_schema_definition
            deep_stringify_keys(resolve_params_schema(@params_schema_definition))
          elsif parameters.any?
            build_schema_from_params
          else
            nil
          end
        end
      end

      def build_schema_from_params
        properties = parameters.to_h do |_name, param|
          schema = { type: param.type }
          schema[:description] = param.description if param.description
          schema[:items] = { type: "string" } if param.type == "array"
          [param.name.to_s, schema]
        end
        required = parameters.select { |_, p| p.required }.keys.map(&:to_s)
        { type: "object", properties: properties, required: required, additionalProperties: false }
      end

      def resolve_params_schema(definition)
        case definition
        when Proc
          schema_class = Ask::Schema.create(&definition)
          schema_class.new.to_json_schema.dig(:schema)
        when Hash then definition
        when ->(d) { d.respond_to?(:to_json_schema) }
          definition.to_json_schema.dig(:schema)
        else nil
        end
      end

      def deep_stringify_keys(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify_keys(v) }
        when Array then obj.map { |v| deep_stringify_keys(v) }
        else obj
        end
      end

      private

      def validate_param_type!(type, name)
        return if VALID_JSON_SCHEMA_TYPES.include?(type)
        raise ArgumentError,
          "Invalid type #{type.inspect} for parameter #{name.inspect}. " \
          "Valid types: #{VALID_JSON_SCHEMA_TYPES.map(&:inspect).join(', ')}"
      end

      def map_type(type)
        case type
        when :int then "integer"
        when :float, :double then "number"
        else type.to_s
        end
      end
    end

    def provider_params
      self.class.provider_params
    end

    def name
      custom = self.class.instance_variable_get(:@tool_name)
      return custom if custom

      klass_name = self.class.name.to_s.split("::").last || ""
      normalized = klass_name.dup.force_encoding("UTF-8").unicode_normalize(:nfkd)
      normalized.encode("ASCII", replace: "")
                .gsub(/[^a-zA-Z0-9_-]/, "-")
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .delete_suffix("_tool")
    end

    def description
      self.class.description
    end

    def parameters
      self.class.parameters
    end

    # @return [Boolean] whether calling this tool requires human approval
    def approval_required?
      self.class.approval_required
    end

    # @return [Boolean] whether this tool may be auto-approved under a
    #   session-level auto-approval rule
    def auto_approvable?
      self.class.auto_approvable
    end

      def call(args = {}, abort_controller = nil)
      normalized = normalize_args(args)
      validation = validate(normalized)
      return Ask::Result.failure(validation) if validation
      normalized[:_abort_controller] = abort_controller if abort_controller
      execute_kwargs = normalized.reject { |k, _| k == :_abort_controller || k == :abort_controller }
      execute(**execute_kwargs)
      rescue Halt => e
        Ask::Result.ok(data: e.content, metadata: { halted: true })
      rescue StandardError => e
        Ask::Result.failure("#{self.class.name.split('::').last} raised #{e.class}: #{e.message}")
      end

      def execute(**args)
        raise NotImplementedError, "#{self.class} must implement #execute(**args)"
      end

    def params_schema
      return @params_schema if defined?(@params_schema)
      @params_schema = begin
        if params_schema_definition
          deep_stringify_keys(resolve_params_schema(params_schema_definition))
        elsif parameters.any?
          build_schema_from_params
        else
          nil
        end
      end
    end

    def tool_definition
      defn = { name: name, description: description }
      defn[:input_schema] = params_schema if params_schema
      defn
    end

    def inspect
      "#<#{self.class.name} name=#{name.inspect}>"
    end

    # Validate normalized (symbol-keyed) arguments. Returns nil when
    # valid, or an actionable message — one that names what was expected
    # — so the model (or a repair pass) can correct the call instead of
    # guessing. Public: ask-agent's tool-call repair validates through
    # this. Tools with a declared `params` block validate against the
    # resolved schema (required keys + unknown keys when strict).
    def validate(normalized)
      return validate_against_schema(normalized) if params_schema_definition

      expected = self.class.parameters.keys
      missing = expected.select { |name| self.class.parameters[name].required && !normalized.key?(name) }
      return "missing required parameters: #{missing.map(&:inspect).join(', ')} — expected: #{expected.map(&:inspect).join(', ')}" unless missing.empty?

      unknown = normalized.keys - expected
      return "unknown parameters: #{unknown.map(&:inspect).join(', ')} — expected: #{expected.map(&:inspect).join(', ')}" unless unknown.empty?

      nil
    end

    private

    def validate_against_schema(normalized)
      schema = params_schema || {}
      expected = Array(schema["required"]).map(&:to_s) # block-form schemas carry symbols here
      missing = expected - normalized.keys.map(&:to_s)
      return "missing required parameters: #{missing.map(&:inspect).join(', ')} — expected: #{expected.map(&:inspect).join(', ')}" unless missing.empty?

      properties = schema["properties"] || {}
      if schema["additionalProperties"] == false
        unknown = normalized.keys.map(&:to_s) - properties.keys
        return "unknown parameters: #{unknown.map(&:inspect).join(', ')} — expected: #{properties.keys.map(&:inspect).join(', ')}" unless unknown.empty?
      end

      nil
    end

    def params_schema_definition
      self.class.instance_variable_get(:@params_schema_definition)
    end

    def resolve_params_schema(definition)
      case definition
      when Proc
        schema_class = Ask::Schema.create(&definition)
        schema_class.new.to_json_schema.dig(:schema)
      when Hash then definition
      when ->(d) { d.respond_to?(:to_json_schema) }
        definition.to_json_schema.dig(:schema)
      else nil
      end
    end

    def build_schema_from_params
      properties = parameters.to_h do |_name, param|
        schema = { type: param.type }
        schema[:description] = param.description if param.description
        schema[:items] = { type: "string" } if param.type == "array"
        [param.name.to_s, schema]
      end
      required = parameters.select { |_, p| p.required }.keys.map(&:to_s)
      { type: "object", properties: properties, required: required, additionalProperties: false }
    end

    def deep_stringify_keys(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify_keys(v) }
      when Array then obj.map { |v| deep_stringify_keys(v) }
      else obj
      end
    end

    def normalize_args(args)
      return {} if args.nil?
      return {} if args.respond_to?(:empty?) && args.empty?

      # Parse JSON strings sent by LLMs (tool call arguments arrive as JSON)
      if args.is_a?(String)
        args = JSON.parse(args) rescue (return {})
      end

      args.respond_to?(:transform_keys) ? args.transform_keys(&:to_sym) : {}
    end

    VALID_JSON_SCHEMA_TYPES = %i[string integer number boolean array object].freeze

    class Parameter
      attr_reader :name, :type, :description, :required
      alias required? required
      def initialize(name:, type:, description: nil, required: true)
        @name = name; @type = type; @description = description; @required = required
      end
      def to_h
        { name: name, type: type, description: description, required: required }
      end
    end
  end
end
