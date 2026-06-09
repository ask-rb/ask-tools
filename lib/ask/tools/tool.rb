# frozen_string_literal: true

require "ask-schema"

module Ask
  # Base class for defining tools that LLMs can call.
  #
  # Subclass +Ask::Tool+, use the DSL to declare metadata and parameters,
  # and implement +#execute+ to perform the work.
  #
  #   class Greeter < Ask::Tool
  #     description "Greets a person by name"
  #     param :name, type: :string, desc: "The person's name", required: true
  #
  #     def execute(name:)
  #       Ask::Result.ok(data: "Hello, #{name}!")
  #     end
  #   end
  #
  #   Greeter.new.name         # => "greeter"
  #   Greeter.new.call(name: "World")
  #   # => #<Ask::Result ok=true output="Hello, World!">
  #
  class Tool
    # Raised (or returned from +#call+) to signal the conversation loop
    # should stop rather than continuing after this tool's result.
    class Halt < StandardError
      attr_reader :content

      def initialize(content)
        @content = content
        super(content.to_s)
      end
    end

    class << self
      # @api private
      def inherited(subclass)
        super
        @parameters = {} if @parameters.nil?
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@parameters, {})
        subclass.instance_variable_set(:@params_schema_definition, nil)
      end

      # Set or retrieve the tool's human-readable description.
      #
      # @param text [String, nil] when provided, sets the description
      # @return [String, nil]
      def description(text = nil)
        return @description unless text

        @description = text
      end
      alias desc description

      # Declare a parameter the tool accepts.
      #
      # @param name [Symbol] parameter name
      # @param type [Symbol] JSON Schema type (+:string+, +:integer+, +:number+,
      #   +:boolean+, +:array+, +:object+)
      # @param desc [String] human-readable description of the parameter
      # @param required [Boolean] whether the parameter is mandatory
      # @return [void]
      def param(name, type:, desc: nil, description: nil, required: true)
        type = type.to_s.downcase.to_sym
        validate_param_type!(type, name)
        parameters[name] = Parameter.new(
          name: name,
          type: map_type(type),
          description: desc || description,
          required: required
        )
      end

      # Define tool parameters using the {Ask::Schema} DSL.
      #
      # When a block is provided, it takes precedence over individual
      # +param+ declarations for schema generation.
      #
      # @example
      #   params do
      #     string :location, description: "City name"
      #     string :unit, enum: %w[celsius fahrenheit]
      #   end
      #
      # @param schema [Ask::Schema, Class<Ask::Schema>, Hash, nil] A pre-built schema
      # @param block [Proc] DSL block evaluated by Ask::Schema
      # @return [void]
      def params(schema = nil, &block)
        @params_schema_definition = schema || block
      end

      # @api private
      # @return [Hash{Symbol => Ask::Tool::Parameter}]
      def parameters
        @parameters ||= {}
      end

      # @api private
      def provider_params
        @provider_params ||= {}
      end
    end

    # Auto-derive the tool name from the class name.
    # Converts CamelCase to snake_case and strips a trailing +_tool+ suffix.
    #
    # @return [String]
    def name
      klass_name = self.class.name.to_s.split("::").last || self.class.name.to_s
      normalized = klass_name.dup.force_encoding("UTF-8").unicode_normalize(:nfkd)
      normalized.encode("ASCII", replace: "")
                .gsub(/[^a-zA-Z0-9_-]/, "-")
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .delete_suffix("_tool")
    end

    # @return [String, nil] the tool's description
    def description
      self.class.description
    end

    # @return [Hash{Symbol => Ask::Tool::Parameter}]
    def parameters
      self.class.parameters
    end

    # Call the tool with the given arguments.
    #
    # Normalizes keys to symbols, validates required parameters,
    # and delegates to +#execute+.
    #
    # @param args [Hash, nil] keyword arguments for the tool
    # @return [Ask::Result] the tool's result
    def call(args = {})
      normalized = normalize_args(args)
      validation = validate(normalized)
      return Ask::Result.error(message: validation) if validation

      execute(**normalized)
    rescue Halt => e
      Ask::Result.ok(data: e.content, metadata: { halted: true })
    rescue StandardError => e
      Ask::Result.error(message: "#{self.class.name.split('::').last} raised #{e.class}: #{e.message}")
    end

    # Subclasses must implement this method.
    #
    # @param args [Hash] normalized keyword arguments
    # @return [Ask::Result] the tool's result
    def execute(**)
      raise NotImplementedError, "#{self.class} must implement #execute(**args)"
    end

    # Generate a JSON Schema hash describing this tool's parameters.
    # Suitable for LLM function-calling APIs (OpenAI, Anthropic, etc.).
    #
    # When a +params+ block was provided, uses {Ask::Schema} to generate
    # the schema. Otherwise, auto-generates from +param+ declarations.
    #
    # @return [Hash, nil]
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

    # Full tool definition hash for LLM API calls.
    #
    # @return [Hash]
    def tool_definition
      defn = {
        name: name,
        description: description
      }
      defn[:input_schema] = params_schema if params_schema
      defn
    end

    # @return [String] inspect string
    def inspect
      "#<#{self.class.name} name=#{name.inspect}>"
    end

    private

    # @return [Object, nil] stored params schema definition from the class
    def params_schema_definition
      self.class.instance_variable_get(:@params_schema_definition)
    end

    # Resolve a params schema definition into a JSON Schema hash.
    # Supports Proc (DSL block), Hash (raw JSON Schema), or anything
    # responding to +to_json_schema+ (Ask::Schema instances/classes).
    def resolve_params_schema(definition)
      case definition
      when Proc
        schema_class = Ask::Schema.create(&definition)
        schema_class.new.to_json_schema.dig(:schema)
      when Hash
        definition
      when ->(d) { d.respond_to?(:to_json_schema) }
        definition.to_json_schema.dig(:schema)
      else
        nil
      end
    end

    # Build a JSON Schema hash from +param+ declarations.
    def build_schema_from_params
      properties = parameters.to_h do |_name, param|
        schema = { type: param.type }
        schema[:description] = param.description if param.description
        schema[:items] = { type: "string" } if param.type == "array"
        [param.name.to_s, schema]
      end

      required = parameters.select { |_, p| p.required }.keys.map(&:to_s)

      {
        type: "object",
        properties: properties,
        required: required,
        additionalProperties: false
      }
    end

    # Recursively convert symbol keys to string keys in hashes.
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

    def self.validate_param_type!(type, name)
      return if VALID_JSON_SCHEMA_TYPES.include?(type)

      raise ArgumentError,
            "Invalid type #{type.inspect} for parameter #{name.inspect}. " \
            "Valid types: #{VALID_JSON_SCHEMA_TYPES.map(&:inspect).join(', ')}"
    end

    def self.map_type(type)
      case type
      when :int then "integer"
      when :float, :double then "number"
      else type.to_s
      end
    end

    # Internal value object for parameter metadata.
    class Parameter
      # @return [Symbol]
      attr_reader :name

      # @return [String] JSON Schema type string
      attr_reader :type

      # @return [String, nil]
      attr_reader :description

      # @return [Boolean]
      attr_reader :required

      alias required? required

      def initialize(name:, type:, description: nil, required: true)
        @name = name
        @type = type
        @description = description
        @required = required
      end

      # @return [Hash]
      def to_h
        {
          name: name,
          type: type,
          description: description,
          required: required
        }
      end
    end
  end
end
