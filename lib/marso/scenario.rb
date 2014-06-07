require 'colorize'
require 'securerandom'
require_relative 'config'

module Marso

  class Scenario
    ISSUES_LIST = [:error, :failed, :cancelled]
    @@color_options=nil
    @@color_options_size=0
    attr_reader :name, :steps, :id, :status, :color_theme, :cancel_steps_upon_issues,
    :realtime_step_stdout

    # name: Scenario's name
    # options:
    #   :id => hex string (length 8). Default is randomly generated
    #   :steps => array of Step objects
    #   :color_theme => color from gem 'colorize'(e.g. :blue). That allows
    #                   to visually group all steps from the same scenario.
    #                   Default is randomly choosen from the available set
    #   :cancel_steps_upon_issues => Boolean. If true, all steps defined after
    #                                a broken step(i.e. step in status :failed,
    #                                :error, or :cancelled) will not be
    #                                executed, and will all be set so their
    #                                status is :cancelled. If defined, it
    #                                overrides the Config.cancel_steps_upon_issues
    #                                setting.
    def initialize(name, options={})

      if @@color_options.nil?
        @@color_options = String.colors
        @@color_options_size = @@color_options.size
      end

      @name = name
      @id =
        options.key?(:id) ?
        options[:id] :
        SecureRandom.hex(4)

      @status =
        options.key?(:status) ?
        options[:status] :
        :pending

      @color_theme =
        options.key?(:color_theme) ?
        options[:color_theme] :
        @@color_options[rand(@@color_options_size)]

      @steps =
        options.key?(:steps) ?
        options[:steps].map { |s| Step.new(s.text, @id, @color_theme, s.status, &s.block) } :
        []

      @cancel_steps_upon_issues =
        options.key?(:cancel_steps_upon_issues) ?
        options[:cancel_steps_upon_issues] :
        Marso::Config.get(:cancel_steps_upon_issues)

      @realtime_step_stdout =
        options.key?(:realtime_step_stdout) ?
        options[:realtime_step_stdout] :
        Marso::Config.get(:realtime_step_stdout)
    end

    def given(assumption_text, *args, &block)
      return add_step(:given, assumption_text, *args, &block)
    end

    def and(assumption_text, *args, &block)
      return add_step(:and, assumption_text, *args, &block)
    end

    def when(assumption_text, *args, &block)
      return add_step(:when, assumption_text, *args, &block)
    end

    def then(assumption_text, *args, &block)
      return add_step(:then, assumption_text, *args, &block)
    end

    def but(assumption_text, *args, &block)
      return add_step(:but, assumption_text, *args, &block)
    end

    def run
      previous_step_status = nil
      scenario_status = :passed
      no_issues = true
      puts "Scenario #{@id}".colorize(@color_theme) + ": " + "#{name}".blue if @realtime_step_stdout

      processed_steps = @steps.map { |s|
        executed_step = execute_step(s, previous_step_status)

        print executed_step.print_context if @realtime_step_stdout

        previous_step_status = executed_step.status

        if no_issues
          case previous_step_status
          when :error
            no_issues = false
            scenario_status = :error
          when :failed
            no_issues = false
            scenario_status = :failed
          when :cancelled
            no_issues = false
            scenario_status = :failed
          end
        end

        executed_step
      }

      return Scenario.new(@name, {
        :id => @id,
        :steps => processed_steps,
        :status => scenario_status,
        :color_theme => @color_theme
      })
    end

    def context
      return
        "Scenario #{@id}: #{name}\n" +
        (@steps.any? ? @steps.map { |s| s.context }.join("\n") : "")
    end

    def print_context
      puts "Scenario #{@id}".colorize(@color_theme) + ": " + "#{name}".blue
      @steps.map { |s| s.print_context  } if !@steps.nil?
    end


    private

      def add_step(step_type, assumption_text, *args, &block)
        body_msg = nil
        status = :pending
        step_name = step_type.to_s

        begin
          body_msg = "#{step_name} " + assumption_text % args
        rescue Exception => e
          status = :error
          body_msg =
            "#{assumption_text}: ERROR\n" +
            "args: #{args.nil? ? '' : args.join(',')}\n" +
            "#{e.message}\n" +
            "#{e.backtrace}"
        end

        new_step_series = @steps | [Step.new(body_msg, @id, color_theme, status, &block)]

        return Scenario.new(@name, {
          :id => @id,
          :steps => new_step_series,
          :status => @status,
          :color_theme => @color_theme
        })
      end

      def execute_step(step, previous_step_status)
        if ISSUES_LIST.include?(previous_step_status) && @cancel_steps_upon_issues
          cancelled_step = Step.new(step.text, @id, @color_theme, :cancelled, &step.block)
          return cancelled_step.execute
        else
          return step.execute
        end
      end
  end

  # A 'Step' is a Scenario's part. It contains
  # a text that describe what that step does, as well
  # as a status that indicates whether or not that step
  # has already been executed. This status can take the
  # following values:
  # => :pending
  # => :passed
  # => :failed
  # => :cancelled
  # => :error
  class Step
    attr_reader :text, :status, :color_theme, :scenario_id, :block

    def initialize(text, scenario_id, color_theme, status=:pending, &block)
      @text=text
      @status=status
      @block=block
      @scenario_id=scenario_id
      @color_theme = color_theme
    end

    def execute
      if @status != :cancelled
        execute_block
      else
        return self
      end
    end

    def context
      scenario_id = "#{@scenario_id}"
      body = nil
      case @status
      when :pending
        body = "#{@text}: PENDING"
      when :passed
          body = "#{@text}: PASSED"
      when :failed
        body = "#{@text}: FAILED"
      when :cancelled
        body = "#{@text}: CANCELLED"
      when :error
        body = "#{@text}"
      end

      return "#{scenario_id}: #{body}"

    end

    def print_context
      scenario_id = "#{@scenario_id}".colorize(@color_theme)
      body = nil
      case @status
      when :pending
        body = "#{@text}: PENDING".light_yellow
      when :passed
          body = "#{@text}: PASSED".green
      when :failed
        body = "#{@text}: FAILED".red
      when :cancelled
        body = "#{@text}: CANCELLED".light_black
      when :error
        body = "#{@text}".red
      end

      puts "#{scenario_id}: #{body}"

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

        updated_text = @text

        if status==:error
          updated_text =
            "#{text}: ERROR\n" +
            "#{err.message}\n" +
            "#{err.backtrace}"
        end

        return Step.new(updated_text, @scenario_id, @color_theme, status, &@block)
      end
  end
end
