# frozen_string_literal: true

require_relative "../../test_helper"

module Ask
  class ResultTest < Minitest::Test
    def test_ok_factory_creates_successful_result
      result = Ask::Result.ok(data: "hello")

      assert_predicate result, :ok?
      assert_equal "hello", result.output
      assert_nil result.error
      assert_equal({}, result.metadata)
    end

    def test_error_factory_creates_failed_result
      result = Ask::Result.error(message: "something broke")

      refute_predicate result, :ok?
      assert_nil result.output
      assert_equal "something broke", result.error
      assert_equal({}, result.metadata)
    end

    def test_constructor_accepts_all_attributes
      result = Ask::Result.new(
        ok: true,
        output: "data",
        error: nil,
        metadata: { source: "test" }
      )

      assert_predicate result, :ok?
      assert_equal "data", result.output
      assert_nil result.error
      assert_equal({ source: "test" }, result.metadata)
    end

    def test_to_s_returns_output_for_success
      result = Ask::Result.ok(data: 42)
      assert_equal "42", result.to_s
    end

    def test_to_s_returns_error_for_failure
      result = Ask::Result.error(message: "fail")
      assert_equal "fail", result.to_s
    end

    def test_to_h_serializes_all_fields
      result = Ask::Result.ok(data: "hi", metadata: { key: "val" })
      hash = result.to_h

      assert_equal true, hash[:ok]
      assert_equal "hi", hash[:output]
      assert_nil hash[:error]
      assert_equal({ key: "val" }, hash[:metadata])
    end

    def test_error_result_to_h
      result = Ask::Result.error(message: "err")
      hash = result.to_h

      assert_equal false, hash[:ok]
      assert_nil hash[:output]
      assert_equal "err", hash[:error]
    end

    def test_inspect_shows_ok_result
      result = Ask::Result.ok(data: "test")
      assert_match(/ok=true.*output=/, result.inspect)
    end

    def test_inspect_shows_error_result
      result = Ask::Result.error(message: "fail")
      assert_match(/ok=false.*error=/, result.inspect)
    end

    def test_ok_factory_accepts_metadata
      result = Ask::Result.ok(data: "x", metadata: { count: 1 })
      assert_equal({ count: 1 }, result.metadata)
    end

    def test_error_factory_accepts_metadata
      result = Ask::Result.error(message: "x", metadata: { code: 500 })
      assert_equal({ code: 500 }, result.metadata)
    end
  end
end
