require 'colorize'
require 'securerandom'
require_relative 'config'
require_relative 'helpers/texthelper'

module Marso

  class ScenarioContext
    attr_reader :id, :before_run, :get_scenario, :after_run, :ctx, :status,
    :description, :story_id, :feature_id

    def initialize(description, ctx={})
      validate_arguments(description, ctx)

      @description = description.clone

      @description[:id] = SecureRandom.hex(4) if description[:id].nil?
      @description[:status] = :none if description[:status].nil?
      @ctx=ctx.clone

      @id = @description[:id]
      @before_run=@description[:before_run]
      @get_scenario=@description[:get_scenario]
      @after_run=@description[:after_run]
      @status=@description[:status]

      @story_id = ctx[:story_id]
      @feature_id = ctx[:feature_id]
    end

    def run
      @before_run.call(@description[:id], @ctx) unless @before_run.nil?
      s = @get_scenario.call(@id, @ctx)
      runned_scenario = s.run
      @after_run.call(@id, @ctx) unless @after_run.nil?

      updated_description = @description.clone
      updated_description[:get_scenario] = proc { runned_scenario }
      updated_description[:status] = runned_scenario.status

      return ScenarioContext.new(updated_description, @ctx)
    end

    def puts_scenario
      s = @get_scenario.call(@id, @ctx)
      s.puts_description
    end

    def get_colorized_description
      s = @get_scenario.call(@id, @ctx)
      s.get_colorized_description
    end

    private
      def validate_arguments(description, ctx)
        raise ArgumentError, "Argument 'ctx' must be a Hash" unless ctx.is_a?(Hash)
        raise ArgumentError, "Argument 'description' cannot be nil" if description.nil?
        raise ArgumentError, "Argument 'description' must define a :get_scenario key that points to a closure that returns a Marso::Scenario object" if description[:get_scenario].nil?
      end
  end

  class Scenario
    include TextHelper

    ISSUES_LIST = [:error, :failed, :cancelled]
    @@color_options=nil
    @@color_options_size=0
    attr_reader :name, :steps, :id, :status, :color_theme,
    :cancel_steps_upon_issues, :realtime_step_stdout, :ctx, :story_id,
    :feature_id

    # description: Hash defined as follow
    #   :id => Arbitrary number or string. Default is randomly generated
    #          (hex string (length 8))
    #   :name => Scenario's name
    #   :steps => array of Step objects
    #   :color_theme => color from gem 'colorize'(e.g. :blue). That allows
    #                   to visually group all steps from the same scenario.
    #                   Default is randomly choosen from the available set
    #   :cancel_steps_upon_issues => Boolean. If true, all steps defined after
    #                                a broken step(i.e. step in status :failed,
    #                                :error, or :cancelled) will not be
    #                                executed, and will all be set so their
    #                                status is :cancelled.
    #
    #                                If defined, it overrides the
    #                                Config.cancel_steps_upon_issues setting.
    #   :realtime_step_stdout => Boolean. If true, the result of each step is
    #                            output to the console in realtime rather than
    #                            waiting for the entire scenario to finish and
    #                            then display all the steps all at once. Setting
    #                            that config to true may make reading the output
    #                            harder when multiple scenarios are executed in
    #                            paralell.Steps of different scenarios may
    #                            indeed be intertwined in the console.
    #
    #                            If defined, it overrides the
    #                            Config.realtime_step_stdout setting.
    def initialize(description, ctx={})
      validate_arguments(description, ctx)

      if @@color_options.nil?
        @@color_options = String.colors
        @@color_options_size = @@color_options.size
      end

      @name = description[:name]
      @ctx = ctx.clone

      @indent_steps = 0
      @indent_steps+=1 unless ctx[:story_id].nil?
      @indent_steps+=1 unless ctx[:feature_id].nil?

      @story_id = ctx[:story_id]
      @feature_id = ctx[:feature_id]

      @id =
        description.key?(:id) ?
        description[:id] :
        SecureRandom.hex(4)

      @status =
        description.key?(:status) ?
        description[:status] :
        :none

      @color_theme =
        description.key?(:color_theme) ?
        description[:color_theme] :
        @@color_options[rand(@@color_options_size)]

      @steps =
        description.key?(:steps) ?
        description[:steps].map { |s| Step.new(s.text, @id, @color_theme, s.status, &s.block) } :
        []

      @cancel_steps_upon_issues =
        description.key?(:cancel_steps_upon_issues) ?
        description[:cancel_steps_upon_issues] :
        Marso::Config.get(:cancel_steps_upon_issues)

      @realtime_step_stdout =
        description.key?(:realtime_step_stdout) ?
        description[:realtime_step_stdout] :
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
      puts_indented("Scenario #{@id}".colorize(@color_theme) + ": " + "#{name}".blue) if @realtime_step_stdout

      processed_steps = @steps.map { |s|
        executed_step = execute_step(s, previous_step_status)

        print_indented(executed_step.print_description) if @realtime_step_stdout

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

      updated_scenario = Scenario.new(
        {
          :id => @id,
          :name => @name,
          :steps => processed_steps,
          :status => scenario_status,
          :color_theme => @color_theme
        },
        @ctx)

      updated_scenario.puts_description unless @realtime_step_stdout

      return updated_scenario
    end

    def description
      return
        "Scenario #{@id}: #{name}\n" +
        (@steps.any? ? @steps.map { |s| s.context }.join("\n") : "")
    end

    def puts_description
      puts_indented self.get_colorized_description
    end

    def print_description
      print_indented self.get_colorized_description
    end

    def get_colorized_description
      scen_parts = [get_header.colorize(@color_theme) + ": " + "#{@name}".blue]
      if !@steps.nil?
        (scen_parts | @steps.map { |s| s.get_description_for_print  }).join("\n")
      else
        scen_parts[0]
      end
    end

    private

      def validate_arguments(description, ctx)
          raise ArgumentError, "Argument 'description' must be a Hash" unless description.is_a?(Hash)
          raise ArgumentError, "Argument 'ctx' must be a Hash" unless ctx.is_a?(Hash)
      end

      def add_step(step_type, assumption_text, *args, &block)
        body_msg = nil
        status = :none
        step_name = step_type.to_s.capitalize

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

        return Scenario.new(
          {
            :id => @id,
            :name => @name,
            :steps => new_step_series,
            :status => @status,
            :color_theme => @color_theme
          },
          @ctx)
      end

      def execute_step(step, previous_step_status)
        if ISSUES_LIST.include?(previous_step_status) && @cancel_steps_upon_issues
          cancelled_step = Step.new(step.text, @id, @color_theme, :cancelled, &step.block)
          return cancelled_step.execute
        else
          return step.execute
        end
      end

      def get_header
        header = []
        header << "Feature #{@ctx[:feature_id]}" unless @ctx[:feature_id].nil?
        header << "Story #{@ctx[:story_id]}" unless @ctx[:story_id].nil?
        header << "Scenario #{@id}"
        header.join(" - ")
      end
  end

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
    attr_reader :text, :status, :color_theme, :scenario_id, :block

    def initialize(text, scenario_id, color_theme, status=:none, &block)
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

    def description
      scenario_id = "#{@scenario_id}"
      body = nil
      case @status
      when :none
        body = "#{@text}"
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

    def print_description
      puts self.get_description_for_print
    end

    def get_description_for_print
      scenario_id = "#{@scenario_id}".colorize(@color_theme)
      body = nil
      case @status
      when :none
        body = "#{@text}".light_yellow
      when :passed
          body = "#{@text}: PASSED".green
      when :failed
        body = "#{@text}: FAILED".red
      when :cancelled
        body = "#{@text}: CANCELLED".light_black
      when :error
        body = "#{@text}".red
      end

      return "#{scenario_id}: #{body}"
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
