require 'securerandom'
require_relative 'story_load'
require_relative 'story_publish'
require_relative '../../helpers/statushelper'

module Marso

  class Story
    include StoryLoad
    include StoryPublish

    attr_reader :id, :description, :status, :ctx, :scenario_contexts,
    :feature_id, :tree_position, :header, :text, :color_theme, :rootpath

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
      @ctx = ctx.clone

      @description[:scenario_contexts] = [] if description[:scenario_contexts].nil?
      @description[:id] = SecureRandom.hex(4) if description[:id].nil?
      @description[:rootpath] = File.dirname(caller[0]) if description[:rootpath].nil?

      @rootpath = @description[:rootpath]
      @id = @description[:id]
      @scenario_contexts = @description[:scenario_contexts]

      if @scenario_contexts.empty? && !@description[:status].nil?
        @status = @description[:status]
      else
        @status = @scenario_contexts.status
      end

      @feature_id = ctx[:feature_id]
      @tree_position = @feature_id.nil? ? 0 : 1

      @header = get_header(@id, @status, @ctx, @description)
      @color_theme = get_color_theme(@status)
      @text = get_text(@header, @description)
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

      def get_color_theme(status)
        case status
        when :passed
          :green
        when :failed_no_component
          :red
        when :failed
          :red
        when :error
          :red
        else
          :light_yellow
        end
      end

      def get_header(id, status, ctx, description)
        header = []
        header << "Feature #{ctx[:feature_id]}" unless ctx[:feature_id].nil?
        header << "Story #{id}: #{description[:name]}"
        case status
        when :passed
          return "#{header.join(' - ')}: PASSED"
        when :none
          return header.join(" - ")
        when :failed_no_component
          return "#{header.join(' - ')}: FAILED - No scenarios found"
        else
          return "#{header.join(' - ')}: FAILED"
        end
      end

      def get_text(header, description)
        story_parts = [header]
        story_parts << "In order to #{description[:in_order_to]}" if description.key?(:in_order_to)
        story_parts << "As a #{description[:as_a]}" if description.key?(:as_a)
        story_parts << "I #{description[:i]}" if description.key?(:i)
        story_parts.join("\n")
      end
  end
end
