     require 'colorize'
require 'securerandom'
require_relative '../../config'
require_relative 'scenario_publish'

module Marso

  class ScenarioContext
    attr_reader :id, :before_run, :get_scenario, :after_run, :ctx, :status,
    :description, :story_id, :feature_id

    def initialize(description, ctx)
      validate_arguments(description, ctx)

      @description = description.clone
      @ctx=ctx.clone

      @description[:id] = SecureRandom.hex(3) if description[:id].nil?
      @description[:status] = :none if description[:status].nil?

      @id = @description[:id]
      @before_run = @description[:before_run]
      @get_scenario = @description[:get_scenario]
      @after_run = @description[:after_run]
      @status = @description[:status]

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

    def indented_colorized_text
      s = @get_scenario.call(@id, @ctx)
      s.indented_colorized_text
    end

    private
      def validate_arguments(description, ctx)
        raise ArgumentError, "Argument 'ctx' must be a Hash" unless ctx.is_a?(Hash)
        raise ArgumentError, "Argument 'description' cannot be nil" if description.nil?
        raise ArgumentError, "Argument 'description' must define a :get_scenario key that points to a closure that returns a Marso::Scenario object" if description[:get_scenario].nil?
      end
  end

  class Scenario
    include ScenarioPublish

    ISSUES_LIST = [:error, :failed, :cancelled]

    @@color_options=nil
    @@color_options_size=0

    attr_reader :name, :steps, :id, :status, :color_theme,
    :cancel_steps_upon_issues, :realtime_step_stdout, :ctx, :story_id,
    :feature_id, :header, :tree_position, :fname

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
      @fname = description[:name].downcase.gsub(' ', '_')
      @ctx = ctx.clone

      @tree_position = 0
      @tree_position+=1 unless ctx[:story_id].nil?
      @tree_position+=1 unless ctx[:feature_id].nil?

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

      @header = get_header(@id, @ctx)

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

    # include_id will prepend the scenario id to the step's description.
    # This can be useful in the case where each step is being output to the
    # console in realtime. In that situation multiple steps from multiple
    # scenarios may be intertwined if they are executed concurently. Without
    # the scenario id, it may be difficult to identify which step belongs to
    # which scenario
    def text(include_id=false)
      return
        "{@header}: #{name}\n" +
        (@steps.any? ? @steps.map { |s| s.text(include_id) }.join("\n") : "")
    end

    def run
      previous_step_status = nil
      scenario_status = :passed
      no_issues = true

      processed_steps = @steps.map { |s|
        runned_step = run_step(s, previous_step_status)

        print_indented(runned_step.print_description) if @realtime_step_stdout

        previous_step_status = runned_step.status

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

        runned_step
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

      return updated_scenario
    end

    private

      def validate_arguments(description, ctx)
        raise ArgumentError, "Argument 'description' must be a Hash" unless description.is_a?(Hash)
        raise ArgumentError, "Argument 'description[:name]' is required" if description[:name].nil?
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

      def run_step(step, previous_step_status)
        if ISSUES_LIST.include?(previous_step_status) && @cancel_steps_upon_issues
          cancelled_step = Step.new(step.text, @id, @color_theme, :cancelled, &step.block)
          return cancelled_step.execute
        else
          return step.run
        end
      end

      def get_header(id, ctx)
        header = []
        header << "Feature #{ctx[:feature_id]}" unless ctx[:feature_id].nil?
        header << "Story #{ctx[:story_id]}" unless ctx[:story_id].nil?
        header << "Scenario #{id}"
        header.join(" - ")
      end
  end
end
