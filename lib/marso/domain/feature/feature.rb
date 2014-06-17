require 'securerandom'
require_relative 'feature_load'
require_relative 'feature_publish'
require_relative '../../helpers/statushelper'

module Marso

  class Feature
    include FeatureLoad
    include FeaturePublish

    attr_reader :id, :description, :status, :ctx, :stories, :scenario_contexts,
    :rootpath, :header, :text, :tree_position, :color_theme

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
    #   :status => Can only be set if both :scenario_contexts and :stories are
    #              empty. Otherwise, it will be overidden by the status of
    #              either :scenario_contexts or :stories
    def initialize(description={}, ctx={})
      validate_arguments(description, ctx)

      @description = description.clone
      @ctx = ctx.clone

      @description[:scenario_contexts] = [] if description[:scenario_contexts].nil?
      @description[:stories] = [] if description[:stories].nil?
      @description[:id] = SecureRandom.hex(4) if description[:id].nil?
      @description[:rootpath] = File.dirname(caller[0]) if description[:rootpath].nil?

      @rootpath = @description[:rootpath]
      @id = @description[:id]
      @scenario_contexts = @description[:scenario_contexts]
      @stories = @description[:stories]

      if @scenario_contexts.empty? && @stories.empty? && !@description[:status].nil?
        @status = @description[:status]
      else
        @status = Marso.item_with_stronger_status(@stories, @scenario_contexts).status
      end

      @tree_position = 0
      @header = get_header(@id, @status, @description)
      @color_theme = get_color_theme(@status)
      @text = get_text(@header, @description)
    end

    # Returns the combination of the feature's scenario contexts and the
    # scenario contexts under each feature's stories
    def all_scenario_contexts
      @scenario_contexts | self.stories_scenario_contexts
    end

    # Returns all the scenario contexts under each feature's stories
    def stories_scenario_contexts
      @stories.map { |s| s.scenario_contexts }.flatten
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

      def get_header(id, status, description)
        header = "Feature #{id}: #{description[:name]}"

        case status
        when :passed
          return "#{header}: PASSED"
        when :none
          return header
        when :failed_no_component
          return "#{header}: FAILED - No scenarios or stories found"
        else
          return "#{header}: FAILED"
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

      def get_text(header, description)
        feat_parts = [header]
        feat_parts << "In order to #{description[:in_order_to]}" if description.key?(:in_order_to)
        feat_parts << "As a #{description[:as_a]}" if description.key?(:as_a)
        feat_parts << "I #{description[:i]}" if description.key?(:i)
        feat_parts.join("\n")
      end
  end
end
