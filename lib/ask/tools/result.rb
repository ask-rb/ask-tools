# frozen_string_literal: true

module Ask
  # Standardized return value for tool execution.
  #
  # Every tool's #execute method should return an Ask::Result.
  # Use the factory methods +.ok+ and +.error+ for common cases.
  #
  #   Ask::Result.ok(data: "hello world")
  #   Ask::Result.error(message: "something went wrong")
  #
  class Result
    # @return [Boolean] whether the tool completed successfully
    attr_reader :ok

    # @return [Object, nil] the output data when the tool succeeded
    attr_reader :output

    # @return [String, nil] the error message when the tool failed
    attr_reader :error

    # @return [Hash] arbitrary metadata attached to the result
    attr_reader :metadata

    alias ok? ok

    # @return [Boolean] whether the tool failed
    def error?
      !ok
    end

    # @return [String, nil] the error message (alias for +error+)
    alias error_message error

    def initialize(ok:, output: nil, error: nil, metadata: {})
      @ok = ok
      @output = output
      @error = error
      @metadata = metadata
    end

    # Create a successful result.
    #
    # @param data [Object] the tool's output
    # @param metadata [Hash] optional metadata
    # @return [Ask::Result]
    def self.ok(data:, metadata: {})
      new(ok: true, output: data, error: nil, metadata: metadata)
    end

    # Create a failed result (positional message form, used by Tool#call).
    #
    # @param message [String] description of the failure
    # @param metadata [Hash] optional metadata
    # @return [Ask::Result]
    def self.failure(message, metadata: {})
      new(ok: false, output: nil, error: message, metadata: metadata)
    end

    # Create a failed result.
    #
    # @param message [String] description of the failure
    # @param metadata [Hash] optional metadata
    # @return [Ask::Result]
    def self.error(message:, metadata: {})
      new(ok: false, output: nil, error: message, metadata: metadata)
    end

    # Human-readable representation.
    # Returns the output for success or the error message for failure.
    #
    # @return [String]
    def to_s
      ok? ? output.to_s : error.to_s
    end

    # Hash representation suitable for serialization.
    #
    # @return [Hash]
    def to_h
      {
        ok: ok,
        output: output,
        error: error,
        metadata: metadata
      }
    end

    # @return [String] inspect string
    def inspect
      if ok?
        "#<Ask::Result ok=true output=#{output.inspect}>"
      else
        "#<Ask::Result ok=false error=#{error.inspect}>"
      end
    end
  end
end
