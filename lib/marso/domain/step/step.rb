require_relative 'step_publish'

module Marso

  # A 'Step' is a Scenario's part. It contains
  # a text that describe what that step does, as well
  # as a status that indicates whether or not that step
  # has already been executed. This status can take the
  # following values:
  # => :none
  # => :passed
  # => :failed
  # => :cancelled
  # => :error
  class Step
    include StepPublish

    attr_reader :description, :status, :color_theme, :scenario_id, :block

    def initialize(description, scenario_id, color_theme, status=:none, &block)
      @description=description
      @status=status
      @block=block
      @scenario_id=scenario_id
      @color_theme = color_theme
    end

    def run
      if @status != :cancelled
        execute_block
      else
        return self
      end
    end

    # include_id will prepend the scenario id to the step's description.
    # This can be useful in the case where each step is being output to the
    # console in realtime. In that situation multiple steps from multiple
    # scenarios may be intertwined if they are executed concurently. Without
    # the scenario id, it may be difficult to identify which step belongs to
    # which scenario
    def text(include_id=false)
      body = nil
      case @status
      when :none
        body = "#{@description}"
      when :passed
          body = "#{@description}: PASSED"
      when :failed
        body = "#{@description}: FAILED"
      when :cancelled
        body = "#{@description}: CANCELLED"
      when :error
        body = "#{@description}"
      end

      return include_id ? "#{scenario_id}: #{body}" : body

    end

    private
      def execute_block
        operation = lambda { |x|
          begin
            result = @block.call
            result_type = result.class
            if result_type == TrueClass || result_type == FalseClass
              if result
                return :passed, nil
              else
                return :failed, nil
              end
            else
              return :passed, nil
            end
          rescue Exception => e
            return :error, e
          end
        }

        status, err = operation.call(nil)

        updated_description = @description

        if status==:error
          updated_description =
            "#{@description}: ERROR\n" +
            "#{err.message}\n" +
            "#{err.backtrace}"
        end

        return Step.new(updated_description, @scenario_id, @color_theme, status, &@block)
      end
  end
end
