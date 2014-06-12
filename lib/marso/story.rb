require 'colorize'
require 'securerandom'
require_relative 'helpers/texthelper'
require_relative 'helpers/statushelper'
require_relative 'helpers/componenthelper'

module Marso

  class Story
    include TextHelper

    attr_reader :id, :description, :status, :ctx, :scenario_contexts, :feature_id

    # description (optional): Hash defined as follow
    #   :id => Arbitrary number or string. Default is randomly generated
    #          (hex string (length 8))
    #   :name => Story's name
    #   :in_order_to => String that describes the fundamental story's business
    #                   value
    #   :as_a => String that describes the user(s)
    #   :i => String that describes the feature that could deliver the story's
    #         business value(e.g. I want ... or I should ...)
    #   :scenario_contexts => Array of all the scenario contexts that are part
    #                         of that story
    #   :rootpath => Path to the folder that contain this current feature's file
    #                as well as its associated 'scenarios' and 'stories' folder
    #   :status => Can only be set if :scenario_contexts is empty. Otherwise, it
    #              will be overidden by the status of :scenario_contexts
    def initialize(description, ctx={})
      validate_arguments(description, ctx)

      @description = description.clone
      @description[:scenario_contexts] = [] if description[:scenario_contexts].nil?
      @description[:id] = SecureRandom.hex(4) unless description.key?(:id)
      @description[:color_theme] = :light_blue unless description.key?(:color_theme)
      @description[:rootpath] = File.dirname(caller[0]) if description[:rootpath].nil?

      @rootpath = @description[:rootpath]

      @scenario_contexts = @description[:scenario_contexts]
      @id = @description[:id]

      if @scenario_contexts.empty? && !@description[:status].nil?
        @status = @description[:status]
      else
        @status = @scenario_contexts.status
      end

      @ctx = ctx.clone

      @indent_steps = 0
      @indent_steps+=1 unless ctx[:feature_id].nil?

      @feature_id = ctx[:feature_id]
    end

    def load_scenario_contexts
      new_ctx = @ctx.clone
      new_ctx[:story_id] = @id
      file_path_pattern = File.join(@rootpath, 'scenarios/*.rb')

      scenario_ctxs = Marso.load_component(:scenario_context, file_path_pattern, new_ctx)

      new_description = @description.clone
      new_description[:scenario_contexts] = scenario_ctxs
      return Story.new(new_description, new_ctx)
    end

    # Run the feature
    # args:
    #   load_mode (optional):
    #     => :l - (default) Load the component if it hasn;t been loaded yet
    #     => :i - Ignore loading the componeents, and simply run the feature as it is
    def run(load_mode=:l)
      ignore_load_component = load_mode == :i

      if @scenario_contexts.any? || ignore_load_component
        return run_scenarios
      else
        loaded_story = self.load_scenario_contexts
        return loaded_story.run :i
      end
    end

    # include_mode values:
    # => :none - Only display the feature's description
    # => :with_stories - Display the feature description as well as all its
    #                    stories' description
    # => :with_scenarios - Display the feature description as well as all its
    #                      scenarios' description
    # => :with_all - Display the feature description as well as both all its
    #                stories and scenarios descriptions
    def puts_description(include_mode=:none)
      puts_indented self.get_colorized_description(include_mode)
    end

    # include_mode values:
    # => :none - Only display the feature's description
    # => :with_stories - Display the feature description as well as all its
    #                    stories' description
    # => :with_scenarios - Display the feature description as well as all its
    #                      scenarios' description
    # => :with_all - Display the feature description as well as both all its
    #                stories and scenarios descriptions
    def print_description(include_mode=:none)
      print_text self.get_colorized_description(include_mode)
    end

    def get_colorized_description(include_mode=:none)
      color_theme = :light_yellow
      case @status
      when :passed
        color_theme = :green
      when :failed_no_scenarios
        color_theme = :red
      when :failed
        color_theme = :red
      when :error
        color_theme = :red
      end

      story_parts = [get_header]
      story_parts << "In order to #{@description[:in_order_to]}" if @description.key?(:in_order_to)
      story_parts << "As a #{@description[:as_a]}" if @description.key?(:as_a)
      story_parts << "I #{@description[:i]}" if @description.key?(:i)

      description = [story_parts.join("\n").colorize(color_theme)]

      if include_mode == :with_scenarios && !@scenario_contexts.empty?
        @scenario_contexts.each { |scn|
          description << scn.get_colorized_description.gsub("\n", "\n\t")
        }
      end

      return description.join("\n\t")
    end

    private

      def validate_arguments(description, ctx)
        raise ArgumentError, "Argument 'description' cannot be nil" if description.nil?
        raise ArgumentError, "Argument 'description' must be a Hash" unless description.is_a?(Hash)
        raise ArgumentError, "Argument 'ctx' must be a Hash" unless ctx.is_a?(Hash)
        unless description[:scenario_contexts].nil?
          unless description[:scenario_contexts].empty?
            raise ArgumentError, "Argument 'description[:scenario_contexts]' must be an Array" unless description[:scenario_contexts].is_a?(Array)
            raise ArgumentError, "Argument 'description[:scenario_contexts]' can only contain objects of type Marso::ScenarioContext" if description[:scenario_contexts].any? { |x| !x.is_a?(Marso::ScenarioContext) }
          end
        end
      end

      def get_header
        header = []
        header << "Feature #{@ctx[:feature_id]}" unless @ctx[:feature_id].nil?
        header << "Story #{@id}: #{@description[:name]}"
        case @status
        when :passed
          return "#{header.join(' - ')}: PASSED"
        when :none
          return header.join(" - ")
        when :failed_no_scenarios
          return "#{header.join(' - ')}: FAILED - No scenarios found"
        else
          return "#{header.join(' - ')}: FAILED"
        end
      end

      def run_scenarios
        if @scenario_contexts.any?
          puts_indented "Running #{get_header}..."
          runned_scenario_ctxs = @scenario_contexts.map { |scenario_ctx|
            scenario_ctx.run
          }

          updated_description = @description.clone
          updated_description[:scenario_contexts] = runned_scenario_ctxs

          updated_story = Story.new(updated_description, @ctx)

          updated_story.puts_description

          return updated_story
        else
          puts_indented "#{get_header} does not have any scenario contexts defined".colorize(:red)
          return self
        end
      end
  end
end
