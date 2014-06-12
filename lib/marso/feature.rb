require 'colorize'
require 'securerandom'
require_relative 'helpers/texthelper'
require_relative 'helpers/statushelper'
require_relative 'helpers/componenthelper'

module Marso

  class Feature
    include TextHelper

    attr_reader :id, :description, :status, :ctx, :stories, :scenario_contexts

    # description (optional): Hash defined as follow
    #   :id => Arbitrary number or string. Default is randomly generated
    #          (hex string (length 8))
    #   :name => Story's name
    #   :in_order_to => String that describes the fundamental story's business
    #                   value
    #   :as_a => String that describes the user(s)
    #   :i => String that describes the feature that could deliver the story's
    #         business value(e.g. I want ... or I should ...)
    #   :stories => Array of all the stories that are part of that feature
    #   :scenario_contexts => Array of all the scenario contexts that are part
    #                         of that feature
    #   :rootpath => Path to the folder that contain this current feature's file
    #                as well as its associated 'scenarios' and 'stories' folder
    def initialize(description={}, ctx={})
      validate_arguments(description, ctx)

      @description = description.clone
      @description[:scenario_contexts] = [] if description[:scenario_contexts].nil?
      @description[:stories] = [] if description[:stories].nil?
      @description[:id] = SecureRandom.hex(4) if description[:id].nil?
      @description[:color_theme] = :light_blue if description[:color_theme].nil?
      @description[:rootpath] = File.dirname(caller[0]) if description[:rootpath].nil?

      @rootpath = @description[:rootpath]
      @id = @description[:id]
      @scenario_contexts = @description[:scenario_contexts]
      @stories = @description[:stories]

      @status = Marso.item_with_stronger_status(@stories, @scenario_contexts).status

      @ctx = ctx
      @indent_steps = 0
    end

    # Load feature's components based on the following mode:
    # => :stories
    # => :scenario_contexts
    # => :all
    def load(mode)
      case mode
      when :stories
        return load_stories
      when :scenario_contexts
        return load_scenario_contexts
      when :all
        return load_all
      else
        raise ArgumentError, "Mode #{mode} is not supported. Use one of the following: :stories, :scenario_contexts, :all"
      end
    end

    # Run the feature
    # args:
    #   mode: Defines which feature's components must be run
    #     => :stories
    #     => :scenarios
    #     => :all
    #   load_mode (optional):
    #     => :l - (default) Load the component if it hasn;t been loaded yet
    #     => :i - Ignore loading the componeents, and simply run the feature as it is
    def run(mode, load_mode=:l)
      ignore_load_component = load_mode == :i

      case mode
      when :stories
        if self.stories.any? || ignore_load_component
          return run_stories
        else
          loaded_feat = self.load :stories
          return loaded_feat.run :stories, :i
        end
      when :scenarios
        if self.scenario_contexts.any? || ignore_load_component
          return run_scenarios
        else
          loaded_feat = self.load :scenarios
          return loaded_feat.run :scenarios, :i
        end
      when :all
        if (self.scenario_contexts.any? && self.stories.any?) || ignore_load_component
          return run_all
        else
          if self.scenario_contexts.any? && self.stories.empty?
            loaded_feat = self.load :stories
            return loaded_feat.run :all, :i
          end
          if self.scenario_contexts.empty? && self.stories.any?
            loaded_feat = self.load :scenario_contexts
            return loaded_feat.run :all, :i
          end
          if self.scenario_contexts.empty? && self.stories.empty?
            loaded_feat = self.load :all
            return loaded_feat.run :all, :i
          end
        end
      else
        raise ArgumentError, "Mode #{mode} is not supported. Use one of the following: :stories, :scenarios, :all"
      end
    end

    def get_all_scenario_contexts
      all_scenario_ctxs = []
      all_scenario_ctxs = @scenario_contexts if @scenario_contexts.any?
      if @stories.any?
        @stories.each { |story|
          if story.scenario_contexts.any?
            story.scenario_contexts.each { |scn| all_scenario_ctxs << scn }
          else
            story.load_scenario_contexts.scenario_contexts.each { |scn| all_scenario_ctxs << scn }
          end
        }
      end

      return all_scenario_ctxs
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
      inculde_scenarios = include_mode == :with_scenarios || include_mode == :with_all
      inculde_stories = include_mode == :with_stories || include_mode == :with_all

      color_theme = :light_yellow
      case @status
      when :passed
        color_theme = :green
      when :failed
        color_theme = :red
      when :error
        color_theme = :red
      end

      feat_parts = [get_header]
      feat_parts << "In order to #{@description[:in_order_to]}" if @description.key?(:in_order_to)
      feat_parts << "As a #{@description[:as_a]}" if @description.key?(:as_a)
      feat_parts << "I #{@description[:i]}" if @description.key?(:i)

      description_with_scenarios = [feat_parts.join("\n").colorize(color_theme)]

      if inculde_scenarios && !@scenario_contexts.empty?
        @scenario_contexts.each { |scn|
          description_with_scenarios << scn.get_colorized_description.gsub("\n", "\n\t")
        }
      end

      description_with_stories = [description_with_scenarios.join("\n\t")]

      if inculde_stories && !@stories.empty?
        @stories.each { |s|
          description_with_stories << s.get_colorized_description.gsub("\n", "\n\t")
        }
      end

      return description_with_stories.join("\n\t")
    end

    private

      def validate_arguments(description, ctx)
        raise ArgumentError, "Argument 'description' cannot be nil" if description.nil?
        raise ArgumentError, "Argument 'description' must be a Hash" unless description.is_a?(Hash)
        raise ArgumentError, "Argument 'ctx' must be a Hash" unless ctx.is_a?(Hash)
        unless description[:scenario_contexts].nil?
          unless description[:scenario_contexts].empty?
            raise ArgumentError, "Argument 'description[:scenario_contexts]' must be an Array" unless description[:scenario_contexts].is_a?(Array)
            offender = description[:scenario_contexts].detect { |x| !x.is_a?(Marso::ScenarioContext) }.class
            raise ArgumentError, "One value inside 'description[:scenario_contexts]' is of type #{offender}. The only type allowed is Marso::ScenarioContext" unless offender == NilClass
          end
        end
      end

      def get_header
        header = "Feature #{@id}: #{@description[:name]}"

        case @status
        when :passed
          return "#{header}: PASSED"
        when :none
          return header
        else
          return "#{header}: FAILED"
        end
      end

      def load_scenario_contexts
        new_ctx = @ctx.clone
        new_ctx[:feature_id] = @id
        file_path_pattern = File.join(@rootpath, 'scenarios/*.rb')

        scenario_ctxs = Marso.load_component(:scenario_context, file_path_pattern, new_ctx)

        new_description = @description.clone
        new_description[:scenario_contexts] = scenario_ctxs
        return Feature.new(new_description, new_ctx)
      end

      def load_stories
        new_ctx = @ctx.clone
        new_ctx[:feature_id] = @id
        file_path_pattern = File.join(@rootpath, 'stories/*/*.rb')

        stories = Marso.load_component(:story, file_path_pattern, new_ctx)

        new_description = @description.clone
        new_description[:stories] = stories
        return Feature.new(new_description, new_ctx)
      end

      def load_all
        load_stories.load :scenario_contexts
      end

      def run_scenarios
        if @scenario_contexts.any?
          puts_indented "Running scenarios for #{get_header}..."
          runned_scenario_ctxs = @scenario_contexts.map { |scenario_ctx|
            scenario_ctx.run
          }

          updated_description = @description.clone
          updated_description[:scenario_contexts] = runned_scenario_ctxs

          updated_feature = Feature.new(updated_description, @ctx)

          updated_feature.puts_description

          return updated_feature
        else
          puts_indented "#{get_header} does not have any scenario contexts defined".colorize(:red)
          return self
        end
      end

      def run_stories
        if @stories.any?
          puts_indented "Running stories for #{get_header}..."
          runned_stories = @stories.map { |story|
            if story.scenario_contexts.any?
              story.run
            else
              story.load_scenario_contexts.run
            end
          }

          updated_description = @description.clone
          updated_description[:stories] = runned_stories

          updated_feature = Feature.new(updated_description, @ctx)

          updated_feature.puts_description

          return updated_feature
        else
          puts_indented "#{get_header} does not have any stories defined".colorize(:red)
          return self
        end
      end

      def run_all
        all_scenario_ctxs = get_all_scenario_contexts

        if all_scenario_ctxs.any?

          puts_indented "Running #{get_header}..."
          runned_scenario_ctxs = all_scenario_ctxs.map { |scenario_ctx|
            scenario_ctx.run
          }

          updated_stories , updated_scenario_ctxs = reorganize_allscenariosctxs_into_stories_scenarioctxs(runned_scenario_ctxs)

          updated_description = @description.clone
          updated_description[:scenario_contexts] = updated_scenario_ctxs
          updated_description[:stories] = updated_stories

          updated_feature = Feature.new(updated_description, @ctx)

          updated_stories.each { |s| s.puts_description }
          updated_feature.puts_description

          return updated_feature
        else
          error_msg = nil
          if @stories.any?
            stories_nbr = @stories.size
            part = stories_nbr == 1 ? "story, it doesn't" : "stories, none of them"
            error_msg = "Though #{get_header} does contain #{stories_nbr} #{part} contain scenario contexts"
          else
            error_msg = "#{get_header} does not have any stories or scenario contexts defined"
          end
          puts_indented error_msg.colorize(:red)
          return self
        end
      end

      def reorganize_allscenariosctxs_into_stories_scenarioctxs(scenario_contexts)
        updated_stories = []
        updated_scenario_ctxs = []

        scenario_contexts
          .group_by { |x| x.story_id }
          .each { |k,v|
            if k != nil
              story = @stories.detect { |x| x.id == k }
              updated_story_description = story.description.clone
              updated_story_ctx = story.ctx.clone
              updated_story_description[:scenario_contexts] = v
              updated_story = Story.new(updated_story_description, updated_story_ctx)
              updated_stories << updated_story
            else
              updated_scenario_ctxs = v
            end
          }

        @stories.each { |s|
          unless updated_stories.any? { |x| x.id == s.id }
            new_description = s.description.clone
            new_description[:status] = :failed_no_scenarios
            updated_stories << Marso::Story.new(new_description, s.ctx)
          end
        }

        return [updated_stories, updated_scenario_ctxs]
      end
  end
end
