# frozen_string_literal: true

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
      end

      def description(text = nil)
        return @description unless text
        @description = text
      end
      alias desc description

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

      def parameters
        @parameters ||= {}
      end

      def provider_params
        @provider_params ||= {}
      end

      def params_schema
        @params_schema ||= begin
          if @params_schema_definition
            deep_stringify_keys(resolve_params_schema(@params_schema_definition))
          elsif @parameters && @parameters.any?
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

      def call(args = {}, abort_controller = nil)
      normalized = normalize_args(args)
      validation = validate(normalized)
      return Ask::Result.failure(validation) if validation
      normalized[:_abort_controller] = abort_controller if abort_controller
      execute(**normalized)
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

    private

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
      args.respond_to?(:transform_keys) ? args.transform_keys(&:to_sym) : {}
    end

    def validate(normalized)
      return nil if params_schema_definition
      missing = self.class.parameters.select { |_, p| p.required && !normalized.key?(p.name) }
      return "missing required parameters: #{missing.keys.map(&:inspect).join(', ')}" unless missing.empty?
      unknown = normalized.keys - self.class.parameters.keys
      return "unknown parameters: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?
      nil
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
